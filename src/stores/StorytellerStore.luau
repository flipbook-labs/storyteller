local Charm = require("@pkg/Charm")
local ModuleLoader = require("@pkg/ModuleLoader")
local RunningStatus = require("@root/enums/RunningStatus")
local Sift = require("@pkg/Sift")

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
	local effects: { () -> () } = {}

	local status: RunningStatus.StartedStatus = RunningStatus.None

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

	-- These functions are just wrappers to cast `{ Instance }` to `{
	-- ModuleScript }` so Luau gets the memo
	local function storyModulesQueryGet()
		return (storyModulesQuery.get() :: any) :: { ModuleScript }
	end
	local function storybookModulesQueryGet()
		return (storybookModulesQuery.get() :: any) :: { ModuleScript }
	end

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
						loader = loader,
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
		if status == RunningStatus.Stopped or status == RunningStatus.Stopping then
			return
		end
		status = RunningStatus.Stopping

		storybookModulesQuery.destroy()
		storyModulesQuery.destroy()

		for _, connection in connections do
			connection:Disconnect()
		end

		for _, dispose in effects do
			dispose()
		end

		status = RunningStatus.Stopped
	end
	self.stop = stop

	local function start()
		if status == RunningStatus.Starting or status == RunningStatus.Started then
			return
		end
		status = RunningStatus.Starting

		connections = Sift.List.join(connections, {
			storyModulesQuery.added:Connect(function()
				setStoryModules(storyModulesQueryGet())
			end),

			storyModulesQuery.changed:Connect(function()
				setStoryModules(storyModulesQueryGet())
			end),

			storyModulesQuery.removed:Connect(function()
				setStoryModules(storyModulesQueryGet())
			end),

			storybookModulesQuery.added:Connect(function(storybookModules: { Instance })
				Charm.batch(function()
					for _, storybookModule in storybookModules do
						assert(storybookModule:IsA("ModuleScript"), "Luau")
						loadStorybook(storybookModule)
					end

					setStorybookModules(storybookModulesQueryGet())
				end)
			end),

			storybookModulesQuery.changed:Connect(function(storybookModules)
				Charm.batch(function()
					setStorybookModules(storybookModulesQueryGet())

					for _, storybookModule in storybookModules do
						assert(storybookModule:IsA("ModuleScript"), "Luau")
						reloadStorybook(storybookModule)
					end
				end)
			end),

			storybookModulesQuery.removed:Connect(function(storybookModules: { Instance })
				Charm.batch(function()
					for _, storybookModule in storybookModules do
						assert(storybookModule:IsA("ModuleScript"), "Luau")
						unloadStorybook(storybookModule)
					end

					setStorybookModules(storybookModulesQueryGet())
				end)
			end),

			root.Destroying:Connect(stop),

			script.Destroying:Connect(stop),
		})

		local storybookModules = storybookModulesQueryGet()

		Charm.batch(function()
			setStoryModules(storyModulesQueryGet())
			setStorybookModules(storybookModules)

			for _, storybookModule in storybookModules do
				loadStorybook(storybookModule)
			end
		end)

		status = RunningStatus.Started
	end
	self.start = start

	return self
end

return {
	new = StorytellerStore.new,
	instance = StorytellerStore.new(game),
}
