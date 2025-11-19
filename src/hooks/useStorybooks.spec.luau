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
local storybookModule: ModuleScript

beforeEach(function()
	container = Instance.new("Folder")
	container.Parent = game

	storybookModule = Instance.new("ModuleScript")
	storybookModule.Name = "Sample.storybook"
	storybookModule.Source = [[
		return {
			storyRoots = {
				script.Parent
			}
		}
	]]
	storybookModule.Parent = container
end)

afterEach(function()
	container:Destroy()
end)

test("loads storybook modules", function()
	local get = renderHook(function()
		return useStorybooks(container)
	end)

	local storybooks = get()

	expect(storybooks.available[1]).toMatchObject({
		name = "Sample",
	})
end)

test("storybooks with syntax errors are marked unavailable", function()
	storybookModule.Source = [[
		return {
			syntax error
		}
	]]

	local get = renderHook(function()
		return useStorybooks(container)
	end)

	local storybooks = get()

	expect(storybooks.unavailable[1]).toMatchObject({
		problem = expect.any("string"),
		storybook = {
			name = storybookModule.Name,
		},
	})
end)

test("adding a new storybook to the DM triggers a re-render", function()
	local newStorybookModule = Instance.new("ModuleScript")
	newStorybookModule.Name = "BOO.storybook"
	newStorybookModule.Source = [[
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

	expect(storybooks.available).toEqual({
		expect.objectContaining({
			name = "Sample",
		}),
	})

	act(function()
		newStorybookModule.Parent = container
		task.wait()
	end)

	storybooks = get()

	expect(storybooks.available).toEqual(expect.arrayContaining({
		expect.objectContaining({
			name = "Sample",
		}),
		expect.objectContaining({
			name = "BOO",
		}),
	}))
end)

test("renaming a ModuleScript to turn it into a Storybook updates as expected", function()
	local getStorybooks = renderHook(function()
		return useStorybooks(container)
	end)

	local moduleScript = Instance.new("ModuleScript")
	moduleScript.Source = storybookModule.Source

	act(function()
		moduleScript.Parent = container
		task.wait()
	end)

	expect(getStorybooks().available).toEqual({
		expect.objectContaining({
			name = "Sample",
		}),
	})
	expect(getStorybooks().unavailable).toEqual({})

	act(function()
		moduleScript.Name = "Foo.storybook"
		task.wait()
	end)

	expect(getStorybooks().available).toEqual(expect.arrayContaining({
		expect.objectContaining({
			name = "Sample",
		}),
		expect.objectContaining({
			name = "Foo",
		}),
	}))
	expect(getStorybooks().unavailable).toEqual({})
end)

test("removing a storybook from the DM triggers a re-render", function()
	local get = renderHook(function()
		return useStorybooks(container)
	end)

	act(function()
		storybookModule:Destroy()
		task.wait()
	end)

	local storybooks = get()

	expect(storybooks.available).toEqual({})
end)

test("re-renders on module changes", function()
	local get = renderHook(function()
		return useStorybooks(container)
	end)

	local storybooks = get()

	expect(storybooks.available).toEqual({
		expect.objectContaining({
			name = "Sample",
		}),
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

	expect(storybooks.available).toEqual({
		expect.objectContaining({
			name = "New Name",
		}),
	})
end)
