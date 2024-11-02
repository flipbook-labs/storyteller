local Sift = require("@pkg/Sift")

local createRendererForStory = require("@root/createRendererForStory")
local types = require("@root/types")

type Story<T> = types.Story<T>
type StoryControls = types.StoryControls
type StoryProps = types.StoryProps
type StoryRenderer<T> = types.StoryRenderer<T>
type RenderLifecycle = types.RenderLifecycle

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

--[=[
	The final step. Once you have your Storybook, a Story to render, and the
	renderer to use for the Story, this function will handle the lifecycle of
	mounting, updating, and unmounting the Story for viewing.


	:::info
	We may update this function to make `renderer` an optional last argument in
	the future so that `createRendererForStory` can be called implicitly.
	Determining which renderer to use probably doesn’t need to be the consumer’s
	job.
	:::

	Usage:

	```lua
	local ModuleLoader = require("@pkg/ModuleLoader")
	local Storyteller = require("@pkg/Storyteller")

	local loader = ModuleLoader.new()

	local storybookModules = Storyteller.findStorybookModules(game)
	assert(#storybookModules > 0, "no Storybook modules found")

	local storybook
	pcall(function()
		storybook = Storyteller.loadStorybookModule(loader, storybookModules[1])
	end)

	if storybook then
		local storyModules = Storyteller.findStoryModulesForStorybook(storybook)
		assert(#storyModules > 0, "no Story modules found")

		local story
		pcall(function()
			story = Storyteller.loadStoryModule(loader, storyModules[1], storybook)
		end)

		if story then
			local lifecycle = Storyteller.render(container, story)

			print(container:GetChildren())

				lifecycle.unmount()

			print(container:GetChildren())
		end
	end
	```

	@tag Rendering
	@within Storyteller
]=]
local function render<T>(container: Instance, story: Story<T>): RenderLifecycle
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
