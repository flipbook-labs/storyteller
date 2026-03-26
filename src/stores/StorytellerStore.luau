local Charm = require("@pkg/Charm")
local ModuleLoader = require("@pkg/ModuleLoader")
local RunningStatus = require("@root/enums/RunningStatus")
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
	local status: RunningStatus.RunningStatus = RunningStatus.None

	local getLoadedStorybooks, setLoadedStorybooks = Charm.signal({} :: { LoadedStorybook })
	self.getLoadedStorybooks = getLoadedStorybooks

	local getUnavailableStorybooks, setUnavailableStorybooks = Charm.signal({} :: { UnavailableStorybook })
	self.getUnavailableStorybooks = getUnavailableStorybooks

	local storyModulesQuery = query({
		root = root,
		selector = "ModuleScript",
		matcher = isStoryModule,
	})

	local storybookModulesQuery = query({
		root = root,
		selector = "ModuleScript",
		matcher = isStorybookModule,
	})

	-- These functions are just wrappers to cast `{ Instance }` to `{
	-- ModuleScript }` so Luau gets the memo
	local function storyModulesQueryGet()
		return (storyModulesQuery.get() :: any) :: { ModuleScript }
	end
	local function storybookModulesQueryGet()
		return (storybookModulesQuery.get() :: any) :: { ModuleScript }
	end
	local function storybookModulesQueryGetSet()
		return (storybookModulesQuery.getSet() :: any) :: { [ModuleScript]: true }
	end

	self.getStoryModules = storyModulesQueryGet
	self.getStorybookModules = storybookModulesQueryGet

	local getOrphanedStoryModules = Charm.computed(function(): { ModuleScript }
		local orphans = {}
		for _, storyModule in storyModulesQueryGet() do
			if isOrphanedStoryModule(storyModule, getLoadedStorybooks()) then
				table.insert(orphans, storyModule)
			end
		end
		return orphans
	end)
	self.getOrphanedStoryModules = getOrphanedStoryModules

	local disposeStorybookModuleObserver

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

	local function stop()
		if status == RunningStatus.Stopped or status == RunningStatus.Stopping then
			return
		end
		status = RunningStatus.Stopping

		if storybookModulesQuery then
			storybookModulesQuery.destroy()
		end
		if storyModulesQuery then
			storyModulesQuery.destroy()
		end

		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)

		disposeStorybookModuleObserver()

		status = RunningStatus.Stopped
	end
	self.stop = stop

	local function start()
		if status == RunningStatus.Starting or status == RunningStatus.Started then
			return
		end
		status = RunningStatus.Starting

		disposeStorybookModuleObserver = Charm.observe(storybookModulesQueryGetSet, function(_, storybookModule)
			print("load", storybookModule:GetFullName())
			loadStorybook(storybookModule)

			local changedConn = storybookModule.Changed:Connect(debounce(function()
				print("reload", storybookModule:GetFullName())
				unloadStorybook(storybookModule)
				loadStorybook(storybookModule)
			end))

			return function()
				print("unload", storybookModule:GetFullName())

				unloadStorybook(storybookModule)
				changedConn:Disconnect()
			end
		end)

		table.insert(connections, root.Destroying:Connect(stop))
		table.insert(connections, script.Destroying:Connect(stop))

		local storybookModules = storybookModulesQueryGet()

		Charm.batch(function()
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
