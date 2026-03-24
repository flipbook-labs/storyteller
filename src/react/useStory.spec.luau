local JestGlobals = require("@pkg/JestGlobals")
local ModuleLoader = require("@pkg/ModuleLoader")
local ReactRoblox = require("@pkg/ReactRoblox")

local renderHook = require("@root/test-utils/renderHook")
local types = require("@root/types")
local useStory = require("./useStory")

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
local componentModule: ModuleScript
local storyModule: ModuleScript
local storybook: LoadedStorybook

beforeEach(function()
	container = Instance.new("Folder")
	container.Parent = game

	componentModule = Instance.new("ModuleScript")
	componentModule.Name = "Component"
	componentModule.Source = [[
		local function Component(props)
			local label = Instance.new("TextButton")
			label.Text = "Click Me"

			return label
		end

		return Component
	]]
	componentModule.Parent = container

	storyModule = Instance.new("ModuleScript")
	storyModule.Name = "Sample.story"
	storyModule.Source = [[
		local Component = require(script.Parent.Component)

		return {
			story = Component
		}
	]]
	storyModule.Parent = container

	storybook = {
		name = "Storybook",
		loader = ModuleLoader.new(),
		source = Instance.new("ModuleScript"),
		storyRoots = { container },
	}
end)

afterEach(function()
	container:Destroy()
end)

test("loads a story module", function()
	local get = renderHook(function()
		return useStory(storyModule, storybook)
	end)

	waitForAct(function()
		local story, err = get()

		expect(err).toBeUndefined()

		expect(story).toEqual({
			name = "Sample",
			story = expect.any("function"),
			source = storyModule,
			storybook = storybook,
		})
	end)
end)

test("handles story errors", function()
	storyModule.Source = "syntax error" .. storyModule.Source

	local get = renderHook(function()
		return useStory(storyModule, storybook)
	end)

	waitForAct(function()
		local story, err = get()

		expect(err).toBeDefined()
		expect(story).toBeUndefined()
	end)
end)

test("re-renders on module changes", function()
	local get = renderHook(function()
		return useStory(storyModule, storybook)
	end)

	waitForAct(function()
		local story, err = get()

		expect(err).toBeUndefined()
		expect(story).toEqual(expect.objectContaining({
			name = "Sample",
		}))
	end)

	storyModule.Source = [[
		local Component = require(script.Parent.Component)

		return {
			name = "Foo",
			story = Component
		}
	]]

	-- Wait for engine events
	act(function()
		task.wait()
	end)

	waitForAct(function()
		local story, err = get()

		expect(err).toBeUndefined()
		expect(story).toEqual(expect.objectContaining({
			name = "Foo",
		}))
	end)
end)

test("reloads on dependency changes", function()
	local get = renderHook(function()
		return useStory(storyModule, storybook)
	end)

	local story

	waitForAct(function()
		story = get()
		expect(story).never.toBe(nil)
	end)

	componentModule.Source = [[
		local function Component(props)
			local label = Instance.new("TextButton")
			label.Text = "Changed"

			return label
		end

		return Component
	]]

	-- Wait for engine events
	act(function()
		task.wait()
	end)

	waitForAct(function()
		local newStory = get()

		expect(newStory).never.toBe(story)
	end)
end)
