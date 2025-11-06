local JestGlobals = require("@pkg/JestGlobals")
local ReactRoblox = require("@pkg/ReactRoblox")

local new = require("@root/test-utils/new")
local renderHook = require("@root/test-utils/renderHook")
local types = require("@root/types")

local useOrphanedStoryModules = require("./useOrphanedStoryModules")

local expect = JestGlobals.expect
local test = JestGlobals.test

local act = ReactRoblox.act

type LoadedStorybook = types.LoadedStorybook

test("updates when moving instances around the DataModel", function()
	local storybookModule = new("ModuleScript", {
		Source = [[
			return {
				storyRoots = {
					script.Parent
				}
			}
		]],
	})

	local templateStoryModule = new("ModuleScript", {
		Source = [[
			return {
				story = function() end
			}
		]],
	})

	local storyModuleA = templateStoryModule:Clone()
	local storyModuleB = templateStoryModule:Clone()
	local storyModuleC = templateStoryModule:Clone()
	local storyModuleD = templateStoryModule:Clone()

	local container = new("Folder", {}, {
		["Folder"] = new("Folder", {}, {
			["Sample.storybook"] = storybookModule,
			["A.story"] = storyModuleA,
			["Folder"] = new("Folder", {}, {
				["B.story"] = storyModuleB,
			}),
		}),
		["C.story"] = storyModuleC,
		["D.story"] = storyModuleD,
	})

	local getOrphanedStories = renderHook(function()
		return useOrphanedStoryModules(container)
	end)

	expect(getOrphanedStories()).toEqual(expect.arrayContaining({
		storyModuleC,
		storyModuleD,
	}))

	act(function()
		print("storyModuleA.Parent = container")
		storyModuleA.Parent = container
		task.wait()
	end)

	print("check")
	expect(getOrphanedStories()).toEqual(expect.arrayContaining({
		storyModuleA,
		storyModuleC,
		storyModuleD,
	}))

	act(function()
		print("storybookModule.Parent = container")
		storybookModule.Parent = container
		task.wait()
	end)

	expect(getOrphanedStories()).toEqual({})
end)

test("updates when adding/removing instances from the DataModel", function()
	local storybookModule = new("ModuleScript", {
		Source = [[
			return {
				storyRoots = {
					script.Parent
				}
			}
		]],
	})

	local templateStoryModule = new("ModuleScript", {
		Source = [[
			return {
				story = function() end
			}
		]],
	})

	local storyModuleA = templateStoryModule:Clone()
	local storyModuleB = templateStoryModule:Clone()
	local storyModuleC = templateStoryModule:Clone()
	local storyModuleD = templateStoryModule:Clone()

	local container = new("Folder", {}, {
		["Folder"] = new("Folder", {}, {
			["Sample.storybook"] = storybookModule,
			["A.story"] = storyModuleA,
			["Folder"] = new("Folder", {}, {
				["B.story"] = storyModuleB,
			}),
		}),
		["C.story"] = storyModuleC,
		["D.story"] = storyModuleD,
	})

	local getOrphanedStories = renderHook(function()
		return useOrphanedStoryModules(container)
	end)

	expect(getOrphanedStories()).toEqual(expect.arrayContaining({
		storyModuleC,
		storyModuleD,
	}))

	storybookModule.Parent = nil

	expect(getOrphanedStories()).toEqual(expect.arrayContaining({
		storyModuleA,
		storyModuleB,
		storyModuleC,
		storyModuleD,
	}))

	storybookModule.Parent = storyModuleB.Parent

	expect(getOrphanedStories()).toEqual(expect.arrayContaining({
		storyModuleA,
		storyModuleC,
		storyModuleD,
	}))

	storyModuleC.Parent = nil

	expect(getOrphanedStories()).toEqual(expect.arrayContaining({
		storyModuleA,
		storyModuleD,
	}))
end)
