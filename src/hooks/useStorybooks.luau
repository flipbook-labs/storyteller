local ModuleLoader = require("@pkg/ModuleLoader")
local React = require("@pkg/React")
local Sift = require("@pkg/Sift")
local SignalsReact = require("@rbxpkg/SignalsReact")

local getStorytellerStore = require("@root/stores/getStorytellerStore")
local types = require("@root/types")

local useMemo = React.useMemo
local useSignalState = SignalsReact.useSignalState

type ModuleLoader = ModuleLoader.ModuleLoader
type LoadedStorybook = types.LoadedStorybook
type UnavailableStorybook = types.UnavailableStorybook

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
	})
		local storybooks = Storyteller.useStorybooks(props.parent)

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
local function useStorybooks(parent: Instance?): {
	available: { LoadedStorybook },
	unavailable: { UnavailableStorybook },
}
	local storytellerStore = useSignalState(getStorytellerStore)
	local available = useSignalState(storytellerStore.getLoadedStorybooks)
	local unavailable = useSignalState(storytellerStore.getUnavailableStorybooks)

	return useMemo(function()
		return {
			available = if parent
				then Sift.List.filter(available, function(loadedStorybook)
					return loadedStorybook.source:IsDescendantOf(parent)
				end)
				else available,

			unavailable = if parent
				then Sift.List.filter(unavailable, function(unavailableStorybook)
					return unavailableStorybook.storybook.source:IsDescendantOf(parent)
				end)
				else unavailable,
		}
	end, { available, unavailable, parent } :: { unknown })
end

return useStorybooks
