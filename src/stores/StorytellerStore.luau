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

local function startsWith(haystack: string, needle: string)
	return haystack:sub(1, #needle) == needle
end

local StorytellerStore = {}

function StorytellerStore.new(root: Instance): StorytellerStore
	local self = {}

	local connections: { [string]: RBXScriptConnection } = {}
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
			setWasAnyModuleChanged(false)
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
	end

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

	local function destroy()
		instanceQueryStore.destroy()

		for _, connection in connections do
			connection:Disconnect()
		end
	end
	self.destroy = destroy

	local function onStorybookModuleRemoved(storybookModule: ModuleScript)
		unloadStorybook(storybookModule)

		for key, connection in connections do
			if startsWith(key, storybookModule:GetFullName()) then
				connection:Disconnect()
				connections[key] = nil
			end
		end
	end

	local function reloadStorybook(storybookModule: ModuleScript)
		unloadStorybook(storybookModule)
		loadStorybook(storybookModule)
	end

	local function onStorybookModuleAdded(storybookModule: ModuleScript)
		local prefix = storybookModule:GetFullName()

		loadStorybook(storybookModule)

		connections[`{prefix}_NameChanged`] = storybookModule:GetPropertyChangedSignal("Name"):Connect(function()
			reloadStorybook(storybookModule)
		end)
		connections[`{prefix}_SourceChanged`] = storybookModule:GetPropertyChangedSignal("Source"):Connect(function()
			reloadStorybook(storybookModule)
		end)

		connections[`{prefix}_AncestryChanged`] = storybookModule.AncestryChanged:Connect(function()
			if not storybookModule.Parent then
				onStorybookModuleRemoved(storybookModule)
			end
		end)
	end

	local function onStoryModuleRemoved(storyModule: ModuleScript)
		for key, connection in connections do
			if startsWith(key, storyModule:GetFullName()) then
				connection:Disconnect()
				connections[key] = nil
			end
		end
	end

	local function onStoryModuleAdded(storyModule: ModuleScript)
		local prefix = storyModule:GetFullName()

		connections[`{prefix}_AncestryChanged`] = storyModule.AncestryChanged:Connect(function()
			if not storyModule.Parent then
				onStoryModuleRemoved(storyModule)
			end
		end)
	end

	local function onInstanceAdded(instance: Instance)
		if instance:IsA("ModuleScript") then
			local prefix = instance:GetFullName()
			connections[`{prefix}_NameChanged`] = instance:GetPropertyChangedSignal("Name"):Connect(function()
				onInstanceAdded(instance)
			end)
			connections[`{prefix}_SourceChanged`] = instance:GetPropertyChangedSignal("Name"):Connect(function()
				onInstanceAdded(instance)
			end)

			if isStorybookModule(instance) then
				onStorybookModuleAdded(instance)
			end
			if isStoryModule(instance) then
				onStoryModuleAdded(instance)
			end
		end

		setWasAnyModuleChanged(true)
	end

	for _, moduleScript in getModuleScripts(false) do
		onInstanceAdded(moduleScript)
	end
	connections.DescendantAdded = root.DescendantAdded:Connect(onInstanceAdded)

	return self
end

return StorytellerStore
