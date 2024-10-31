local types = require("@root/types")

type Story<T> = types.Story<T>
type StoryRenderer<T> = types.StoryRenderer<T>

local function createRobloxRenderer(): StoryRenderer<Instance>
	local handle: Instance?
	local currentStory: Story<Instance>

	local function mount(container, story, initialProps)
		local element: Instance

		currentStory = story

		if typeof(story.story) == "function" then
			element = story.story(initialProps)
		else
			element = story.story
		end

		handle = element

		element.Parent = container
	end

	local function unmount()
		if typeof(handle) == "Instance" then
			handle:Destroy()
		end
	end

	local function update(props)
		if handle then
			local container = handle.Parent
			unmount()
			mount(container, currentStory, props)
		end
	end

	return {
		mount = mount,
		update = update,
		unmount = unmount,
	}
end

return createRobloxRenderer
