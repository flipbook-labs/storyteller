local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")

local types = require("@root/types")
local useStorytellerStore = require("@root/react/useStorytellerStore")

local useEffect = React.useEffect
local useSignalState = ReactCharm.useSignalState

--[=[
	This hook triggers a rerender when the Story module or any of its required
	modules change. For example, updating the `story` property or updating a
	React component’s source will trigger useStory to rerender with the new
	content.

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
local function useStory(module: ModuleScript, storybook: types.LoadedStorybook): (types.LoadedStory<unknown>?, string?)
	local storytellerStore = useStorytellerStore()
	local records = useSignalState(storytellerStore.getStoryModuleRecords)

	useEffect(function()
		return storytellerStore.requestStoryModules({
			{
				storyModule = module,
				storybook = storybook,
			},
		}, "interactive")
	end, { module, storytellerStore, storybook } :: { unknown })

	local recordsForModule = records[module]
	local record = if recordsForModule then recordsForModule[storybook.source] else nil
	return if record then record.story else nil, if record then record.problem else nil
end

return useStory
