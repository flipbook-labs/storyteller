local JestGlobals = require("@pkg/JestGlobals")
local ModuleLoader = require("@pkg/ModuleLoader")
local ReactRoblox = require("@pkg/ReactRoblox")

local renderHook = require("@root/test-utils/renderHook")
local types = require("@root/types")
local useStorybooks = require("./useStorybooks")

local beforeEach = JestGlobals.beforeEach
local expect = JestGlobals.expect
local test = JestGlobals.test

local act = ReactRoblox.act

type LoadedStorybook = types.LoadedStorybook

local loader: ModuleLoader.ModuleLoader
local container: Folder
local storybookModule: ModuleScript

-- TODO: Create a hierarchy of Storybooks
-- TODO: Test that a storybook change (like to its name or packages) will re-render

beforeEach(function()
	loader = ModuleLoader.new()

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
		return useStorybooks(container, loader)
	end)

	local storybooks = get()

	expect(storybooks).toEqual({
		{
			name = "Sample",
			storyRoots = expect.anything(),
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
		return useStorybooks(container, loader)
	end)

	local storybooks = get()

	expect(storybooks).toEqual({
		{
			name = "Sample",
			storyRoots = expect.anything(),
		},
	})

	act(function()
		newStorybookModule.Parent = container
	end)

	storybooks = get()

	expect(storybooks).toEqual({
		{
			name = "Sample",
			storyRoots = expect.anything(),
		},
		{
			name = "Foo",
			storyRoots = expect.anything(),
		},
	})
end)

-- TOOD: Update useStorybooks so this test can pass
test.skip("removing a storybook from the DM triggers a re-render", function()
	local get = renderHook(function()
		return useStorybooks(container, loader)
	end)

	act(function()
		storybookModule:Destroy()
	end)

	local storybooks = get()

	expect(storybooks).toEqual({})
end)

test("re-renders on module changes", function()
	local get = renderHook(function()
		return useStorybooks(container, loader)
	end)

	local storybooks = get()

	expect(storybooks).toEqual({
		{
			name = "Sample",
			storyRoots = expect.anything(),
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

	expect(storybooks).toEqual({
		{
			name = "New Name",
			storyRoots = expect.anything(),
		},
	})
end)
