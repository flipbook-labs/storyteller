local JestGlobals = require("@pkg/JestGlobals")

local loadStoryModuleSnapshot = require("./loadStoryModuleSnapshot")
local types = require("@root/types")

local expect = JestGlobals.expect
local test = JestGlobals.test

test("returns lightweight metadata for every story", function()
	local storyModule = Instance.new("ModuleScript")
	storyModule.Name = "Button.story"
	storyModule.Source = [[
		return {
			name = "Buttons",
			stories = {
				{
					id = "primary",
					name = "Primary",
					summary = "The main button",
					story = function() end,
				},
				{
					name = "Secondary",
					story = function() end,
				},
			},
		}
	]]

	local storybook: types.LoadedStorybook = {
		name = "Storybook",
		source = Instance.new("ModuleScript"),
		storyRoots = {},
	}

	local snapshot = loadStoryModuleSnapshot(storyModule, storybook)
	local expectedStories: { types.StorySnapshot } = {
		{
			id = "primary",
			name = "Primary",
			summary = "The main button",
		},
		{
			id = "Secondary",
			name = "Secondary",
		},
	}

	expect(snapshot).toEqual({
		name = "Buttons",
		source = storyModule,
		stories = expectedStories,
	})
end)
