local JestGlobals = require("@pkg/JestGlobals")

local findStorybookModules = require("./findStorybookModules")

local beforeEach = JestGlobals.beforeEach
local expect = JestGlobals.expect
local test = JestGlobals.test

local container

beforeEach(function()
	container = Instance.new("Folder")
end)

test("find all storybook modules under a parent", function()
	local storybookModule = Instance.new("ModuleScript")
	storybookModule.Name = "Sample.storybook"
	storybookModule.Parent = container

	-- Add Folders above the container to build out a nested hierarchy
	for _ = 1, 10 do
		local folder = Instance.new("Folder")
		container.Parent = folder
		container = folder
	end

	expect(findStorybookModules(container)).toEqual({
		storybookModule,
	})
end)
