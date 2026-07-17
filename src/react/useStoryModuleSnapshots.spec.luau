local JestGlobals = require("@pkg/JestGlobals")
local ReactRoblox = require("@pkg/ReactRoblox")

local renderHook = require("@root/test-utils/renderHook")
local types = require("@root/types")
local useStoryModuleSnapshots = require("./useStoryModuleSnapshots")
local waitFor = require("@root/test-utils/waitFor")

local expect = JestGlobals.expect
local test = JestGlobals.test
local act = ReactRoblox.act

test("loads snapshots and isolates malformed modules", function()
	local validStoryModule = Instance.new("ModuleScript")
	validStoryModule.Name = "Valid.story"
	validStoryModule.Source = [[
		return {
			stories = {
				Alpha = function() end,
				Beta = function() end,
			},
		}
	]]

	local invalidStoryModule = Instance.new("ModuleScript")
	invalidStoryModule.Name = "Invalid.story"
	invalidStoryModule.Source = "syntax error"

	local storybook: types.LoadedStorybook = {
		name = "Storybook",
		source = Instance.new("ModuleScript"),
		storyRoots = {},
	}
	local targets = {
		{
			storyModule = validStoryModule,
			storybook = storybook,
		},
		{
			storyModule = invalidStoryModule,
			storybook = storybook,
		},
	}

	local get = renderHook(function()
		return useStoryModuleSnapshots(targets)
	end)

	act(function()
		task.wait(0.1)
	end)

	waitFor(function()
		local snapshots = get()
		expect(snapshots[validStoryModule]).toBeDefined()
		expect(snapshots[invalidStoryModule]).toBeDefined()
		expect(snapshots[validStoryModule].stories).toEqual({
			expect.objectContaining({ id = "Alpha", name = "Alpha" }),
			expect.objectContaining({ id = "Beta", name = "Beta" }),
		})
		expect(snapshots[invalidStoryModule].problem).toBeDefined()
	end)

	act(function()
		invalidStoryModule.Source = [[
			return {
				story = function() end,
			}
		]]
		task.wait(0.1)
	end)

	waitFor(function()
		local snapshot = get()[invalidStoryModule]
		expect(snapshot.problem).toBeUndefined()
		expect(snapshot.stories).toEqual({
			expect.objectContaining({
				id = "default",
				name = "Invalid",
			}),
		})
	end)
end)

test("shares dependency loads during initial discovery", function()
	local container = Instance.new("Folder")
	local dependency = Instance.new("ModuleScript")
	dependency.Name = "Dependency"
	dependency.Source = "return {}"
	dependency.Parent = container

	local firstStoryModule = Instance.new("ModuleScript")
	firstStoryModule.Name = "First.story"
	firstStoryModule.Source = [[
		local dependency = require(script.Parent.Dependency)
		return {
			name = tostring(dependency),
			story = function() end,
		}
	]]
	firstStoryModule.Parent = container

	local secondStoryModule = Instance.new("ModuleScript")
	secondStoryModule.Name = "Second.story"
	secondStoryModule.Source = firstStoryModule.Source
	secondStoryModule.Parent = container

	local storybook: types.LoadedStorybook = {
		name = "Storybook",
		source = Instance.new("ModuleScript"),
		storyRoots = {},
	}
	local targets = {
		{
			storyModule = firstStoryModule,
			storybook = storybook,
		},
		{
			storyModule = secondStoryModule,
			storybook = storybook,
		},
	}

	local get = renderHook(function()
		return useStoryModuleSnapshots(targets)
	end)

	act(function()
		task.wait(0.1)
	end)

	waitFor(function()
		local snapshots = get()
		expect(snapshots[firstStoryModule]).toBeDefined()
		expect(snapshots[secondStoryModule]).toBeDefined()
		expect(snapshots[firstStoryModule].stories[1].name).toBe(snapshots[secondStoryModule].stories[1].name)
	end)

	local initialName = get()[firstStoryModule].stories[1].name
	act(function()
		dependency.Source = "return { changed = true }"
		task.wait(0.1)
	end)

	waitFor(function()
		local snapshots = get()
		expect(snapshots[firstStoryModule].stories[1].name).never.toBe(initialName)
		expect(snapshots[secondStoryModule].stories[1].name).never.toBe(initialName)
	end)
end)
