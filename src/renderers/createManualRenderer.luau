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

	local function renderStory(story: LoadedStory<ManualStory>, props: StoryProps)
		local mapStory = if story.storybook then story.storybook.mapStory else nil
		local storyValue: Instance | ((...any) -> unknown) = if mapStory then mapStory(story.story) else story.story

		local result: unknown

		if typeof(storyValue) == "Instance" then
			result = storyValue
		elseif typeof(storyValue) == "function" then
			if debug.info(storyValue, "a") >= 2 then
				result = storyValue(currentContainer, props)
			else
				result = storyValue(props)
			end
		end

		if typeof(result) == "function" then
			cleanup = result :: CleanupFn
		elseif typeof(result) == "Instance" then
			if not result.Parent then
				result.Parent = currentContainer
			end
		end
	end

	local function mount(container: Instance, story: LoadedStory<ManualStory>, props: StoryProps)
		currentContainer = container

		local mapDefinition = if story.storybook then story.storybook.mapDefinition else nil

		-- The definition is mapped once here rather than in renderStory so
		-- that updates re-render the already-mapped story instead of
		-- transforming it a second time
		if mapDefinition then
			story = mapDefinition(story)
		end

		currentStory = story
		renderStory(story, props)
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
		renderStory(currentStory, props)
	end

	return {
		mount = mount,
		update = update,
		unmount = unmount,
	}
end

return createManualRenderer
