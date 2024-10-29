local types = require("@root/types")

type Story<T> = types.Story<T>
type StoryRenderer<T> = types.StoryRenderer<T>
type LegacyFunctionalStory = <T>(target: Instance, props: types.StoryProps<T>) -> (() -> ())?

local function createRobloxRenderer(): StoryRenderer<Instance>
	local handle: Instance?
	local currentStory: Story<Instance>
	local legacyCleanup: (() -> ())?
	local isOldFunctionalStoryFormat = false

	local function mount(container, story, initialProps)
		local element: Instance

		currentStory = story

		if typeof(story.story) == "function" then
			-- For backwards compatability. The older format of functional
			-- stories takes in the parent as the first argument, followed by
			-- props. This call to debug.info lets us know how many args the
			-- function takes so we can conditionally pass in the container to
			-- support older stories. This should be removed in a future major
			-- version
			if debug.info(story.story, "a") >= 2 then
				isOldFunctionalStoryFormat = true
				local legacyStory = (story.story :: any) :: LegacyFunctionalStory
				legacyCleanup = legacyStory(container, initialProps)
			else
				element = story.story(initialProps)
			end
		else
			element = story.story
		end

		handle = element

		if not isOldFunctionalStoryFormat then
			element.Parent = container
		end
	end

	local function unmount()
		if isOldFunctionalStoryFormat then
			if legacyCleanup then
				legacyCleanup()
			end
		else
			if typeof(handle) == "Instance" then
				handle:Destroy()
			end
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
