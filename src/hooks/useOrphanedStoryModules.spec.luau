local JestGlobals = require("@pkg/JestGlobals")
local ReactRoblox = require("@pkg/ReactRoblox")

local new = require("@root/test-utils/new")
local renderHook = require("@root/test-utils/renderHook")
local types = require("@root/types")

local useOrphanedStoryModules = require("./useOrphanedStoryModules")

local expect = JestGlobals.expect
local test = JestGlobals.test
local beforeEach = JestGlobals.beforeEach
local afterEach = JestGlobals.afterEach

local act = ReactRoblox.act

type LoadedStorybook = types.LoadedStorybook

local container: Folder

beforeEach(function()
	container = Instance.new("Folder")
	container.Parent = game
end)

afterEach(function()
	container:Destroy()
end)

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

	local root = new("Folder", nil, {
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

	root.Parent = container
	task.wait()

	local getOrphanedStories = renderHook(function()
		return useOrphanedStoryModules()
	end)

	expect(getOrphanedStories()).toEqual(expect.arrayContaining({
		storyModuleC,
		storyModuleD,
	}))

	act(function()
		storyModuleA.Parent = root
		task.wait()
	end)

	expect(getOrphanedStories()).toEqual(expect.arrayContaining({
		storyModuleA,
		storyModuleC,
		storyModuleD,
	}))

	act(function()
		storybookModule.Parent = root
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

	local root = new("Folder", nil, {
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

	root.Parent = container
	task.wait()

	local getOrphanedStories = renderHook(function()
		return useOrphanedStoryModules()
	end)

	expect(getOrphanedStories()).toEqual(expect.arrayContaining({
		storyModuleC,
		storyModuleD,
	}))

	act(function()
		storybookModule.Parent = nil
		task.wait()
	end)

	expect(getOrphanedStories()).toEqual(expect.arrayContaining({
		storyModuleA,
		storyModuleB,
		storyModuleC,
		storyModuleD,
	}))

	act(function()
		storybookModule.Parent = storyModuleB.Parent
		task.wait()
	end)

	expect(getOrphanedStories()).toEqual(expect.arrayContaining({
		storyModuleA,
		storyModuleC,
		storyModuleD,
	}))

	act(function()
		storyModuleC.Parent = nil
		task.wait()
	end)

	expect(getOrphanedStories()).toEqual(expect.arrayContaining({
		storyModuleA,
		storyModuleD,
	}))
end)
