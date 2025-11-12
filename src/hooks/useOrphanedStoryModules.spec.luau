local JestGlobals = require("@pkg/JestGlobals")
local ReactRoblox = require("@pkg/ReactRoblox")

local new = require("@root/test-utils/new")
local renderHook = require("@root/test-utils/renderHook")
local types = require("@root/types")
local waitForEvents = require("@root/test-utils/waitForEvents")

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

	local container = new("Folder", nil, {
		["Folder"] = new("Folder", nil, {
			["Sample.storybook"] = storybookModule,
			["A.story"] = storyModuleA,
			["Folder"] = new("Folder", nil, {
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

	print("storyModuleA.Parent = container")
	act(function()
		storyModuleA.Parent = container
		waitForEvents()
	end)

	print("check")
	expect(getOrphanedStories()).toEqual(expect.arrayContaining({
		storyModuleA,
		storyModuleC,
		storyModuleD,
	}))

	print("storybookModule.Parent = container")
	act(function()
		storybookModule.Parent = container
		waitForEvents()
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

	act(function()
		storybookModule.Parent = nil
		waitForEvents()
	end)

	expect(getOrphanedStories()).toEqual(expect.arrayContaining({
		storyModuleA,
		storyModuleB,
		storyModuleC,
		storyModuleD,
	}))

	act(function()
		storybookModule.Parent = storyModuleB.Parent
		waitForEvents()
	end)

	expect(getOrphanedStories()).toEqual(expect.arrayContaining({
		storyModuleA,
		storyModuleC,
		storyModuleD,
	}))

	act(function()
		storyModuleC.Parent = nil
		waitForEvents()
	end)

	expect(getOrphanedStories()).toEqual(expect.arrayContaining({
		storyModuleA,
		storyModuleD,
	}))
end)

test("updates when renaming modules", function() end)
