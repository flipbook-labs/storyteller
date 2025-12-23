local React = require("@pkg/React")

local render = require("@root/render")
local types = require("@root/types")
local useStory = require("@root/react/useStory")

local useEffect = React.useEffect
local useRef = React.useRef

type LoadedStorybook = types.LoadedStorybook
type RenderLifecycle = types.RenderLifecycle

local function StoryContainer(props: {
	storyModule: ModuleScript,
	storybook: LoadedStorybook,
	extraProps: { [string]: any }?,
	onError: ((message: string) -> ())?,
})
	local ref = useRef(nil :: Frame?)
	local story, err = useStory(props.storyModule, props.storybook)
	local lifecycle = useRef(nil :: RenderLifecycle?)

	-- TODO: Throw an error if `extraProps` includes any props that Storyteller
	-- owns. Like `container`. These props will silently get discarded and
	-- Storyteller will use its own

	useEffect(function()
		if ref.current and story then
			local success, result = xpcall(function()
				lifecycle.current = render(ref.current, story, props.extraProps)
			end, debug.traceback)

			if not success and props.onError then
				props.onError(result)
			end
		end

		return function()
			if lifecycle.current then
				lifecycle.current.unmount()
				lifecycle.current = nil
			end
		end
	end, { story })

	-- TODO: Work out the update loop. The following is ripped from Flipbook
	-- useEffect(function()
	-- 	if props.story == prevStory and props.controls ~= prevControls then
	-- 		local areControlsDifferent = prevControls and not Sift.Dictionary.equals(props.controls, prevControls)

	-- 		if lifecycle.current and areControlsDifferent then
	-- 			local success, result = xpcall(function()
	-- 				lifecycle.current.update(props.controls)
	-- 			end, debug.traceback)

	-- 			if not success then
	-- 				setErr(result)
	-- 			end
	-- 		end
	-- 	end
	-- end, { props.controls, prevControls, props.story, prevStory } :: { unknown })

	useEffect(function()
		-- TODO: Make this this doesn't get called too often. Might need to add
		-- an `err ~= prevErr` check to debounce
		if props.onError and err then
			props.onError(err)
		end
	end, { props.onError, err } :: { unknown })

	return React.createElement("Frame", {
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		ref = ref,
	})
end

return StoryContainer
