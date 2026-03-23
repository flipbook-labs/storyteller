local JestGlobals = require("@pkg/JestGlobals")
local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")

local StorytellerContext = require("@root/react/StorytellerContext")
local StorytellerStore = require("@root/stores/StorytellerStore")
local new = require("@root/test-utils/new")
local renderHook = require("@root/test-utils/renderHook")
local types = require("@root/types")
local waitFor = require("@root/test-utils/waitFor")

local useOrphanedStoryModules = require("./useOrphanedStoryModules")

local expect = JestGlobals.expect
local test = JestGlobals.test
local beforeEach = JestGlobals.beforeEach
local afterEach = JestGlobals.afterEach

local act = ReactRoblox.act

type LoadedStorybook = types.LoadedStorybook

local container: Folder
local store: StorytellerStore.StorytellerStore

local function Wrapper(props): React.ReactNode
	return React.createElement(StorytellerContext.StorytellerProvider, {
		store = store,
	}, props.children)
end

beforeEach(function()
	container = Instance.new("Folder")
	container.Parent = game
	store = StorytellerStore.new(container)
end)

afterEach(function()
	store.stop()
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

	local getOrphanedStories = renderHook(function()
		return useOrphanedStoryModules(container)
	end, {
		wrapper = Wrapper,
	})

	waitFor(function()
		expect(getOrphanedStories()).toEqual(expect.arrayContaining({
			storyModuleC,
			storyModuleD,
		}))
	end)

	act(function()
		storyModuleA.Parent = root
		task.wait()
	end)

	waitFor(function()
		expect(getOrphanedStories()).toEqual(expect.arrayContaining({
			storyModuleA,
			storyModuleC,
			storyModuleD,
		}))
	end)

	act(function()
		storybookModule.Parent = root
		task.wait()
	end)

	waitFor(function()
		expect(getOrphanedStories()).toEqual({})
	end)
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
		return useOrphanedStoryModules(container)
	end, {
		wrapper = Wrapper,
	})

	waitFor(function()
		expect(getOrphanedStories()).toEqual(expect.arrayContaining({
			storyModuleC,
			storyModuleD,
		}))
	end)

	act(function()
		storybookModule.Parent = nil
		task.wait()
	end)

	waitFor(function()
		expect(getOrphanedStories()).toEqual(expect.arrayContaining({
			storyModuleA,
			storyModuleB,
			storyModuleC,
			storyModuleD,
		}))
	end)

	act(function()
		storybookModule.Parent = storyModuleB.Parent
		task.wait()
	end)

	waitFor(function()
		expect(getOrphanedStories()).toEqual(expect.arrayContaining({
			storyModuleA,
			storyModuleC,
			storyModuleD,
		}))
	end)

	act(function()
		storyModuleC.Parent = nil
		task.wait()
	end)

	waitFor(function()
		expect(getOrphanedStories()).toEqual(expect.arrayContaining({
			storyModuleA,
			storyModuleD,
		}))
	end)
end)
