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
	local currentStory: LoadedStory<T>?

	local function mount(container: Instance, story: LoadedStory<T>, props: StoryProps)
		local mapStory = if story.storybook then story.storybook.mapStory else nil
		local mapDefinition = if story.storybook then story.storybook.mapDefinition else nil
		local element: unknown

		if mapDefinition then
			story = mapDefinition(story)
		end

		local roactElement = toRoactElement(story.story)
		if roactElement then
			currentComponent = roactElement.component
			element = roactElement
		else
			currentComponent = story.story
			element = Roact.createElement(currentComponent, props)
		end

		if mapStory then
			element = Roact.createElement(mapStory(story.story), props, element)
		end

		currentStory = story
		tree = Roact.mount(element, container, "RoactRenderer")
	end

	local function update(props: StoryProps)
		if tree and currentComponent then
			local element = Roact.createElement(currentComponent, props)

			local mapStory = if currentStory and currentStory.storybook then currentStory.storybook.mapStory else nil
			if currentStory and mapStory then
				element = Roact.createElement(mapStory(currentStory.story), props, element)
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
