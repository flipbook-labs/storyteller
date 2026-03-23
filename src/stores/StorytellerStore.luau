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

		for _, dispose in effects do
			dispose()
		end
		table.clear(effects)

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
			shouldProcess = shouldProcessModule,
		})

		storybookModulesQuery = query({
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

		local function setStoryModulesIfChanged(nextModules: { ModuleScript })
			if Sift.List.equals((getStoryModules() :: any) :: { Instance }, (nextModules :: any) :: { Instance }) then
				return
			end

			setStoryModules(nextModules)
		end

		local function setStorybookModulesIfChanged(nextModules: { ModuleScript })
			if
				Sift.List.equals((getStorybookModules() :: any) :: { Instance }, (nextModules :: any) :: { Instance })
			then
				return
			end

			setStorybookModules(nextModules)
		end

		local function syncStoryModules(force: boolean?)
			local modules = storyModulesQueryGet()
			if force then
				setStoryModules(modules)
			else
				setStoryModulesIfChanged(modules)
			end
		end

		local function syncStorybookModules()
			setStorybookModulesIfChanged(storybookModulesQueryGet())
		end

		connections = Sift.List.join(connections, {
			storyModulesQuery.added:Connect(function()
				syncStoryModules()
			end),

			storyModulesQuery.changed:Connect(function()
				-- A story can move within the DataModel without changing query
				-- membership; publish the latest snapshot so orphaned stories
				-- recompute against updated ancestry.
				syncStoryModules(true)
			end),

			storyModulesQuery.removed:Connect(function()
				syncStoryModules()
			end),

			storybookModulesQuery.added:Connect(function(storybookModules: { Instance })
				Charm.batch(function()
					for _, storybookModule in storybookModules do
						assert(storybookModule:IsA("ModuleScript"), "Luau")
						loadStorybook(storybookModule)
					end

					syncStorybookModules()
				end)
			end),

			storybookModulesQuery.changed:Connect(function(storybookModules)
				Charm.batch(function()
					syncStorybookModules()

					for _, storybookModule in storybookModules do
						assert(storybookModule:IsA("ModuleScript"), "Luau")
						local signature = getStorybookSignature(storybookModule)
						if storybookSignatures[storybookModule] ~= signature then
							reloadStorybook(storybookModule)
						end
					end
				end)
			end),

			storybookModulesQuery.removed:Connect(function(storybookModules: { Instance })
				Charm.batch(function()
					for _, storybookModule in storybookModules do
						assert(storybookModule:IsA("ModuleScript"), "Luau")
						unloadStorybook(storybookModule)
					end

					syncStorybookModules()
				end)
			end),

			root.Destroying:Connect(stop),

			script.Destroying:Connect(stop),
		})

		local storybookModules = storybookModulesQueryGet()

		Charm.batch(function()
			syncStoryModules()
			setStorybookModulesIfChanged(storybookModules)

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
