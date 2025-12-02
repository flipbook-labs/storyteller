local JestGlobals = require("@pkg/JestGlobals")
local ReactRoblox = require("@pkg/ReactRoblox")

local renderHook = require("@root/test-utils/renderHook")
local types = require("@root/types")
local useStorybooks = require("./useStorybooks")

local afterEach = JestGlobals.afterEach
local beforeEach = JestGlobals.beforeEach
local expect = JestGlobals.expect
local test = JestGlobals.test

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

test("loads storybook modules", function()
	local storybookModule = Instance.new("ModuleScript")
	storybookModule.Name = "Sample.storybook"
	storybookModule.Source = [[
		return {
			storyRoots = {
				Instance.new("Folder")
			}
		}
	]]

	-- TODO: Make tests work without the task.wait(). This tells me there might
	-- be something in StorytellerStore that isn't recomputing when certain
	-- events happen
	storybookModule.Parent = container
	task.wait()

	local get = renderHook(function()
		return useStorybooks(container)
	end)

	local storybooks = get()

	expect(#storybooks.available).toBe(1)
	expect(#storybooks.unavailable).toBe(0)

	expect(storybooks.available[1]).toMatchObject({
		name = "Sample",
	})
end)

test("storybooks with syntax errors are marked unavailable", function()
	local storybookModule = Instance.new("ModuleScript")
	storybookModule.Name = "Sample.storybook"
	storybookModule.Source = [[
		return {
			syntax error
		}
	]]

	storybookModule.Parent = container
	task.wait()

	local get = renderHook(function()
		return useStorybooks(container)
	end)

	local storybooks = get()

	expect(#storybooks.available).toBe(0)
	expect(#storybooks.unavailable).toBe(1)

	expect(storybooks.unavailable[1]).toMatchObject({
		problem = expect.any("string"),
		storybook = {
			name = storybookModule.Name,
		},
	})
end)

test("adding a new storybook to the DM triggers a re-render", function()
	local storybookModule = Instance.new("ModuleScript")
	storybookModule.Name = "Sample.storybook"
	storybookModule.Source = [[
		return {
			storyRoots = {
				Instance.new("Folder")
			}
		}
	]]

	local get = renderHook(function()
		return useStorybooks(container)
	end)

	local storybooks = get()

	expect(#storybooks.available).toBe(0)
	expect(#storybooks.unavailable).toBe(0)

	act(function()
		storybookModule.Parent = container
		task.wait()
	end)

	storybooks = get()

	expect(#storybooks.available).toBe(1)
	expect(#storybooks.unavailable).toBe(0)

	expect(storybooks.available[1]).toMatchObject({
		name = "Sample",
	})
end)

test("renaming a ModuleScript to turn it into a Storybook updates as expected", function()
	local getStorybooks = renderHook(function()
		return useStorybooks(container)
	end)

	local moduleScript = Instance.new("ModuleScript")
	moduleScript.Source = [[
		return {
			storyRoots = {
				Instance.new("Folder")
			}
		}
	]]

	act(function()
		moduleScript.Parent = container
		task.wait()
	end)

	local storybooks = getStorybooks()

	expect(#storybooks.available).toBe(0)
	expect(#storybooks.unavailable).toBe(0)

	act(function()
		moduleScript.Name = "Foo.storybook"
		task.wait()
	end)

	storybooks = getStorybooks()

	expect(#storybooks.available).toBe(1)
	expect(#storybooks.unavailable).toBe(0)

	expect(storybooks.available[1]).toMatchObject({
		name = "Foo",
	})
end)

test("removing a storybook from the DM triggers a re-render", function()
	local storybookModule = Instance.new("ModuleScript")
	storybookModule.Name = "Sample.storybook"
	storybookModule.Source = [[
		return {
			storyRoots = {
				Instance.new("Folder")
			}
		}
	]]

	storybookModule.Parent = container
	task.wait()

	local get = renderHook(function()
		return useStorybooks(container)
	end)

	act(function()
		storybookModule:Destroy()
		task.wait()
	end)

	local storybooks = get()

	expect(#storybooks.available).toBe(0)
	expect(#storybooks.unavailable).toBe(0)
end)

test("re-renders on module changes", function()
	local storybookModule = Instance.new("ModuleScript")
	storybookModule.Name = "Sample.storybook"
	storybookModule.Source = [[
		return {
			storyRoots = {
				Instance.new("Folder")
			}
		}
	]]

	storybookModule.Parent = container
	task.wait()

	local get = renderHook(function()
		return useStorybooks(container)
	end)

	local storybooks = get()

	expect(storybooks.available[1]).toMatchObject({
		name = "Sample",
	})

	act(function()
		storybookModule.Source = [[
			return {
				name = "New Name",
				storyRoots = {
					Instance.new("Folder")
				}
			}
		]]
		task.wait()
	end)

	storybooks = get()

	expect(storybooks.available[1]).toMatchObject({
		name = "New Name",
	})
end)
