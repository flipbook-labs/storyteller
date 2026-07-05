local types = require("@root/types")

type StoryProps = types.StoryProps
type LoadedStory<T> = types.LoadedStory<T>
type StoryRenderer<T> = types.StoryRenderer<T>

type CleanupFn = () -> ()
type ManualStory = Instance | ((props: StoryProps) -> CleanupFn?)

local function createManualRenderer(): StoryRenderer<ManualStory>
	local currentContainer
	local currentStory
	local cleanup: (() -> ())?

	local function mount(container: Instance, story: LoadedStory<ManualStory>, props: StoryProps)
		currentContainer = container
		currentStory = story

		local mapStory = if story.storybook then story.storybook.mapStory else nil
		local storyValue: Instance | ((...any) -> any) = if mapStory then mapStory(story.story) else story.story

		local result

		if typeof(storyValue) == "Instance" then
			result = storyValue
		elseif typeof(storyValue) == "function" then
			if debug.info(storyValue, "a") >= 2 then
				result = storyValue(container, props)
			else
				result = storyValue(props)
			end
		end

		if typeof(result) == "function" then
			cleanup = result
		elseif typeof(result) == "Instance" then
			if not result.Parent then
				result.Parent = container
			end
		end
	end

	local function unmount()
		if cleanup then
			cleanup()
			cleanup = nil
		end

		currentContainer:ClearAllChildren()
	end

	local function update(props)
		unmount()
		mount(currentContainer, currentStory, props)
	end

	return {
		mount = mount,
		update = update,
		unmount = unmount,
	}
end

return createManualRenderer
