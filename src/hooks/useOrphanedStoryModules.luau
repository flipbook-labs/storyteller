local React = require("@pkg/React")
local Sift = require("@pkg/Sift")
local SignalsReact = require("@rbxpkg/SignalsReact")

local getStorytellerStore = require("@root/stores/getStorytellerStore")

local useMemo = React.useMemo
local useSignalState = SignalsReact.useSignalState

--[=[
	This hook is used for the discovery of Story modules that are not associated
	with any Storybooks. These are known as "orphaned" or "unknown" stories

	This hook should be used in conjunction with `useStorybooks` so that a list
	of the available storybooks is determined first, otherwise all stories would
	come back as orphans.

	:::info
	In the future version hooks may be migrated to a new package to remove the
	React dependency from Storyteller.
	:::

	Usage:

	```lua
	local React = require("@pkg/React")
	local Storyteller = require("@pkg/Storyteller")

	local e = React.createElement

	local function OrphanList(props: {
		parent: Instance,
	})
		local storybooks = Storyteller.useStorybooks(props.parent)
		local orphanedStoryModules = Storyteller.useOrphanedStoryModules(props.parent, storybooks.available)

		local children = {}
		for index, orphanedStoryModule in orphanedStoryModules do
			children[orphanedStoryModule.Name] = e("TextLabel", {
				Text = orphanedStoryModule.Name,
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

	return OrphanList
	```

	@tag React
	@tag Story
	@within Storyteller
]=]
local function useOrphanedStoryModules(parent: Instance?): { ModuleScript }
	local storytellerStore = useSignalState(getStorytellerStore)
	local orphanedStoryModules = useSignalState(storytellerStore.getOrphanedStoryModules)

	return useMemo(function()
		if parent then
			return Sift.List.filter(orphanedStoryModules, function(orphanedStoryModule)
				return orphanedStoryModule:IsDescendantOf(parent)
			end)
		end

		return orphanedStoryModules
	end, { parent, orphanedStoryModules })
end

return useOrphanedStoryModules
