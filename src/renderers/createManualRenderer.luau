local types = require("@root/types")

type StoryProps = types.StoryProps
type LoadedStory<T> = types.LoadedStory<T>
type StoryRenderer<T> = types.StoryRenderer<T>

type CleanupFn = () -> ()
type ManualStory = Instance | ((props: StoryProps) -> CleanupFn?)

local function createManualRenderer(): StoryRenderer<ManualStory>
	local currentContainer: Instance?
	local currentStory: LoadedStory<ManualStory>?
	local cleanup: (() -> ())?

	local function renderStory(story: LoadedStory<ManualStory>, props: StoryProps)
		local mapStory = if story.storybook then story.storybook.mapStory else nil
		local storyValue: unknown = if mapStory then mapStory(story.story) else story.story

		local result: unknown

		if typeof(storyValue) == "Instance" then
			result = storyValue
		elseif typeof(storyValue) == "function" then
			-- A story function takes either `(props)` or `(container, props)`.
			-- `debug.info` with "a" returns how many parameters the function
			-- declares, which tells the two apart.
			local storyFn = storyValue :: (...unknown) -> unknown
			if debug.info(storyFn, "a") >= 2 then
				result = storyFn(currentContainer, props)
			else
				result = storyFn(props)
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

		if mapDefinition then
			story = mapDefinition(story) :: LoadedStory<ManualStory>
		end

		currentStory = story
		renderStory(story, props)
	end

	local function unmount()
		if cleanup then
			cleanup()
			cleanup = nil
		end

		if currentContainer then
			currentContainer:ClearAllChildren()
		end
	end

	local function update(props: StoryProps)
		unmount()
		if currentStory then
			renderStory(currentStory, props)
		end
	end

	return {
		mount = mount,
		update = update,
		unmount = unmount,
	}
end

return createManualRenderer
