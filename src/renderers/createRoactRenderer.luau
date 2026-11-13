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

	local function mount(container: Instance, story: LoadedStory<T>, props: StoryProps)
		local mapStory = if story.storybook then story.storybook.mapStory else nil
		local mapDefinition = if story.storybook then story.storybook.mapDefinition else nil
		local element

		if mapDefinition then
			story = mapDefinition(story)
		end

		if isRoactElement(story.story) then
			currentComponent = (story.story :: any).component
			element = story.story
		else
			currentComponent = story.story
			element = Roact.createElement(currentComponent, props)
		end

		-- `mapStory` usually returns a new component on every call. Mapping once
		-- keeps the component type stable, so updates don't remount the story.
		mappedStory = if mapStory then mapStory(story.story) else nil
		if mappedStory then
			element = Roact.createElement(mappedStory, props, element)
		end

		tree = Roact.mount(element, container, "RoactRenderer")
	end

	local function update(props: StoryProps)
		if tree and currentComponent then
			local element = Roact.createElement(currentComponent, props)

			if mappedStory then
				element = Roact.createElement(mappedStory, props, element)
			end

			Roact.update(tree, element)
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
