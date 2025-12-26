local React = require("@pkg/React")

local render = require("@root/render")
local types = require("@root/types")
local usePrevious = require("@root/react/usePrevious")

local useCallback = React.useCallback
local useEffect = React.useEffect
local useRef = React.useRef

type LoadedStorybook = types.LoadedStorybook
type LoadedStory<T> = types.LoadedStory<T>
type RenderLifecycle = types.RenderLifecycle
type StoryControls = types.StoryControls
type ExtraStoryProps = types.ExtraStoryProps

local function StoryContainer(props: {
	story: LoadedStory<unknown>,
	controls: StoryControls?,
	extraProps: ExtraStoryProps?,
	onError: ((message: string) -> ())?,
})
	local ref = useRef(nil :: Frame?)
	local lifecycle = useRef(nil :: RenderLifecycle?)
	local prevStory = usePrevious(props.story)
	local prevExtraProps = usePrevious(props.extraProps)
	local prevControls = usePrevious(props.controls)

	local mount = useCallback(function()
		if lifecycle.current then
			return
		end

		if not ref.current then
			-- logger:Warn("attempted to mount story before ref was ready")
			return
		end

		-- logger:Debug("mounting story")

		local success, result = xpcall(function()
			lifecycle.current = render(ref.current, props.story, props.extraProps)
		end, debug.traceback)

		if not success and props.onError then
			props.onError(result)
		end
	end, { props.story, props.extraProps, props.onError } :: { unknown })

	local update = useCallback(function()
		if not lifecycle.current then
			return
		end

		-- logger:Debug("updating story")

		local success, result = xpcall(function()
			lifecycle.current.update(props.controls, props.extraProps)
		end, debug.traceback)

		if not success and props.onError then
			props.onError(result)
		end
	end, { props.controls, props.extraProps, props.onError } :: { unknown })

	local unmount = useCallback(function()
		if not lifecycle.current then
			return
		end

		-- logger:Debug("unmounting story")

		lifecycle.current.unmount()
		lifecycle.current = nil
	end, {})

	-- Main mounting and unmounting logic
	useEffect(function()
		local isFirstRender = prevStory == nil
		local didStoryChange = prevStory and props.story ~= prevStory

		if isFirstRender and ref.current then
			mount()
			return
		end

		if didStoryChange then
			unmount()

			if ref.current and props.story then
				mount()
			end
		end
	end, { mount, unmount, props.story, prevStory } :: { unknown })

	-- Unmount when the StoryContainer does
	useEffect(function()
		return unmount
	end, {})

	-- Update when extraProps change
	useEffect(function()
		local didStoryChange = prevStory and props.story == prevStory
		local didControlsChange = prevControls and props.controls ~= prevControls
		local didExtraPropsChange = prevExtraProps and props.extraProps ~= prevExtraProps

		if lifecycle.current and (didStoryChange or didControlsChange or didExtraPropsChange) then
			update()
		end
	end, { update, props.story, prevStory, props.extraProps, prevExtraProps, props.onError } :: { unknown })

	return React.createElement("Frame", {
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		ref = ref,
	})
end

return StoryContainer
