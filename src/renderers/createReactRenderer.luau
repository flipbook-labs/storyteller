local types = require("@root/types")

type StoryRenderer<T> = types.StoryRenderer<T>
type LoadedStory<T> = types.LoadedStory<T>
type StoryProps = types.StoryProps

-- Storybooks supply their own copy of React, so these types describe only the
-- parts of it that this renderer uses.
type ReactRoot = {
	render: (self: ReactRoot, element: unknown) -> (),
	unmount: (self: ReactRoot) -> (),
}

type Packages = {
	React: {
		createElement: (component: unknown, props: unknown?, ...unknown) -> unknown,
	},
	ReactRoblox: {
		createRoot: (container: Instance) -> ReactRoot,
	},
}

local function isReactElement(maybeElement: unknown): boolean
	if typeof(maybeElement) == "table" then
		local element = maybeElement :: { [string]: unknown }
		return element["$$typeof"] ~= nil and element.props ~= nil and element.type ~= nil
	end
	return false
end

local function createReactRenderer<T>(packages: Packages): StoryRenderer<T>
	local React = packages.React
	local ReactRoblox = packages.ReactRoblox

	local root: ReactRoot?
	local currentStory: LoadedStory<unknown>?
	local mappedStory: unknown

	local function reactRender(story: types.LoadedStory<unknown>, props: StoryProps)
		local element: unknown
		if isReactElement(story.story) then
			element = story.story
			if mappedStory then
				element = React.createElement(mappedStory, props, element)
			end
		elseif mappedStory then
			-- The mapped component renders the story itself. Storybooks often
			-- pass their props on to the story, so children would reach it too.
			element = React.createElement(mappedStory, props)
		else
			element = React.createElement(story.story, props)
		end

		currentStory = story
		if root then
			root:render(element)
		end
	end

	local function mount(container: Instance, story: LoadedStory<T>, props: StoryProps)
		local mapDefinition = if story.storybook then story.storybook.mapDefinition else nil

		if mapDefinition then
			story = mapDefinition(story)
		end

		-- `mapStory` usually returns a new component on every call. Mapping once
		-- keeps the component type stable, so updates don't remount the story.
		local mapStory = if story.storybook then story.storybook.mapStory else nil
		mappedStory = if mapStory then mapStory(story.story) else nil

		root = ReactRoblox.createRoot(container)
		reactRender(story, props)
	end

	local function update(props: StoryProps)
		if currentStory then
			reactRender(currentStory, props)
		end
	end

	local function unmount()
		if root then
			root:unmount()
		end
	end

	return {
		mount = mount,
		update = update,
		unmount = unmount,
	}
end

return createReactRenderer
