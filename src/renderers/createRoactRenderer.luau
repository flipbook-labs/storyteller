local types = require("@root/types")

type StoryRenderer<T> = types.StoryRenderer<T>
type LoadedStory<T> = types.LoadedStory<T>
type StoryProps = types.StoryProps

type RoactTree = unknown

-- Storybooks supply their own copy of Roact, so these types describe only the
-- parts of it that this renderer uses.
type Packages = {
	Roact: {
		createElement: (component: unknown, props: unknown?, ...unknown) -> unknown,
		mount: (element: unknown, container: Instance, name: string) -> RoactTree,
		update: (tree: RoactTree, element: unknown) -> RoactTree,
		unmount: (tree: RoactTree) -> (),
	},
}

type RoactElement = {
	component: unknown,
	props: unknown,
}

local function toRoactElement(maybeElement: unknown): RoactElement?
	if typeof(maybeElement) == "table" then
		local element = maybeElement :: { [string]: unknown }
		if element.component ~= nil and element.props ~= nil then
			return element :: RoactElement
		end
	end
	return nil
end

local function createRoactRenderer<T>(packages: Packages): StoryRenderer<T>
	local Roact = packages.Roact
	local tree: RoactTree?
	local currentComponent: unknown
	local mappedStory: unknown
	local isElementStory = false

	local function createStoryElement(props: StoryProps, storyElement: unknown?): unknown
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

		local roactElement = toRoactElement(story.story)
		isElementStory = roactElement ~= nil
		currentComponent = if roactElement then roactElement.component else story.story

		-- `mapStory` usually returns a new component on every call. Mapping once
		-- keeps the component type stable, so updates don't remount the story.
		mappedStory = if mapStory then mapStory(story.story) else nil

		local element = createStoryElement(props, roactElement)
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
