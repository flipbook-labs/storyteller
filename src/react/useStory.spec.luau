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

	local story, err = get()

	expect(err).toBeUndefined()

	expect(story).toEqual({
		name = "Sample",
		story = expect.any("function"),
		source = storyModule,
		storybook = storybook,
	})
end)

test("handles story errors", function()
	storyModule.Source = "syntax error" .. storyModule.Source

	local get = renderHook(function()
		return useStory(storyModule, storybook)
	end)

	local story, err = get()

	expect(err).toBeDefined()
	expect(story).toBeUndefined()
end)

test("re-renders on module changes", function()
	local get = renderHook(function()
		return useStory(storyModule, storybook)
	end)

	local story, err = get()

	expect(err).toBeUndefined()
	expect(story).toEqual(expect.objectContaining({
		name = "Sample",
	}))

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

	story, err = get()

	expect(err).toBeUndefined()
	expect(story).toEqual(expect.objectContaining({
		name = "Foo",
	}))
end)

test("reloads on dependency changes", function()
	local get = renderHook(function()
		return useStory(storyModule, storybook)
	end)

	local story = get()

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

	local newStory = get()

	expect(newStory).never.toBe(story)
end)
