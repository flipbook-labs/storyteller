local JestGlobals = require("@pkg/JestGlobals")
local ModuleLoader = require("@pkg/ModuleLoader")

local loadStoryModule = require("./loadStoryModule")
local types = require("@root/types")

local describe = JestGlobals.describe
local jest = JestGlobals.jest
local test = JestGlobals.test
local expect = JestGlobals.expect
local beforeEach = JestGlobals.beforeEach
local afterEach = JestGlobals.afterEach

local mockPlainStorybook: types.LoadedStorybook
local mockRoactStorybook: types.LoadedStorybook
local mockReactStorybook: types.LoadedStorybook

beforeEach(function()
	mockPlainStorybook = {
		name = "Plain Storybook",
		storyRoots = {},
		loader = ModuleLoader.new(),
		source = Instance.new("ModuleScript"),
	}

	mockRoactStorybook = {
		name = "Roact Storybook",
		storyRoots = {},
		loader = ModuleLoader.new(),
		source = Instance.new("ModuleScript"),
		packages = {
			Roact = {
				createElement = jest.fn(),
				mount = jest.fn(),
				unmount = jest.fn(),
			},
		},
	}

	mockReactStorybook = {
		name = "React Storybook",
		storyRoots = {},
		loader = ModuleLoader.new(),
		source = Instance.new("ModuleScript"),
		packages = {
			React = {
				createElement = jest.fn(),
			},
			ReactRoblox = {
				createRoot = jest.fn(),
			},
		},
	}
end)

afterEach(function()
	jest.resetAllMocks()
end)

local function createMockStoryModule(source: string): ModuleScript
	local storyModule = Instance.new("ModuleScript")
	storyModule.Name = "Foo.story"
	storyModule.Source = source

	return storyModule
end

test("load a story module as a table", function()
	local storyModule = createMockStoryModule([[
		return {
			name = "Sample",
			story = function() end
		}
	]])

	local story = loadStoryModule(storyModule, mockPlainStorybook)

	expect(story).toEqual({
		name = "Sample",
		source = expect.anything(),
		story = expect.any("function"),
		storybook = mockPlainStorybook,
	})
end)

test("handle Hoarcekat stories", function()
	local storyModule = createMockStoryModule([[
		return function(target)
			local gui = Instance.new("TextLabel")
			gui.Parent = target

			return function()
				gui:Destroy()
			end
		end
	]])

	local story = loadStoryModule(storyModule, mockPlainStorybook)

	expect(story).toBeDefined()
end)

test("use the name of the story module for the story name", function()
	local storyModule = createMockStoryModule([[
			return {
				story = function() end
			}
		]])
	storyModule.Name = "SampleName.story"

	local story = loadStoryModule(storyModule, mockPlainStorybook)

	assert(story ~= nil, "story not defined")
	expect(story.name).toEqual("SampleName")
end)

test("pass the storybook's renderer to the story", function()
	local storyModule = createMockStoryModule([[
		return {
			story = function() end
		}
	]])

	local story = loadStoryModule(storyModule, mockReactStorybook)

	expect(story).toBeDefined()

	story = loadStoryModule(storyModule, mockRoactStorybook)

	expect(story).toBeDefined()
end)

test("generic failures for stories", function()
	local storyModule = createMockStoryModule([[
			syntax error
			return {

			}
		]])

	expect(function()
		loadStoryModule(storyModule, mockPlainStorybook)
	end).toThrow("Failed to load story")
end)

test("malformed stories", function()
	local storyModule = createMockStoryModule([[
		return {
			name = false,
			story = "should be a function"
		}
	]])

	expect(function()
		loadStoryModule(storyModule, mockPlainStorybook)
	end).toThrow("Story is malformed")
end)

describe("legacy support", function()
	test("packages attached to the story get grouped in `packages` object", function()
		local storybook: types.LoadedStorybook = {
			name = "Storybook",
			storyRoots = {},
			loader = ModuleLoader.new(),
			source = Instance.new("ModuleScript"),
		}

		local storyModule = createMockStoryModule([[
			return {
				story = function() end,
				react = {},
				reactRoblox = {},
			}
		]])

		local story = loadStoryModule(storyModule, storybook)

		expect(story).toMatchObject({
			story = expect.anything(),
			packages = {
				React = expect.anything(),
				ReactRoblox = expect.anything(),
			},
		})
	end)

	test("packages attached to the story take precedence over the storybook", function()
		local storybook: types.LoadedStorybook = {
			name = "Storybook",
			storyRoots = {},
			loader = ModuleLoader.new(),
			source = Instance.new("ModuleScript"),
			packages = {
				Roact = {},
			},
		}

		local storyModule = createMockStoryModule([[
			return {
				story = function() end,
				react = {},
				reactRoblox = {},
			}
		]])

		local story = loadStoryModule(storyModule, storybook)

		expect(story).toMatchObject({
			story = expect.anything(),

			-- Don't inherit Roact from the storybook since the story is
			-- explicitly using React, despite not grouping it in the
			-- `packages` object
			packages = {
				React = expect.anything(),
				ReactRoblox = expect.anything(),
			},
		})
	end)
end)

describe("roblox internal", function()
	-- Right now we don't support rendering more than one story. For now, we
	-- pick a random one to render.
	test("pick a single substory to show", function()
		local storybook: types.LoadedStorybook = {
			name = "Storybook",
			storyRoots = {},
			loader = ModuleLoader.new(),
			source = Instance.new("ModuleScript"),
			packages = {},
		}

		local storyModule = createMockStoryModule([[
			return {
				stories = {
					One = function() end,
					Two = function() end,
					Three = function() end,
				}
			}
		]])

		local story = loadStoryModule(storyModule, storybook)

		expect(story.story).toBeDefined()
		expect((story :: any).substories).toBeUndefined()
	end)
end)
