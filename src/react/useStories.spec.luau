local JestGlobals = require("@pkg/JestGlobals")
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

	local stories
	waitFor(function()
		local err
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
