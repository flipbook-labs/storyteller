local JestGlobals = require("@pkg/JestGlobals")
local ReactRoblox = require("@pkg/ReactRoblox")

local renderHook = require("@root/test-utils/renderHook")
local types = require("@root/types")
local useStoriesForModule = require("./useStoriesForModule")
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
		return useStoriesForModule(storyModule, storybook)
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
		return useStoriesForModule(storyModule, storybook)
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
