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
	-- Folder
	--   FolderA
	--     StoryA.story
	--   FolderB
	--     StoryB.story

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

test("returns empty list when all Story modules are managed by Storybooks", function()
	-- Folder
	--   FolderA
	--     StoryA.story
	--   FolderB
	--     StoryB.story

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

	local storybookA: types.LoadedStorybook = {
		name = "Storybook",
		loader = ModuleLoader.new(),
		source = Instance.new("ModuleScript"),
		storyRoots = {
			folderA,
		},
	}

	local storybookB: types.LoadedStorybook = {
		name = "Storybook",
		loader = ModuleLoader.new(),
		source = Instance.new("ModuleScript"),
		storyRoots = {
			folderB,
		},
	}

	expect(findOrphanedStoryModules(container, { storybookA, storybookB })).toEqual({})
end)

test("returns all story modules when no storybooks are present", function()
	for _ = 1, 5 do
		local storyModule = Instance.new("ModuleScript")
		storyModule.Name = "Story.story"
		storyModule.Parent = container
	end

	expect(#findOrphanedStoryModules(container, {})).toBe(5)
end)

test("keeps going after hitting a story along the way", function()
	local storyModuleA = Instance.new("ModuleScript")
	storyModuleA.Name = "StoryA.story"
	storyModuleA.Parent = container

	-- Add Folders above the container to build out a nested hierarchy
	for _ = 1, 5 do
		local folder = Instance.new("Folder")
		container.Parent = folder
		container = folder
	end

	-- Place a story in the middle to make sure StoryB will still get picked up
	local storyModuleB = Instance.new("ModuleScript")
	storyModuleB.Name = "StoryB.story"
	storyModuleB.Parent = container

	for _ = 1, 5 do
		local folder = Instance.new("Folder")
		container.Parent = folder
		container = folder
	end

	expect(findOrphanedStoryModules(container, {})).toEqual({ storyModuleA, storyModuleB })
end)

test("handles deeply nested stories", function()
	local storyModuleA = Instance.new("ModuleScript")
	storyModuleA.Name = "StoryA.story"
	storyModuleA.Parent = container

	-- Add Folders above the container to build out a nested hierarchy
	for _ = 1, 10 do
		local folder = Instance.new("Folder")
		container.Parent = folder
		container = folder
	end

	local folderB = Instance.new("Folder")
	folderB.Name = "FolderB"
	folderB.Parent = container

	local storyModuleB = Instance.new("ModuleScript")
	storyModuleB.Name = "StoryB.story"
	storyModuleB.Parent = folderB

	local storybookA: types.LoadedStorybook = {
		name = "Storybook",
		loader = ModuleLoader.new(),
		source = Instance.new("ModuleScript"),
		storyRoots = {
			container,
		},
	}

	local storybookB: types.LoadedStorybook = {
		name = "Storybook",
		loader = ModuleLoader.new(),
		source = Instance.new("ModuleScript"),
		storyRoots = {
			folderB,
		},
	}

	expect(findOrphanedStoryModules(container, { storybookA, storybookB })).toEqual({})
end)
