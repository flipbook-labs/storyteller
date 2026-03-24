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

local DEFAULT_TIMEOUT = 1

local function waitForAct(callback: () -> (), options: { timeout: number?, interval: number? }?)
	local timeout = if options and options.timeout then options.timeout else DEFAULT_TIMEOUT
	local interval = if options and options.interval then options.interval else 0

	local startedAt = os.clock()
	local lastError

	while true do
		local ok, err = pcall(function()
			callback()
		end)

		if ok then
			return
		end

		lastError = err

		if os.clock() - startedAt >= timeout then
			error(lastError, 2)
		end

		act(function()
			if interval > 0 then
				task.wait(interval)
			else
				task.wait()
			end
		end)
	end
end

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

	waitForAct(function()
		expect(getOrphanedStories()).toEqual(expect.arrayContaining({
			storyModuleC,
			storyModuleD,
		}))
	end, { interval = 0 })

	act(function()
		storyModuleA.Parent = root
		task.wait()
	end)

	waitForAct(function()
		expect(getOrphanedStories()).toEqual(expect.arrayContaining({
			storyModuleA,
			storyModuleC,
			storyModuleD,
		}))
	end, { interval = 0 })

	act(function()
		storybookModule.Parent = root
		task.wait()
	end)

	waitForAct(function()
		expect(getOrphanedStories()).toEqual({})
	end, { interval = 0 })
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

	waitForAct(function()
		expect(getOrphanedStories()).toEqual(expect.arrayContaining({
			storyModuleC,
			storyModuleD,
		}))
	end, { interval = 0 })

	act(function()
		storybookModule.Parent = nil
		task.wait()
	end)

	waitForAct(function()
		expect(getOrphanedStories()).toEqual(expect.arrayContaining({
			storyModuleA,
			storyModuleB,
			storyModuleC,
			storyModuleD,
		}))
	end, { interval = 0 })

	act(function()
		storybookModule.Parent = storyModuleB.Parent
		task.wait()
	end)

	waitForAct(function()
		expect(getOrphanedStories()).toEqual(expect.arrayContaining({
			storyModuleA,
			storyModuleC,
			storyModuleD,
		}))
	end, { interval = 0 })

	act(function()
		storyModuleC.Parent = nil
		task.wait()
	end)

	waitForAct(function()
		expect(getOrphanedStories()).toEqual(expect.arrayContaining({
			storyModuleA,
			storyModuleD,
		}))
	end, { interval = 0 })
end)
