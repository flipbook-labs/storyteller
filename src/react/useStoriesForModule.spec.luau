local JestGlobals = require("@pkg/JestGlobals")

local renderHook = require("@root/test-utils/renderHook")
local types = require("@root/types")
local useStoriesForModule = require("./useStoriesForModule")

local expect = JestGlobals.expect
local test = JestGlobals.test

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
	local stories, err = get()

	expect(err).toBeUndefined()
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
end)
