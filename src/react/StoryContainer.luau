local React = require("@pkg/React")

local render = require("@root/render")
local types = require("@root/types")
local useStory = require("@root/hooks/useStory")

local useEffect = React.useEffect
local useRef = React.useRef

type LoadedStorybook = types.LoadedStorybook

-- TODO: Move `hooks/*` to here. This can become a separate package later

-- I should have a component provided by Storyteller for this. Then you
-- can mount something like
-- ```
-- React.createElement(Storyteller.StoryRenderer, {
--     parent = props.parent,
--     storyModule = props.storyModule,
--     storybook = props.storybook,
-- })
-- ```
-- that way the consumer doesn't need to worry about creating a
-- container+ref and running into that weird-feeling deadend at the
-- bottom of the file

local function StoryContainer(props: {
	storyModule: ModuleScript,
	storybook: LoadedStorybook,
	onError: ((message: string) -> ())?,
})
	local ref = useRef(nil :: Frame?)
	local story, err = useStory(props.storyModule, props.storybook)

	useEffect(function(): (() -> ())?
		if ref.current and story then
			local lifecycle = render(ref.current, story)

			return function()
				lifecycle.unmount()
			end
		end
		return nil
	end, { story })

	useEffect(function()
		if props.onError and err then
			props.onError(err)
		end
	end, { props.onError, err } :: { unknown })

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ref = ref,
	})
end

return StoryContainer
