local JestGlobals = require("@pkg/JestGlobals")
local ReactRoblox = require("@pkg/ReactRoblox")

local renderHook = require("@root/test-utils/renderHook")
local types = require("@root/types")
local useStorybooks = require("./useStorybooks")

local beforeEach = JestGlobals.beforeEach
local expect = JestGlobals.expect
local test = JestGlobals.test

local act = ReactRoblox.act

type LoadedStorybook = types.LoadedStorybook

local container: Folder
local storybookModule: ModuleScript

beforeEach(function()
	container = Instance.new("Folder")

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

test("loads storybook modules", function()
	local get = renderHook(function()
		return useStorybooks(container)
	end)

	local storybooks = get()

	expect(storybooks.available).toMatchObject({
		{
			name = "Sample",
		},
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

	expect(storybooks.unavailable).toMatchObject({
		{
			problem = expect.any("string"),
			storybook = {
				name = storybookModule.Name,
			},
		},
	})
end)

test("adding a new storybook to the DM triggers a re-render", function()
	local newStorybookModule = Instance.new("ModuleScript")
	newStorybookModule.Name = "Foo.storybook"
	newStorybookModule.Source = [[
		return {
			storyRoots = {
				script.Parent
			}
		}
	]]

	local get = renderHook(function()
		return useStorybooks(container)
	end)

	local storybooks = get()

	expect(storybooks.available).toMatchObject({
		{
			name = "Sample",
		},
	})

	act(function()
		newStorybookModule.Parent = container
	end)

	storybooks = get()

	expect(storybooks.available).toMatchObject({
		{
			name = "Sample",
		},
		{
			name = "Foo",
		},
	})
end)

-- TOOD: Update useStorybooks so this test can pass
test.skip("removing a storybook from the DM triggers a re-render", function()
	local get = renderHook(function()
		return useStorybooks(container)
	end)

	act(function()
		storybookModule:Destroy()
	end)

	local storybooks = get()

	expect(storybooks.available).toEqual({})
end)

test.only("re-renders on module changes", function()
	local get = renderHook(function()
		return useStorybooks(container)
	end)

	local storybooks = get()

	expect(storybooks.available).toMatchObject({
		{
			name = "Sample",
		},
	})

	act(function()
		storybookModule.Source = [[
			return {
				name = "New Name",
				storyRoots = {
					script.Parent
				}
			}
		]]
	end)

	storybooks = get()

	expect(storybooks.available).toMatchObject({
		{
			name = "New Name",
		},
	})
end)
