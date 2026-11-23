local JestGlobals = require("@pkg/JestGlobals")
local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")

local StoryModuleRequestPriority = require("@root/stores/enums/StoryModuleRequestPriority")
local StorytellerStore = require("@root/stores/StorytellerStore")
local renderHook = require("@root/test-utils/renderHook")
local types = require("@root/types")
local useStories = require("./useStories")
local waitFor = require("@root/test-utils/waitFor")

local expect = JestGlobals.expect
local test = JestGlobals.test
local act = ReactRoblox.act

test("loads every story from a module", function()
	local storyModule = Instance.new("ModuleScript")
	storyModule.Name = "Sample.story"
	storyModule.Source = [[
		return {
			stories = {
				{ name = "First", story = function() end },
				{ name = "Second", story = function() end },
			},
		}
	]]

	local storybook: types.LoadedStorybook = {
		name = "Storybook",
		source = Instance.new("ModuleScript"),
		storyRoots = {},
	}

	local get = renderHook(function()
		return useStories(storyModule, storybook)
	end)
	act(function()
		task.wait(0.1)
	end)

	local stories: { types.LoadedStory<unknown> }?
	waitFor(function()
		local err: string?
		stories, err = get()
		expect(err).toBeUndefined()
		expect(stories).toBeDefined()
	end)

	expect(stories).toEqual({
		expect.objectContaining({
			id = "First",
			name = "First",
		}),
		expect.objectContaining({
			id = "Second",
			name = "Second",
		}),
	})

	storybook.source:Destroy()
	storyModule:Destroy()
end)

test("unrelated record updates do not rerender a loaded story", function()
	local storyModule = Instance.new("ModuleScript")
	storyModule.Name = "Selected.story"
	storyModule.Source = [[return { story = function() end }]]
	local unrelatedModule = Instance.new("ModuleScript")
	unrelatedModule.Name = "Unrelated.story"
	unrelatedModule.Source = [[return { story = function() end }]]
	local storybook: types.LoadedStorybook = {
		name = "Storybook",
		source = Instance.new("ModuleScript"),
		storyRoots = {},
	}

	local renderCount = 0
	local get = renderHook(function()
		renderCount += 1
		return useStories(storyModule, storybook)
	end)

	act(function()
		task.wait(0.1)
	end)
	waitFor(function()
		local stories = get()
		assert(stories, "expected the selected story to load")
		expect(stories[1].name).toBe("Selected")
	end)
	local countAfterSelectedLoad = renderCount

	local releaseUnrelated = StorytellerStore.get().requestStoryModule(StoryModuleRequestPriority.Background, {
		storyModule = unrelatedModule,
		storybook = storybook,
	})
	act(function()
		task.wait(0.1)
	end)
	waitFor(function()
		local record = StorytellerStore.get().getStoryModuleRecord({
			storyModule = unrelatedModule,
			storybook = storybook,
		})
		assert(record and record.stories, "expected the unrelated story to load")
		expect(record.stories[1].name).toBe("Unrelated")
	end)

	expect(renderCount).toBe(countAfterSelectedLoad)
	releaseUnrelated()
	act(function()
		task.wait()
	end)
	expect(renderCount).toBe(countAfterSelectedLoad)
	storybook.source:Destroy()
	storyModule:Destroy()
	unrelatedModule:Destroy()
end)

test("surfaces a problem for a malformed module", function()
	local storyModule = Instance.new("ModuleScript")
	storyModule.Name = "Malformed.story"
	storyModule.Source = "syntax error"

	local storybook: types.LoadedStorybook = {
		name = "Storybook",
		source = Instance.new("ModuleScript"),
		storyRoots = {},
	}

	local get = renderHook(function()
		return useStories(storyModule, storybook)
	end)
	act(function()
		task.wait(0.1)
	end)

	waitFor(function()
		local stories, problem = get()
		expect(stories).toBeUndefined()
		expect(problem).toBeDefined()
	end)

	storybook.source:Destroy()
	storyModule:Destroy()
end)

