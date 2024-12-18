local JestGlobals = require("@pkg/JestGlobals")
local ModuleLoader = require("@pkg/ModuleLoader")

local findStoryModulesForStorybook = require("./findStoryModulesForStorybook")
local types = require("@root/types")

local beforeEach = JestGlobals.beforeEach
local expect = JestGlobals.expect
local test = JestGlobals.test

local container

beforeEach(function()
	container = Instance.new("Folder")
end)

test("find all story modules for a storybook", function()
	local storyModule = Instance.new("ModuleScript")
	storyModule.Name = "Sample.story"
	storyModule.Parent = container

	-- Add Folders above the container to build out a nested hierarchy
	for _ = 1, 10 do
		local folder = Instance.new("Folder")
		container.Parent = folder
		container = folder
	end

	local storybook: types.LoadedStorybook = {
		name = "Storybook",
		loader = ModuleLoader.new(),
		storyRoots = {
			container,
		},
	}

	expect(findStoryModulesForStorybook(storybook)).toEqual({ storyModule })
end)
