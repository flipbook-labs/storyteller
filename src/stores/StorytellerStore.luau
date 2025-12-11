local ModuleLoader = require("@pkg/ModuleLoader")
local Sift = require("@pkg/Sift")
local Signals = require("@rbxpkg/Signals")

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
	getLoadedStorybooks: Signals.getter<{ LoadedStorybook }>,
	getUnavailableStorybooks: Signals.getter<{ UnavailableStorybook }>,

	getStorybookModules: Signals.getter<{ ModuleScript }>,
	getStoryModules: Signals.getter<{ ModuleScript }>,
	getOrphanedStoryModules: Signals.getter<{ ModuleScript }>,

	destroy: () -> (),
}

local StorytellerStore = {}

function StorytellerStore.new(root: Instance): StorytellerStore
	local self = {}

	local connections: { RBXScriptConnection } = {}
	local effects: { Signals.dispose } = {}

	local isDestroyed = false

	local getStoryModules, setStoryModules = Signals.createSignal({} :: { ModuleScript })
	self.getStoryModules = getStoryModules

	local getStorybookModules, setStorybookModules = Signals.createSignal({} :: { ModuleScript })
	self.getStorybookModules = getStorybookModules

	local getLoadedStorybooks, setLoadedStorybooks = Signals.createSignal({} :: { LoadedStorybook })
	self.getLoadedStorybooks = getLoadedStorybooks

	local getUnavailableStorybooks, setUnavailableStorybooks = Signals.createSignal({} :: { UnavailableStorybook })
	self.getUnavailableStorybooks = getUnavailableStorybooks

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

	local storyModulesQuery = query({
		roots = { root },
		selector = "ModuleScript",
		matcher = isStoryModule,
	})

	local storybookModulesQuery = query({
		roots = { root },
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

	local function reloadStorybook(storybookModule: ModuleScript)
		unloadStorybook(storybookModule)
		loadStorybook(storybookModule)
	end

	local function destroy()
		if isDestroyed then
			return
		end

		storybookModulesQuery.destroy()
		storyModulesQuery.destroy()

		for _, connection in connections do
			connection:Disconnect()
		end

		for _, dispose in effects do
			dispose()
		end

		isDestroyed = true
	end
	self.destroy = destroy

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
			for _, storybookModule in storybookModules do
				assert(storybookModule:IsA("ModuleScript"), "Luau")
				loadStorybook(storybookModule)
			end

			setStorybookModules(storybookModulesQueryGet())
		end),

		storybookModulesQuery.changed:Connect(function(storybookModules)
			setStorybookModules(storybookModulesQueryGet())

			for _, storybookModule in storybookModules do
				assert(storybookModule:IsA("ModuleScript"), "Luau")
				reloadStorybook(storybookModule)
			end
		end),

		storybookModulesQuery.removed:Connect(function(storybookModules: { Instance })
			for _, storybookModule in storybookModules do
				assert(storybookModule:IsA("ModuleScript"), "Luau")
				unloadStorybook(storybookModule)
			end

			setStorybookModules(storybookModulesQueryGet())
		end),

		root.Destroying:Connect(destroy),

		script.Destroying:Connect(destroy),
	})

	local storybookModules = storybookModulesQueryGet()

	setStoryModules(storyModulesQueryGet())
	setStorybookModules(storybookModules)

	for _, storybookModule in storybookModules do
		loadStorybook(storybookModule)
	end

	return self
end

return StorytellerStore
