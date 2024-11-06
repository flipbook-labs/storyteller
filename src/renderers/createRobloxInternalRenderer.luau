local types = require("@root/types")

type StoryRenderer<T> = types.StoryRenderer<T>

type Packages = {
	React: any,
	RoactCompat: any,
	ReactRoblox: any,
}

local function isReactElement(maybeElement: any): boolean
	if typeof(maybeElement) == "table" then
		return maybeElement["$$typeof"] and maybeElement.props and maybeElement.type
	end
	return false
end

local function createRobloxInternalRenderer(packages: Packages): StoryRenderer<unknown>
	local React = packages.React
	local RoactCompat = packages.RoactCompat
	local ReactRoblox = packages.ReactRoblox

	local root
	local currentStory

	local function reactRender(story: types.Story<unknown>, props)
		local element
		if isReactElement(story.story) then
			element = story.story
		else
			element = React.createElement(story.story, props)
		end

		currentStory = story
		root:render(element)
	end

	local function mount(container, story, props)
		root = ReactRoblox.createRoot(container)
		reactRender(story, props)
	end

	local function update(props)
		if currentStory then
			reactRender(currentStory, props)
		end
	end

	local function unmount()
		root:unmount()
	end

	return {
		mount = mount,
		update = update,
		unmount = unmount,
	}
end

return createRobloxInternalRenderer