test("switching the storybook source reloads from the new source and releases the old hold", function()
	local storyModule = Instance.new("ModuleScript")
	storyModule.Name = "Switched.story"
	storyModule.Source = [[return { story = function() end }]]

	local firstStorybook: types.LoadedStorybook = {
		name = "First",
		source = Instance.new("ModuleScript"),
		storyRoots = {},
	}
	local secondStorybook: types.LoadedStorybook = {
		name = "Second",
		source = Instance.new("ModuleScript"),
		storyRoots = {},
	}

	-- Another consumer holds the first Storybook's entry, so the hook's cleanup
	-- must release only its own hold.
	local releaseOther = StorytellerStore.get().requestStoryModule(StoryModuleRequestPriority.Background, {
		storyModule = storyModule,
		storybook = firstStorybook,
	})

	local setStorybook: (storybook: types.LoadedStorybook) -> ()
	local get = renderHook(function()
		local storybook, setState = React.useState(firstStorybook)
		setStorybook = setState
		return useStories(storyModule, storybook)
	end)
	act(function()
		task.wait(0.1)
	end)

	waitFor(function()
		local stories = get()
		assert(stories, "expected the first Storybook's stories to load")
		expect(stories[1].storybook).toBe(firstStorybook)
	end)

	act(function()
		setStorybook(secondStorybook)
	end)
	act(function()
		task.wait(0.1)
	end)

	waitFor(function()
		local stories = get()
		assert(stories, "expected the second Storybook's stories to load")
		expect(stories[1].name).toBe("Switched")
		expect(stories[1].storybook).toBe(secondStorybook)
	end)

	local firstRecord = StorytellerStore.get().getStoryModuleRecord({
		storyModule = storyModule,
		storybook = firstStorybook,
	})
	assert(firstRecord and firstRecord.stories, "expected the other consumer to keep the first record")

	releaseOther()
	expect(StorytellerStore.get().getStoryModuleRecord({
		storyModule = storyModule,
		storybook = firstStorybook,
	})).toBeUndefined()

	firstStorybook.source:Destroy()
	secondStorybook.source:Destroy()
	storyModule:Destroy()
end)

test("replacing the storybook object for the same source keeps another request's record", function()
	local storyModule = Instance.new("ModuleScript")
	storyModule.Name = "Replaced.story"
	storyModule.Source = [[return { story = function() end }]]

	local source = Instance.new("ModuleScript")
	local storybook: types.LoadedStorybook = {
		name = "Storybook",
		source = source,
		storyRoots = {},
	}
	local replacement: types.LoadedStorybook = {
		name = "Replacement",
		source = source,
		storyRoots = {},
	}

	local releaseOther = StorytellerStore.get().requestStoryModule(StoryModuleRequestPriority.Background, {
		storyModule = storyModule,
		storybook = storybook,
	})

	local setStorybook: (storybook: types.LoadedStorybook) -> ()
	local get = renderHook(function()
		local current, setState = React.useState(storybook)
		setStorybook = setState
		return useStories(storyModule, current)
	end)
	act(function()
		task.wait(0.1)
	end)

	waitFor(function()
		local stories = get()
		assert(stories, "expected the original Storybook's stories to load")
		expect(stories[1].storybook).toBe(storybook)
	end)

	act(function()
		setStorybook(replacement)
	end)
	act(function()
		task.wait(0.1)
	end)

	-- The previous record stays visible until the reload publishes, so wait on
	-- the Storybook identity rather than the name.
	waitFor(function()
		local stories = get()
		assert(stories, "expected the replacement Storybook's stories to load")
		expect(stories[1].storybook).toBe(replacement)
	end)

	-- The other request still holds the entry, so its record must survive the
	-- hook's cleanup for the replaced storybook object.
	local record = StorytellerStore.get().getStoryModuleRecord({
		storyModule = storyModule,
		storybook = storybook,
	})
	assert(record and record.stories, "expected the other request to keep its record")
	expect(record.problem).toBeUndefined()

	releaseOther()
	local stories = get()
	assert(stories, "expected the hook to keep its stories after the other request releases")
	expect(stories[1].storybook).toBe(replacement)

	source:Destroy()
	storyModule:Destroy()
end)
