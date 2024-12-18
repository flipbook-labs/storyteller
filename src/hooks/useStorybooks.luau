local ModuleLoader = require("@pkg/ModuleLoader")
local React = require("@pkg/React")

local findStorybookModules = require("@root/findStorybookModules")
local isStorybookModule = require("@root/isStorybookModule")
local loadStorybookModule = require("@root/loadStorybookModule")
local types = require("@root/types")

local useRef = React.useRef
local useState = React.useState
local useCallback = React.useCallback

export type UnavailableStorybook = {
	problem: string,
	storybook: types.LoadedStorybook,
}

--[=[
	Performs all the discovery and loading of Storybook modules that would
	normally be done via individual API members.

	This hook makes it possible to conveniently load (and reload) Storybooks for
	use in React UI.

	:::info
	In the future version hooks may be migrated to a new package to remove the React dependency from Storyteller.
	:::

	Usage:

	```lua
	local React = require("@pkg/React")
	local Storyteller = require("@pkg/Storyteller")

	local e = React.createElement

	local function StorybookList(props: {
		parent: Instance,
		loader: ModuleLoader,
	})
		local storybooks = Storyteller.useStorybooks(props.parent, props.loader)

		local children = {}
		for index, storybook in storybooks do
			children[storybook.name] = e("TextLabel", {
				Text = storybook.name,
				LayoutOrder = index,
			}),
		end

		return e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, {
			Layout = e("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder
			}),
		}, children)
	end

	return StorybookList
	```

	This hook triggers a rerender when a Storybook module changes. For example,
	updating the `storyRoots` of a Storybook will trigger a rerender, and when
	paired with `useStory` you can get live updates to which Stories a Storybook
	manages.

	@tag React
	@tag Storybook
	@within Storyteller
]=]
local function useStorybooks(parent: Instance): {
	available: { types.LoadedStorybook },
	unavailable: { UnavailableStorybook },
}
	local storybooks, setStorybooks = useState({})
	local unavailableStorybooks, setUnavailableStorybooks = useState({} :: { UnavailableStorybook })

	local loaders = useRef({} :: { [ModuleScript]: ModuleLoader.ModuleLoader })

	local getOrCreateLoader = useCallback(function(storybookModule: ModuleScript)
		local existingLoader = loaders.current[storybookModule]
		if existingLoader then
			return existingLoader
		else
			local loader = ModuleLoader.new()
			loaders.current[storybookModule] = loader
			return loader
		end
	end, {})

	local loadStorybooks = useCallback(function()
		local newStorybooks = {}
		local newUnavailableStorybooks: { UnavailableStorybook } = {}

		for _, storybookModule in findStorybookModules(parent) do
			local loader = getOrCreateLoader(storybookModule)

			-- TODO: Do we need to clear the loader first?

			local storybook: types.LoadedStorybook?
			local success, result = pcall(function()
				storybook = loadStorybookModule(storybookModule, loader)
			end)

			if success then
				table.insert(newStorybooks, storybook)
			else
				table.insert(newUnavailableStorybooks, {
					problem = result,
					storybook = {
						name = storybookModule.Name,
						loader = loader,
						storyRoots = {},
					},
				})
			end
		end

		setStorybooks(newStorybooks)
		setUnavailableStorybooks(newUnavailableStorybooks)
	end, { parent, getOrCreateLoader } :: { unknown })

	React.useEffect(function()
		local function reloadIfStorybook(instance: Instance)
			if isStorybookModule(instance) then
				loadStorybooks()
			end
		end

		local connections = {
			parent.DescendantAdded:Connect(reloadIfStorybook),
		}

		for _, loader in loaders.current do
			table.insert(connections, loader.loadedModuleChanged:Connect(reloadIfStorybook))
		end

		loadStorybooks()

		return function()
			for _, conn in connections do
				conn:Disconnect()
			end
		end
	end, { loadStorybooks, parent } :: { unknown })

	return {
		available = storybooks,
		unavailable = unavailableStorybooks,
	}
end

return useStorybooks
