local types = require("@root/types")

type StoryRenderer<T> = types.StoryRenderer<T>

type Packages = {
	React: any,
	ReactRoblox: any,
}

local function createReactRenderer(packages: Packages): StoryRenderer<unknown>
	local React = packages.React
	local ReactRoblox = packages.ReactRoblox

	local root
	local currentStory

	local function reactRender(story, props)
		local element = React.createElement(story.story, props)
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

return createReactRenderer
