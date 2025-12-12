local JestGlobals = require("@pkg/JestGlobals")
local ModuleLoader = require("@pkg/ModuleLoader")

local new = require("@root/test-utils/new")
local types = require("@root/types")

local isOrphanedStoryModule = require("./isOrphanedStoryModule")

local expect = JestGlobals.expect
local test = JestGlobals.test

test("return `true` for a Story module that is not a descendant of any storyRoots", function()
	local storyModuleA = new("ModuleScript")
	local storyModuleB = new("ModuleScript")

	local container = new("Folder", nil, {
		["A.story"] = storyModuleA,
		["B.story"] = storyModuleB,
	})

	local storybook: types.LoadedStorybook = {
		name = "Storybook",
		source = Instance.new("ModuleScript"),
		storyRoots = {
			container,
		},
		loader = ModuleLoader.new(),
	}

	storyModuleB.Parent = nil

	expect(isOrphanedStoryModule(storyModuleA, { storybook })).toBe(false)
	expect(isOrphanedStoryModule(storyModuleB, { storybook })).toBe(true)
end)

test("return `false` if the given instance is not a ModuleScript", function()
	local candidate = new("Folder")

	local container = new("Folder", nil, {
		-- Has the right suffix, but is not a ModuleScript, so this should never
		-- be included
		["Folder.story"] = candidate,
	})

	local storybook: types.LoadedStorybook = {
		name = "Storybook",
		source = Instance.new("ModuleScript"),
		storyRoots = {
			container,
		},
		loader = ModuleLoader.new(),
	}

	expect(isOrphanedStoryModule(candidate, { storybook })).toBe(false)
end)

test("return `false` if a ModuleScript does not have .story in the name", function()
	local candidate = new("ModuleScript")

	local container = new("Folder", nil, {
		["ModuleScript"] = candidate,
	})

	local storybook: types.LoadedStorybook = {
		name = "Storybook",
		source = Instance.new("ModuleScript"),
		storyRoots = {
			container,
		},
		loader = ModuleLoader.new(),
	}

	expect(isOrphanedStoryModule(candidate, { storybook })).toBe(false)
end)
