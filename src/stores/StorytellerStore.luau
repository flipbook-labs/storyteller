local ModuleLoader = require("@pkg/ModuleLoader")
local Sift = require("@pkg/Sift")
local Signals = require("@rbxpkg/Signals")

local InstanceQueryStore = require("@root/stores/InstanceQueryStore")
local isOrphanedStoryModule = require("@root/isOrphanedStoryModule")
local isStoryModule = require("@root/isStoryModule")
local isStorybookModule = require("@root/isStorybookModule")
local loadStorybookModule = require("@root/loadStorybookModule")
local types = require("@root/types")

type LoadedStorybook = types.LoadedStorybook
type UnavailableStorybook = types.UnavailableStorybook
type LoadedStory<T> = types.LoadedStory<T>

export type StorytellerStore = {
	getLoadedStorybooks: Signals.getter<{ LoadedStorybook }>,
	getUnavailableStorybooks: Signals.getter<{ UnavailableStorybook }>,

	getStorybookModules: Signals.getter<{ ModuleScript }>,
	getStoryModules: Signals.getter<{ ModuleScript }>,
	getOrphanedStoryModules: Signals.getter<{ ModuleScript }>,

	destroy: () -> (),
}

local defaultStorybook: LoadedStorybook = {
	name = "Storybook",
	loader = ModuleLoader.new(),
	source = Instance.new("ModuleScript"),
	storyRoots = {},
}

local StorytellerStore = {}

function StorytellerStore.new(root: Instance): StorytellerStore
	local self = {}

	local instanceQueryStore = InstanceQueryStore.new(root, "ModuleScript")

	-- Just redefining the getter's return type since we know for sure we're
	-- getting back ModuleScripts from the query
	local getModuleScripts = Signals.createComputed(function(scope): { ModuleScript }
		return instanceQueryStore.getMatches(scope) :: any
	end)

	local getWasAnyModuleChanged, setWasAnyModuleChanged = Signals.createSignal(false)

	local effects: { Signals.dispose } = {}

	-- I also need this to recompute when any of the ModuleScripts' Name or
	-- Source changes. Does that have to be an effect?
	local getFilteredModules = Signals.createComputed(function(scope)
		local storyModules = {}
		local storybookModules = {}

		-- This is included so any time one of the ModuleScripts changes this
		-- Signal gets recomputed
		getWasAnyModuleChanged(scope)

		for _, moduleScript in getModuleScripts(scope) do
			if isStoryModule(moduleScript) then
				table.insert(storyModules, moduleScript)
			elseif isStorybookModule(moduleScript) then
				table.insert(storybookModules, moduleScript)
			end
		end

		return {
			storyModules = storyModules,
			storybookModules = storybookModules,
		}
	end)

	local getStoryModules = Signals.createComputed(function(scope)
		return getFilteredModules(scope).storyModules
	end)
	self.getStoryModules = getStoryModules

	local getStorybookModules = Signals.createComputed(function(scope)
		return getFilteredModules(scope).storybookModules
	end)
	self.getStorybookModules = getStorybookModules

	local getLoadedStorybooks, setLoadedStorybooks = Signals.createSignal({} :: { LoadedStorybook })
	self.getLoadedStorybooks = getLoadedStorybooks

	local getUnavailableStorybooks, setUnavailableStorybooks = Signals.createSignal({} :: { UnavailableStorybook })
	self.getUnavailableStorybooks = getUnavailableStorybooks

	local getStorybooksBySource = Signals.createComputed(function(scope): {
		loaded: {
			[ModuleScript]: LoadedStorybook,
		},
		unavailable: {
			[ModuleScript]: UnavailableStorybook,
		},
	}
		local loaded = {}
		local unavailable = {}

		return {
			loaded = loaded,
			unavailable = unavailable,
		}
	end)

	local disposeStorybookLoader = Signals.createEffect(function(scope)
		local connections: { RBXScriptConnection } = {}

		-- Orr I might be able to do something weird by keeping track of the
		-- last value and doing some deep comparisons?
		local prevStorybooks = getLoadedStorybooks(false)

		for _, storybookModule in getStorybookModules(scope) do
			local loader = ModuleLoader.new()

			-- keep track of the storybooks and make sure to only load/reload the minimum amount

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

			-- table.insert(connections, loader.loadedModuleChanged:Connect(reloadStorybook))
			-- table.insert(connections, storybookModule.AncestryChanged:Connect(reloadStorybook))
		end

		return function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end)

	--[[
	local getComputedStorybooks: Signals.getter<{
		available: { LoadedStorybook },
		unavailable: { UnavailableStorybook },
	}>
	getComputedStorybooks = Signals.createComputed(function(scope)
		-- These should be computed in an effect so that we can selectively reload
		-- each storybook instead of recalculating _all_ of them
		local available: { LoadedStorybook } = {}
		local unavailable: { UnavailableStorybook } = {}

		-- Orr I might be able to do something weird by keeping track of the
		-- last value and doing some deep comparisons?
		local prevStorybooks = getComputedStorybooks(false)

		for _, storybookModule in getFilteredModules(scope).storybookModules do
			-- defaultStorybook
			local storybook: LoadedStorybook?
			local success, result = pcall(function()
				storybook = loadStorybookModule(storybookModule, loader)
			end)

			table.insert(connections, loader.loadedModuleChanged:Connect(reloadStorybook))
			table.insert(connections, storybookModule.AncestryChanged:Connect(reloadStorybook))
		end

		return {
			available = available,
			unavailable = unavailable,
		}
	end)

	local getLoadedStorybooks = Signals.createComputed(function(scope)
		return getComputedStorybooks(scope).available
	end)

	local getUnavailableStorybooks = Signals.createComputed(function(scope)
		return getComputedStorybooks(scope).unavailable
	end)
	]]

	local getOrphanedStoryModules = Signals.createComputed(function(scope): { ModuleScript }
		local orphans = {}
		for _, storyModule in getStoryModules(scope) do
			if isOrphanedStoryModule(storyModule, getLoadedStorybooks(scope)) then
				table.insert(orphans, storyModule)
			end
		end
		return orphans
	end)
	self.getOrphanedStoryModules = getOrphanedStoryModules

	local disposeModuleWatcher = Signals.createEffect(function(scope)
		local connections = {}

		for _, moduleScript in getModuleScripts(scope) do
			local events = {
				moduleScript:GetPropertyChangedSignal("Name"),
				moduleScript:GetPropertyChangedSignal("Source"),
			}

			for _, event in events do
				table.insert(
					connections,
					event:Connect(function()
						setWasAnyModuleChanged(true)
					end)
				)
			end
		end

		return function()
			print("CLEANUP")
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end)

	self.destroy = function()
		instanceQueryStore.destroy()
		disposeModuleWatcher()
		disposeStorybookLoader()
	end

	return self
end

return StorytellerStore
