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

	local getWasAnyModuleChanged, setWasAnyModuleChanged = Signals.createSignal(false)

	-- Just redefining the getter's return type since we know for sure we're
	-- getting back ModuleScripts from the query
	local getModuleScripts = Signals.createComputed(function(scope): { ModuleScript }
		local matches = instanceQueryStore.getMatches(scope) :: any

		-- The scope is passed so any time one of the ModuleScripts' properties
		-- change this Signal gets recomputed. This is needed so that Stories
		-- and Storybooks get recomputed when Name or Source properties change
		if getWasAnyModuleChanged(scope) then
			-- We also have to return a new object so that other computeds will
			-- see this as a different set of matches and recompute themselves
			-- too
			return table.clone(matches)
		end

		return matches
	end)

	local getStoryModules = Signals.createComputed(function(scope)
		local storyModules = {}
		for _, moduleScript in getModuleScripts(scope) do
			if isStoryModule(moduleScript) then
				table.insert(storyModules, moduleScript)
			end
		end
		return storyModules
	end)
	self.getStoryModules = getStoryModules

	local getStorybookModules = Signals.createComputed(function(scope)
		local storybookModules = {}
		for _, moduleScript in getModuleScripts(scope) do
			if isStorybookModule(moduleScript) then
				table.insert(storybookModules, moduleScript)
			end
		end
		return storybookModules
	end)
	self.getStorybookModules = getStorybookModules

	local getLoadedStorybooks, setLoadedStorybooks = Signals.createSignal({} :: { LoadedStorybook })
	self.getLoadedStorybooks = getLoadedStorybooks

	local getUnavailableStorybooks, setUnavailableStorybooks = Signals.createSignal({} :: { UnavailableStorybook })
	self.getUnavailableStorybooks = getUnavailableStorybooks

	local disposeStorybookLoader = Signals.createEffect(function(scope)
		for _, moduleScript in getModuleScripts(scope) do
			if isStorybookModule(moduleScript) then
				local loader = ModuleLoader.new()

				local storybook: LoadedStorybook?
				local success, result = pcall(function()
					storybook = loadStorybookModule(moduleScript, loader)
				end)

				if success and storybook then
					setLoadedStorybooks(function(prev)
						local new = table.clone(prev)
						local index = Sift.List.findWhere(new, function(other)
							return other.source == moduleScript
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
							return other.storybook.source == moduleScript
						end)

						if index then
							table.remove(new, index)
						end

						local unavailableStorybook: UnavailableStorybook = {
							problem = result,
							storybook = {
								name = moduleScript.Name,
								loader = loader,
								source = moduleScript,
								storyRoots = {},
							},
						}
						table.insert(new, unavailableStorybook)

						return new
					end)
				end
			end
		end
	end)

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
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end)

	-- This is the effect that takes care of reloading the individual Storybooks
	-- that change when their Name or Source properties are edited.
	local diseposeStorybookReloader = Signals.createEffect(function(scope)
		local connections: { RBXScriptConnection } = {}

		local function reloadStorybook(storybookModule: ModuleScript) end

		for _, storybookModule in getStorybookModules(scope) do
			table.insert(
				connections,
				storybookModule.AncestryChanged:Connect(function()
					reloadStorybook(storybookModule)
				end)
			)
		end

		for _, loadedStorybook in getLoadedStorybooks(scope) do
			table.insert(
				connections,
				loadedStorybook.loader.loadedModuleChanged:Connect(function()
					reloadStorybook(loadedStorybook.source)
				end)
			)
		end

		return function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end)

	local function destroy()
		instanceQueryStore.destroy()
		disposeModuleWatcher()
		disposeStorybookLoader()
		diseposeStorybookReloader()
	end
	self.destroy = destroy

	return self
end

return StorytellerStore
