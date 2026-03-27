local Charm = require("@pkg/Charm")
local ModuleLoader = require("@pkg/ModuleLoader")
local Sift = require("@pkg/Sift")

local debounce = require("@root/debounce")
local isOrphanedStoryModule = require("@root/isOrphanedStoryModule")
local isStoryModule = require("@root/isStoryModule")
local isStorybookModule = require("@root/isStorybookModule")
local loadStorybookModule = require("@root/loadStorybookModule")
local query = require("@root/stores/query")
local types = require("@root/types")

type LoadedStorybook = types.LoadedStorybook
type UnavailableStorybook = types.UnavailableStorybook
type LoadedStory<T> = types.LoadedStory<T>

local function shouldProcessModule(instance: Instance)
	-- ModuleLoader holds a lock on the module it's requiring because it has to
	-- do some weird indirection with cloning, which naturally results in
	-- DataModel events. We do not want a module being required to trigger query
	-- recomputations, so Storyteller needs to pause processing until the lock
	-- is removed
	return not ModuleLoader.isLocked(instance)
end

export type StorytellerStore = {
	start: () -> (),
	stop: () -> (),
	destroy: () -> (),

	getLoadedStorybooks: () -> { LoadedStorybook },
	getUnavailableStorybooks: () -> { UnavailableStorybook },

	getStorybookModules: () -> { ModuleScript },
	getStoryModules: () -> { ModuleScript },
	getOrphanedStoryModules: () -> { ModuleScript },
}

local StorytellerStore = {}

function StorytellerStore.new(root: Instance): StorytellerStore
	local self = {}

	local connections: { RBXScriptConnection } = {}
	local disposeStorybookModuleObserver
	local disposeStorybookModulesSubscription
	local disposeStoryModulesSubscription

	local isDestroyed = false
	local isRunning = false

	local getStoryModules, setStoryModules = Charm.signal({} :: { ModuleScript })
	self.getStoryModules = getStoryModules

	local getStorybookModules, setStorybookModules = Charm.signal({} :: { ModuleScript })
	self.getStorybookModules = getStorybookModules

	local getLoadedStorybooks, setLoadedStorybooks = Charm.signal({} :: { LoadedStorybook })
	self.getLoadedStorybooks = getLoadedStorybooks

	local getUnavailableStorybooks, setUnavailableStorybooks = Charm.signal({} :: { UnavailableStorybook })
	self.getUnavailableStorybooks = getUnavailableStorybooks

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

	local storyModulesQuery = query({
		root = root,
		selector = "ModuleScript",
		matcher = isStoryModule,
		shouldProcess = shouldProcessModule,
	})

	local storybookModulesQuery = query({
		root = root,
		selector = "ModuleScript",
		matcher = isStorybookModule,
		shouldProcess = shouldProcessModule,
	})

	local function loadStorybook(storybookModule: ModuleScript)
		local loader = ModuleLoader.new()

		local storybook: LoadedStorybook?
		local success, result = pcall(function()
			storybook = loadStorybookModule(storybookModule, loader)
		end)

		if success and storybook then
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

	local function reloadStorybook(storybookModule: ModuleScript)
		Charm.batch(function()
			unloadStorybook(storybookModule)
			loadStorybook(storybookModule)
		end)
	end

	local function stop()
		if isDestroyed or not isRunning then
			return
		end
		isRunning = false

		storyModulesQuery.stop()
		storybookModulesQuery.stop()

		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)

		disposeStorybookModuleObserver()
		disposeStorybookModulesSubscription()
		disposeStoryModulesSubscription()
	end
	self.stop = stop

	local function start()
		if isDestroyed or isRunning then
			return
		end
		isRunning = true

		disposeStoryModulesSubscription = Charm.listen(storyModulesQuery.get, function(storyModules)
			setStoryModules((storyModules :: any) :: { ModuleScript })
		end)

		disposeStorybookModulesSubscription = Charm.listen(storybookModulesQuery.get, function(storybookModules)
			setStorybookModules((storybookModules :: any) :: { ModuleScript })
		end)

		disposeStorybookModuleObserver = Charm.observe(storybookModulesQuery.get, function(storybookModule)
			assert(storybookModule:IsA("ModuleScript"), "Luau")

			loadStorybook(storybookModule)

			local changedConn = storybookModule.Changed:Connect(debounce(function()
				reloadStorybook(storybookModule)
			end))

			return function()
				unloadStorybook(storybookModule)
				changedConn:Disconnect()
			end
		end)

		storyModulesQuery.start()
		storybookModulesQuery.start()

		table.insert(connections, root.Destroying:Connect(stop))
		table.insert(connections, script.Destroying:Connect(stop))

		Charm.batch(function()
			for _, storybookModule in storybookModulesQuery.get() do
				assert(storybookModule:IsA("ModuleScript"), "Luau")

				loadStorybook(storybookModule)
			end
		end)
	end
	self.start = start

	local function destroy()
		if isDestroyed then
			return
		end

		isDestroyed = true
		stop()
		storyModulesQuery.destroy()
		storybookModulesQuery.destroy()
	end
	self.destroy = destroy

	return self
end

return {
	new = StorytellerStore.new,
	instance = StorytellerStore.new(game),
}
