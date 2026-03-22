local JestGlobals = require("@pkg/JestGlobals")
local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")

local StorytellerProvider = require("@root/react/StorytellerProvider")
local StorytellerStore = require("@root/stores/StorytellerStore")
local renderHook = require("@root/test-utils/renderHook")
local types = require("@root/types")
local waitFor = require("@root/test-utils/waitFor")

local useStorybooks = require("./useStorybooks")

local afterEach = JestGlobals.afterEach
local beforeEach = JestGlobals.beforeEach
local expect = JestGlobals.expect
local test = JestGlobals.test

local act = ReactRoblox.act

type LoadedStorybook = types.LoadedStorybook

local container: Folder
local store: StorytellerStore.StorytellerStore

local function Wrapper(props): React.ReactNode
	return React.createElement(StorytellerProvider, {
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

	storybookModule.Parent = container
	task.wait()

	local get = renderHook(function()
		return useStorybooks(container)
	end, {
		wrapper = Wrapper,
	})

	waitFor(function()
		local storybooks = get()

		expect(#storybooks.available).toBe(1)
		expect(#storybooks.unavailable).toBe(0)

		expect(storybooks.available[1]).toMatchObject({
			name = "Sample",
		})
	end)
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
	end, {
		wrapper = Wrapper,
	})

	waitFor(function()
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
	end, {
		wrapper = Wrapper,
	})

	local storybooks = get()

	expect(#storybooks.available).toBe(0)
	expect(#storybooks.unavailable).toBe(0)

	act(function()
		storybookModule.Parent = container
		task.wait()
	end)

	waitFor(function()
		storybooks = get()

		expect(#storybooks.available).toBe(1)
		expect(#storybooks.unavailable).toBe(0)

		expect(storybooks.available[1]).toMatchObject({
			name = "Sample",
		})
	end)
end)

test("renaming a ModuleScript to turn it into a Storybook updates as expected", function()
	local getStorybooks = renderHook(function()
		return useStorybooks(container)
	end, {
		wrapper = Wrapper,
	})

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

	waitFor(function()
		storybooks = getStorybooks()

		expect(#storybooks.available).toBe(1)
		expect(#storybooks.unavailable).toBe(0)

		expect(storybooks.available[1]).toMatchObject({
			name = "Foo",
		})
	end)
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
	end, {
		wrapper = Wrapper,
	})

	act(function()
		storybookModule:Destroy()
		task.wait()
	end)

	waitFor(function()
		local storybooks = get()

		expect(#storybooks.available).toBe(0)
		expect(#storybooks.unavailable).toBe(0)
	end)
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
	end, {
		wrapper = Wrapper,
	})

	waitFor(function()
		local storybooks = get()
		expect(storybooks.available[1]).toMatchObject({
			name = "Sample",
		})
	end)

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

	waitFor(function()
		local storybooks = get()

		expect(storybooks.available[1]).toMatchObject({
			name = "New Name",
		})
	end)
end)
