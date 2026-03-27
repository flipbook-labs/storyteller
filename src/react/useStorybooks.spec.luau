local JestGlobals = require("@pkg/JestGlobals")
local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")

local StorytellerContext = require("@root/react/StorytellerContext")
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
	return React.createElement(StorytellerContext.StorytellerProvider, {
		store = store,
	}, props.children)
end

beforeEach(function()
	container = Instance.new("Folder")

	store = StorytellerStore.new(container)
end)

afterEach(function()
	store.destroy()
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

	storybookModule.Parent = container

	repeat
		act(function()
			task.wait()
		end)
	until #get().available > 0

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
	moduleScript.Parent = container

	local storybooks = getStorybooks()

	expect(#storybooks.available).toBe(0)
	expect(#storybooks.unavailable).toBe(0)

	moduleScript.Name = "Foo.storybook"

	repeat
		act(function()
			task.wait()
		end)
	until #getStorybooks().available > 0

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

	local get = renderHook(function()
		return useStorybooks(container)
	end, {
		wrapper = Wrapper,
	})

	local storybooks = get()

	expect(#storybooks.available).toBe(1)
	expect(#storybooks.unavailable).toBe(0)

	storybookModule:Destroy()

	repeat
		act(function()
			task.wait()
		end)
	until #get().available == 0

	storybooks = get()

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

	local get = renderHook(function()
		return useStorybooks(container)
	end, {
		wrapper = Wrapper,
	})

	repeat
		act(function()
			task.wait()
		end)
	until #get().available > 0

	local storybooks = get()
	expect(storybooks.available[1]).toMatchObject({
		name = "Sample",
	})

	storybookModule.Source = [[
			return {
				name = "New Name",
				storyRoots = {
					Instance.new("Folder")
				}
			}
		]]

	repeat
		act(function()
			task.wait()
		end)
	until get() ~= storybooks

	storybooks = get()
	expect(storybooks.available[1]).toMatchObject({
		name = "New Name",
	})
end)
