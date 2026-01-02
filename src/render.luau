local Sift = require("@pkg/Sift")

local controls = require("@root/controls")
local createRendererForStory = require("@root/createRendererForStory")
local types = require("@root/types")

type LoadedStory<T> = types.LoadedStory<T>
type StoryControls = types.StoryControls
type StoryControlsSchema = types.StoryControlsSchema
type StoryProps = types.StoryProps
type ReservedStoryProps = types.ReservedStoryProps
type ExtraStoryProps = types.ExtraStoryProps
type StoryRenderer<T> = types.StoryRenderer<T>
type RenderLifecycle = types.RenderLifecycle

--[=[
	Render a Story to an [Instance] in the [DataModel].

	After discovering, validating, and loading Story modules, rendering them is
	the final step to getting stories visually presented to the user.

	This function handles the lifecycle of mounting, updating, and unmounting
	the Story. On each update, controls can be passed down to the story for
	live-reloading from user interaction.

	**Usage:**

	```lua
	local ModuleLoader = require("@pkg/ModuleLoader")
	local Storyteller = require("@pkg/Storyteller")

	-- At least one `.storybook` module must be present
	local storybookModules = Storyteller.findStorybookModules(game)
	assert(#storybookModules > 0, "no Storybook modules found")

	local storybook
	pcall(function()
		storybook = Storyteller.loadStorybookModule(storybookModules[1])
	end)

	if storybook then
		-- At least one `.story` module must be a descendant of the Instances in
		-- a Storybook's `storyRoots` array
		local storyModules = Storyteller.findStoryModulesForStorybook(storybook)
		assert(#storyModules > 0, "no Story modules found")

		local story
		pcall(function()
			story = Storyteller.loadStoryModule(storyModules[1], storybook)
		end)

		if story then
			-- Finally, render the story to a container of your choosing
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
local function render<T>(container: Instance, story: LoadedStory<T>, initialExtraProps: ExtraStoryProps?): RenderLifecycle
	local renderer = createRendererForStory(story)

	local prevProps: StoryProps?

	local function renderOnce(storyControls: StoryControls?, extraProps: ExtraStoryProps?)
		local hydratedControls = if story.controls
			then controls.hydrateControls(story.controls, if storyControls then storyControls else {})
			else nil

		local reservedStoryProps: ReservedStoryProps = {
			container = container,
			story = story,
			controls = hydratedControls,
		}

		local props: StoryProps = Sift.Dictionary.join({
			-- DEPRECATED: This prop does nothing and is simply left for
			-- backwards compatibility. Flipbook controls this property
			-- itself to provide a dynamic value
			theme = "Dark",
		}, extraProps, story.props, reservedStoryProps)

		if renderer.transformProps then
			props = renderer.transformProps(props, prevProps)
		end

		if not renderer.shouldUpdate or renderer.shouldUpdate(props, prevProps) then
			renderer.mount(container, story, props)
		end

		prevProps = props
	end

	local function update(storyControls: StoryControls?, extraProps: ExtraStoryProps?)
		if renderer.update then
			local hydratedControls = if story.controls and storyControls
				then controls.hydrateControls(story.controls, storyControls)
				else nil

			local props = Sift.Dictionary.join(prevProps, extraProps, {
				controls = hydratedControls,
			})

			renderer.update(props, prevProps)
		else
			renderOnce(controls, extraProps)
		end
	end

	local function unmount()
		if renderer.unmount then
			renderer.unmount()
		end
		container:ClearAllChildren()
	end

	renderOnce(nil, initialExtraProps)

	return {
		update = update,
		unmount = unmount,
	}
end

return render
