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

local DEFAULT_TIMEOUT = 1

local function waitForAct(callback: () -> (), options: { timeout: number?, interval: number? }?)
	local timeout = if options and options.timeout then options.timeout else DEFAULT_TIMEOUT
	local interval = if options and options.interval then options.interval else 0

	local startedAt = os.clock()
	local lastError

	while true do
		local ok, err = pcall(callback)

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
	end)

	waitForAct(function()
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
	end)

	waitForAct(function()
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
	end)

	local storybooks

	waitForAct(function()
		storybooks = get()

		expect(#storybooks.available).toBe(0)
		expect(#storybooks.unavailable).toBe(0)
	end)

	act(function()
		storybookModule.Parent = container
		task.wait()
	end)

	waitForAct(function()
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

	waitForAct(function()
		local storybooks = getStorybooks()

		expect(#storybooks.available).toBe(0)
		expect(#storybooks.unavailable).toBe(0)
	end)

	act(function()
		moduleScript.Name = "Foo.storybook"
		task.wait()
	end)

	waitForAct(function()
		local storybooks = getStorybooks()

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
	end)

	waitForAct(function()
		local storybooks = get()

		expect(#storybooks.available).toBe(1)
		expect(#storybooks.unavailable).toBe(0)
	end)

	act(function()
		storybookModule:Destroy()
		task.wait()
	end)

	waitForAct(function()
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
	end)

	waitForAct(function()
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

	waitForAct(function()
		local storybooks = get()

		expect(storybooks.available[1]).toMatchObject({
			name = "New Name",
		})
	end)
end)
