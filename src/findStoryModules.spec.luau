local JestGlobals = require("@pkg/JestGlobals")

local findStoryModules = require("./findStoryModules")

local beforeEach = JestGlobals.beforeEach
local expect = JestGlobals.expect
local test = JestGlobals.test

local container

beforeEach(function()
	container = Instance.new("Folder")
end)

test("find all story modules under a parent", function()
	local storyModule = Instance.new("ModuleScript")
	storyModule.Name = "Sample.story"
	storyModule.Parent = container

	-- Add Folders above the container to build out a nested hierarchy
	for _ = 1, 10 do
		local folder = Instance.new("Folder")
		container.Parent = folder
		container = folder
	end

	expect(findStoryModules(container)).toEqual({
		storyModule,
	})
end)
