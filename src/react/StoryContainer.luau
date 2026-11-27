local React = require("@pkg/React")

local logger = require("@root/logger")
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
	local ref = useRef<<Frame?>>(nil)
	local lifecycle = useRef<<RenderLifecycle?>>(nil)
	local prevStory = usePrevious(props.story)
	local prevExtraProps = usePrevious(props.extraProps)
	local prevControls = usePrevious(props.controls)

	local mount = useCallback(function()
		if lifecycle.current then
			return
		end

		if not ref.current then
			return
		end

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

		local previousLifecycle = lifecycle.current
		lifecycle.current = nil

		--[[
			The lifecycle's `unmount` runs the Story's teardown, such as
			unmounting a React Story's root, and that can throw. A React root
			throws when a new version of its Story replaces it while its
			previous render is still in progress.

			This runs from an effect, so an error would propagate up the React
			tree that hosts this container and unmount all of it. The error is
			logged as a warning instead. It isn't passed to `onError`, because
			this also runs when one Story replaces another, and the host would
			then show an error in place of the new Story for a failure in the
			old one.

			A throwing teardown also stops the lifecycle before it clears the
			container, so the container is cleared here. Otherwise the old
			Story's instances would stay next to the next Story's.
		]]
		local success, result = xpcall(function()
			previousLifecycle.unmount()
		end, debug.traceback)
		if not success then
			logger.warn("failed to unmount story", result)
			if ref.current then
				ref.current:ClearAllChildren()
			end
		end
	end, {})

	-- Main mounting and unmounting logic
	useEffect(
		function()
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
		end,
		{
			mount,
			unmount,
			props.story,
			prevStory,
		} :: { unknown }
	)

	-- Unmount when the StoryContainer does
	useEffect(function()
		return unmount
	end, {})

	-- Update when extraProps change
	useEffect(
		function()
			local didStoryChange = prevStory and props.story == prevStory
			local didControlsChange = prevControls and props.controls ~= prevControls
			local didExtraPropsChange = prevExtraProps and props.extraProps ~= prevExtraProps

			if lifecycle.current and (didStoryChange or didControlsChange or didExtraPropsChange) then
				update()
			end
		end,
		{
			update,
			props.story,
			prevStory,
			props.extraProps,
			prevExtraProps,
			props.onError,
		} :: { unknown }
	)

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ref = ref,
	})
end

return StoryContainer
