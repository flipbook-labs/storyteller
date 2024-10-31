local Sift = require("@pkg/Sift")

local createRendererForStory = require("@root/createRendererForStory")
local types = require("@root/types")

type Story<T> = types.Story<T>
type StoryControls = types.StoryControls
type StoryProps = types.StoryProps
type StoryRenderer<T> = types.StoryRenderer<T>

local function collapseControls(controls: StoryControls): StoryControls
	return Sift.Dictionary.map(controls, function(control)
		-- Array values are collapsed to their first element to be passed off to
		-- the story as props
		if Sift.List.is(control) then
			return control[1]
		else
			return control
		end
	end)
end

local function render<T>(container: Instance, story: Story<T>)
	local renderer = createRendererForStory(story)

	local prevProps: StoryProps?

	local function renderOnce(controls: StoryControls?)
		local props: StoryProps = {
			container = container,
			story = story,
			theme = "Dark", -- TODO: Support theme changing
		}

		props.controls = Sift.Dictionary.join(
			if story.controls then collapseControls(story.controls) else nil,
			if controls then controls else nil
		)

		if renderer.transformProps then
			props = renderer.transformProps(props, prevProps)
		end

		if not renderer.shouldUpdate or renderer.shouldUpdate(props, prevProps) then
			renderer.mount(container, story, props)
		end

		prevProps = props
	end

	local function update(newControls: StoryControls?)
		if renderer.update then
			local props = Sift.Dictionary.join(prevProps, {
				controls = newControls,
			})

			renderer.update(props, prevProps)
		else
			renderOnce(newControls)
		end
	end

	local function unmount()
		if renderer.unmount then
			renderer.unmount()
		end
		container:ClearAllChildren()
	end

	renderOnce()

	return {
		update = update,
		unmount = unmount,
	}
end

return render
