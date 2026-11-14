local types = require("@root/types")

type StoryRenderer<T> = types.StoryRenderer<T>
type LoadedStory<T> = types.LoadedStory<T>
type StoryProps = types.StoryProps

type Packages = {
	Roact: any,
}

local function isRoactElement(maybeElement: any): boolean
	if typeof(maybeElement) == "table" then
		return maybeElement.component and maybeElement.props
	end
	return false
end

local function createRoactRenderer<T>(packages: Packages): StoryRenderer<T>
	local Roact = packages.Roact
	local tree
	local currentComponent
	local mappedStory
	local isElementStory = false

	local function createStoryElement(props: StoryProps, storyElement: any?)
		if not mappedStory then
			return storyElement or Roact.createElement(currentComponent, props)
		elseif isElementStory then
			return Roact.createElement(mappedStory, props, storyElement or Roact.createElement(currentComponent, props))
		end
		-- The mapped component renders the story itself. Storybooks often pass
		-- their props on to the story, so children would reach it too.
		return Roact.createElement(mappedStory, props)
	end

	local function mount(container: Instance, story: LoadedStory<T>, props: StoryProps)
		local mapStory = if story.storybook then story.storybook.mapStory else nil
		local mapDefinition = if story.storybook then story.storybook.mapDefinition else nil

		if mapDefinition then
			story = mapDefinition(story)
		end

		isElementStory = isRoactElement(story.story)
		currentComponent = if isElementStory then (story.story :: any).component else story.story

		-- `mapStory` usually returns a new component on every call. Mapping once
		-- keeps the component type stable, so updates don't remount the story.
		mappedStory = if mapStory then mapStory(story.story) else nil

		local element = createStoryElement(props, if isElementStory then story.story else nil)
		tree = Roact.mount(element, container, "RoactRenderer")
	end

	local function update(props: StoryProps)
		if tree and currentComponent then
			Roact.update(tree, createStoryElement(props))
		end
	end

	local function unmount()
		if tree then
			Roact.unmount(tree)
		end
	end

	return {
		mount = mount,
		update = update,
		unmount = unmount,
	}
end

return createRoactRenderer
