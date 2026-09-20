-- Requiring this module must do no work. Storyteller gets required
-- transitively inside ModuleLoader sandboxes when a Story module's dependency
-- graph includes it (Flipbook's own stories do), and a sandboxed copy must
-- stay inert: starting discovery there spawns loaders, re-evaluates React
-- package graphs, and feeds foreign component instances into live trees. The
-- shared instance is created on the first get() call rather than at require
-- time.

local Charm = require("@pkg/Charm")
local ModuleLoader = require("@pkg/ModuleLoader")
local Sift = require("@pkg/Sift")

local StoryModuleRecordStore = require("@root/stores/StoryModuleRecordStore")
local StoryModuleRequestPriority = require("@root/stores/enums/StoryModuleRequestPriority")
local debounce = require("@root/debounce")
local excludeFromCharmFreeze = require("@root/stores/excludeFromCharmFreeze")
local isOrphanedStoryModule = require("@root/isOrphanedStoryModule")
local isStoryModule = require("@root/isStoryModule")
local isStorybookModule = require("@root/isStorybookModule")
local loadStorybookModule = require("@root/loadStorybookModule")
local query = require("@root/stores/query")
local types = require("@root/types")

type LoadedStorybook = types.LoadedStorybook
type UnavailableStorybook = types.UnavailableStorybook

type StoryModuleRecord = StoryModuleRecordStore.StoryModuleRecord
type StoryRequest = StoryModuleRecordStore.StoryRequest
type CleanupFn = StoryModuleRecordStore.CleanupFn
type StoryModuleRequestPriority = StoryModuleRequestPriority.StoryModuleRequestPriority

export type StorytellerStore = {
	start: () -> (),
	stop: () -> (),
	destroy: () -> (),

	getLoadedStorybooks: () -> { LoadedStorybook },
	getUnavailableStorybooks: () -> { UnavailableStorybook },

	getStorybookModules: () -> { ModuleScript },
	getStoryModules: () -> { ModuleScript },
	getOrphanedStoryModules: () -> { ModuleScript },

	getStoryModuleRecord: (storyModule: ModuleScript) -> StoryModuleRecord?,
	requestStoryModule: (priority: StoryModuleRequestPriority, storyRequest: StoryRequest) -> CleanupFn,
}

local IS_SANDBOXED = ModuleLoader.isSandboxed()

local StorytellerStore = {}

function StorytellerStore.new(root: Instance): StorytellerStore
	local self = {}

	local connections: { RBXScriptConnection } = {}
	local disposeStorybookModuleObserver
	local disposeModulesSubscription
	local disposeStoryModuleObserver

	local isDestroyed = false
	local isRunning = false

	local pendingStorybookModules: { ModuleScript } = {}
	local queuedStorybookModules: { [ModuleScript]: boolean } = {}
	local isProcessingStorybookModules = false
	local storybookLoadGeneration = 0

	local getStoryModules, setStoryModules = Charm.signal({} :: { ModuleScript })
	self.getStoryModules = getStoryModules

	local getStorybookModules, setStorybookModules = Charm.signal({} :: { ModuleScript })
	self.getStorybookModules = getStorybookModules

	local getLoadedStorybooks, setLoadedStorybooks = Charm.signal({} :: { LoadedStorybook })
	self.getLoadedStorybooks = getLoadedStorybooks

	local getUnavailableStorybooks, setUnavailableStorybooks = Charm.signal({} :: { UnavailableStorybook })
	self.getUnavailableStorybooks = getUnavailableStorybooks

	local recordStore = StoryModuleRecordStore.new()
	self.getStoryModuleRecord = recordStore.getRecord
	self.requestStoryModule = recordStore.request

	local getOrphanedStoryModules = Charm.computed(function(): { ModuleScript }
		local orphans = {}
		for _, storyModule in getStoryModules() do
			assert(storyModule:IsA("ModuleScript"), "Luau")

			if isOrphanedStoryModule(storyModule, getLoadedStorybooks()) then
				table.insert(orphans, storyModule)
			end
		end
		return orphans
	end)
	self.getOrphanedStoryModules = getOrphanedStoryModules

	local modulesQuery = query({
		root = root,
		selector = "ModuleScript",
	})

	local function classifyModules(modules: { Instance })
		local stories: { ModuleScript } = {}
		local storybooks: { ModuleScript } = {}

		for _, module in modules do
			assert(module:IsA("ModuleScript"), "Luau")

			if isStoryModule(module) then
				table.insert(stories, module)
			elseif isStorybookModule(module) then
				table.insert(storybooks, module)
			end
		end

		Charm.batch(function()
			local previousStories = getStoryModules()
			if #stories ~= #previousStories or #Sift.List.differenceSymmetric(stories, previousStories) > 0 then
				setStoryModules(stories)
			end

			local previousStorybooks = getStorybookModules()
			if
				#storybooks ~= #previousStorybooks
				or #Sift.List.differenceSymmetric(storybooks, previousStorybooks) > 0
			then
				setStorybookModules(storybooks)
			end
		end)
	end

	local function loadStorybook(storybookModule: ModuleScript)
		local loader = ModuleLoader.new()

		local storybook: LoadedStorybook?
		local success, result = pcall(function()
			storybook = loadStorybookModule(storybookModule, loader)
		end)

		if success and storybook then
			if storybook.packages then
				-- The Storybook owns this map, so attach the exclusion to a clone.
				local packages = table.clone(storybook.packages)
				excludeFromCharmFreeze(packages)
				storybook.packages = packages
			end

			setLoadedStorybooks(function(prev)
				local new = table.clone(prev)
				local index = Sift.List.findWhere(new, function(other)
					return other.source == storybookModule
				end)
				if index then
					table.remove(new, index)
				end

				table.insert(new, storybook)

				return new
			end)
		else
			setUnavailableStorybooks(function(prev)
				local new = table.clone(prev)
				local index = Sift.List.findWhere(new, function(other)
					return other.storybook.source == storybookModule
				end)

				if index then
					table.remove(new, index)
				end

				local unavailableStorybook: UnavailableStorybook = {
					problem = result,
					storybook = {
						name = storybookModule.Name,
						source = storybookModule,
						storyRoots = {},
					},
				}
				table.insert(new, unavailableStorybook)

				return new
			end)
		end
	end

	local function unloadStorybook(storybookModule: ModuleScript)
		Charm.batch(function()
			setLoadedStorybooks(function(prev)
				return Sift.List.filter(prev, function(storybook)
					return storybook.source ~= storybookModule
				end)
			end)

			setUnavailableStorybooks(function(prev)
				return Sift.List.filter(prev, function(unavailableStorybook)
					return unavailableStorybook.storybook.source ~= storybookModule
				end)
			end)
		end)
	end

	local function processPendingStorybookModules()
		if isProcessingStorybookModules then
			return
		end
		isProcessingStorybookModules = true

		local generation = storybookLoadGeneration
		task.defer(function()
			while generation == storybookLoadGeneration and isRunning do
				local storybookModule = table.remove(pendingStorybookModules, 1)
				if not storybookModule then
					break
				end

				if queuedStorybookModules[storybookModule] then
					queuedStorybookModules[storybookModule] = nil
					loadStorybook(storybookModule)
					task.wait()
				end
			end

			if generation == storybookLoadGeneration then
				isProcessingStorybookModules = false
			end
		end)
	end

	local function queueStorybookModule(storybookModule: ModuleScript)
		if queuedStorybookModules[storybookModule] then
			return
		end

		queuedStorybookModules[storybookModule] = true
		table.insert(pendingStorybookModules, storybookModule)
		processPendingStorybookModules()
	end

	local function reloadStorybook(storybookModule: ModuleScript)
		unloadStorybook(storybookModule)
		queueStorybookModule(storybookModule)
	end

	local function stop()
		if isDestroyed then
			return
		end
		if not isRunning then
			recordStore.clear()
			return
		end
		isRunning = false
		storybookLoadGeneration += 1
		isProcessingStorybookModules = false
		table.clear(pendingStorybookModules)
		table.clear(queuedStorybookModules)

		modulesQuery.stop()

		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)

		disposeStorybookModuleObserver()
		disposeModulesSubscription()
		disposeStoryModuleObserver()
		recordStore.clear()
	end
	self.stop = stop

	local function start()
		if IS_SANDBOXED then
			return
		end
		if isDestroyed or isRunning then
			return
		end
		isRunning = true

		disposeModulesSubscription = Charm.listen(modulesQuery.get, classifyModules)

		disposeStoryModuleObserver = Charm.observe(getStoryModules, function(storyModule)
			assert(storyModule:IsA("ModuleScript"), "Luau")

			local changedConn = storyModule.Changed:Connect(debounce(function()
				setStoryModules(function(prev)
					return table.clone(prev)
				end)
			end))

			return function()
				changedConn:Disconnect()
			end
		end)

		disposeStorybookModuleObserver = Charm.observe(getStorybookModules, function(storybookModule)
			assert(storybookModule:IsA("ModuleScript"), "Luau")

			queueStorybookModule(storybookModule)

			local changedConn = storybookModule.Changed:Connect(debounce(function()
				reloadStorybook(storybookModule)
			end))

			return function()
				queuedStorybookModules[storybookModule] = nil
				unloadStorybook(storybookModule)
				changedConn:Disconnect()
			end
		end)

		modulesQuery.start()

		table.insert(connections, root.Destroying:Connect(stop))
		table.insert(connections, script.Destroying:Connect(stop))
	end
	self.start = start

	local function destroy()
		if isDestroyed then
			return
		end

		stop()
		isDestroyed = true
		recordStore.destroy()
		modulesQuery.destroy()
	end
	self.destroy = destroy

	return self
end

-- Caching relies on this computed staying dependency-free: a Charm signal
-- read during new() would let it re-run and create a second store.
StorytellerStore.get = Charm.computed(function(): StorytellerStore
	return StorytellerStore.new(game)
end)

return StorytellerStore
