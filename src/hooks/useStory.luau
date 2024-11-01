local ModuleLoader = require("@pkg/ModuleLoader")
local React = require("@pkg/React")

local loadStoryModule = require("@root/loadStoryModule")
local types = require("@root/types")

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
		loader: ModuleLoader,
	})
		local ref = useRef(nil :: Frame?)

		local story = Storyteller.useStory(props.storyModule, props.storybook, props.loader)

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
	storybook: types.Storybook,
	loader: ModuleLoader.ModuleLoader
): (types.Story<unknown>?, string?)
	local state, setState = React.useState({} :: {
		story: types.Story<unknown>?,
		err: string?,
	})

	local loadStory = React.useCallback(function()
		local success, result = pcall(function()
			loadStoryModule(loader, module, storybook)
		end)

		setState({
			story = if success then result else nil,
			err = if success then nil else result,
		})
	end, { loader, module, storybook } :: { unknown })

	React.useEffect(function()
		local conn = loader.loadedModuleChanged:Connect(function(other)
			if other == module then
				loadStory()
			end
		end)

		loadStory()

		return function()
			conn:Disconnect()
		end
	end, { module, loadStory, loader } :: { unknown })

	return state.story, state.err
end

return useStory
