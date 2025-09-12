local JestGlobals = require("@pkg/JestGlobals")
local ModuleLoader = require("@pkg/ModuleLoader")

local findOrphanedStoryModules = require("./findOrphanedStoryModules")
local types = require("@root/types")

local beforeEach = JestGlobals.beforeEach
local expect = JestGlobals.expect
local test = JestGlobals.test

local container

beforeEach(function()
	container = Instance.new("Folder")
end)

test("finds all Story modules that aren't managed by a Storybook", function()
	local folderA = Instance.new("Folder")
	folderA.Name = "FolderA"
	folderA.Parent = container

	local storyModuleA = Instance.new("ModuleScript")
	storyModuleA.Name = "StoryA.story"
	storyModuleA.Parent = folderA

	local folderB = Instance.new("Folder")
	folderB.Name = "FolderB"
	folderB.Parent = container

	local storyModuleB = Instance.new("ModuleScript")
	storyModuleB.Name = "StoryB.story"
	storyModuleB.Parent = folderB

	local storybook: types.LoadedStorybook = {
		name = "Storybook",
		loader = ModuleLoader.new(),
		source = Instance.new("ModuleScript"),
		storyRoots = {
			folderA,
		},
	}

	expect(findOrphanedStoryModules(container, { storybook })).toEqual({ storyModuleB })
end)
