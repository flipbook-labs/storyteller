local ModuleLoader = require("@pkg/ModuleLoader")
local React = require("@pkg/React")

local findStorybookModules = require("@root/findStorybookModules")
local loadStorybookModule = require("@root/loadStorybookModule")
local types = require("@root/types")

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
local function useStorybooks(parent: Instance, loader: ModuleLoader.ModuleLoader): { types.LoadedStorybook }
	local storybooks, setStorybooks = React.useState({})

	local loadStorybooks = React.useCallback(function()
		local newStorybooks = {}

		for _, storybookModule in findStorybookModules(parent) do
			local success, result = pcall(function()
				return loadStorybookModule(loader, storybookModule)
			end)

			if success then
				table.insert(newStorybooks, result)
			else
				warn(result)
			end
		end

		setStorybooks(newStorybooks)
	end, { parent, loader } :: { unknown })

	React.useEffect(function()
		local conn = loader.loadedModuleChanged:Connect(function(other)
			if types.IStorybook(other) then
				loadStorybooks()
			end
		end)

		loadStorybooks()

		return function()
			conn:Disconnect()
		end
	end, { loadStorybooks, loader } :: { unknown })

	return storybooks
end

return useStorybooks
