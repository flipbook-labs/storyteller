local Sift = require("@pkg/Sift")

local types = require("@root/types")

type Story<T> = types.Story<T>
type StoryControls = types.StoryControls
type StoryProps<T> = types.StoryProps<T>
type StoryRenderer<T> = types.StoryRenderer<T>

local function render<T>(renderer: StoryRenderer<T>, container: Instance, story: Story<T>)
	local prevProps: StoryProps<T>?

	local function renderOnce(controls: StoryControls?)
		local props: StoryProps<T> = {
			container = container,
			story = story,
			theme = "Dark", -- TODO: Support theme changing
		}

		props.controls = if story.controls
			then Sift.Dictionary.join(story.controls, if controls then controls else {})
			else {}

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
