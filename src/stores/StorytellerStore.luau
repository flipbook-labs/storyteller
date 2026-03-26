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
	local storybookSignatures: { [ModuleScript]: string } = {}

	local status: RunningStatus.RunningStatus = RunningStatus.None

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

	local storyModulesQuery
	local storybookModulesQuery
	local disposeStorybookModuleObserver
	local disposeStoryModuleObserver

	local function getStorybookSignature(storybookModule: ModuleScript): string
		return `{storybookModule:GetFullName()}|{storybookModule.Source}`
	end

	local function loadStorybook(storybookModule: ModuleScript)
		local loader = ModuleLoader.new()
		storybookSignatures[storybookModule] = getStorybookSignature(storybookModule)

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
		storybookSignatures[storybookModule] = nil

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
		disposeStoryModuleObserver()

		table.clear(storybookSignatures)

		status = RunningStatus.Stopped
	end
	self.stop = stop

	local function start()
		if status == RunningStatus.Starting or status == RunningStatus.Started then
			return
		end
		status = RunningStatus.Starting

		-- Queries start running immediately so we create them in here to
		-- ensure they only run when StorytellerStore is started. This fixes
		-- a performance issue where queries were running immediately when
		-- constructing a StorytellerStore which gets Storyteller stuck in a
		-- loop when it is also used within a Storybook
		storyModulesQuery = query({
			root = root,
			selector = "ModuleScript",
			matcher = isStoryModule,
		})

		storybookModulesQuery = query({
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

		disposeStorybookModuleObserver = Charm.observe(storybookModulesQuery.get, function(storybookModule)
			assert(storybookModule:IsA("ModuleScript"), "Luau")

			local signature = getStorybookSignature(storybookModule)

			if storybookSignatures[storybookModule] ~= signature then
				loadStorybook(storybookModule)
			end

			local changedConn = storybookModule.Changed:Connect(debounce(function()
				reloadStorybook(storybookModule)
			end))

			return function()
				setStorybookModules(storybookModulesQueryGet())
				unloadStorybook(storybookModule)
				changedConn:Disconnect()
			end
		end)

		disposeStoryModuleObserver = Charm.observe(storyModulesQuery.get, function(storyModule)
			setStoryModules(storyModulesQueryGet())

			local changedConn = storyModule.Changed:Connect(debounce(function(property)
				print("storyModule Changed, property:", property)
				setStoryModules(storyModulesQueryGet())
			end))

			return function()
				setStoryModules(storyModulesQueryGet())
				changedConn:Disconnect()
			end
		end)

		connections = Sift.List.join(connections, {
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
