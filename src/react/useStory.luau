local types = require("@root/types")
local useStoriesForModule = require("@root/react/useStoriesForModule")

--[=[
	This hook triggers a rerender when the Story module or any of its required
	modules change. For example, updating the `story` property or updating a
	React component’s source will trigger useStory to rerender with the new
	content. Pass a `storyId` to select one Story from a multi-Story module. If
	the ID is omitted or unavailable, the first Story is returned for backward
	compatibility.

	:::info
	In the future version hooks may be migrated to a new package to remove the React dependency from Storyteller.
	:::

	Usage:

	```lua
	local React = require("@pkg/React")
	local Storyteller = require("@pkg/Storyteller")

	local useEffect = React.useEffect
	local useRef = React.useRef
	local e = React.createElement

	local function StoryView(props: {
		parent: Instance,
		storyModule: ModuleScript,
		storybook: Storybook,
	})
		local ref = useRef(nil :: Frame?)

		local story = Storyteller.useStory(props.storyModule, props.storybook)

		useEffect(function()
			if ref.current then
				local renderer = Storyteller.createRendererForStory(story)
				Storyteller.render(renderer, ref.current, story)
			end
		end, { story })

		return e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ref = ref,
		})
	end

	return StoryView
	```

	@tag React
	@tag Story
	@within Storyteller
]=]
local function useStory(
	module: ModuleScript,
	storybook: types.LoadedStorybook,
	storyId: string?
): (types.LoadedStory<unknown>?, string?)
	local stories, err = useStoriesForModule(module, storybook)
	if not stories then
		return nil, err
	end

	if storyId then
		for _, story in stories do
			if story.id == storyId then
				return story, err
			end
		end
	end

	return stories[1], err
end

return useStory
