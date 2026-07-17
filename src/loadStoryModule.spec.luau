local JestGlobals = require("@pkg/JestGlobals")

local loadStoriesFromModule = require("./loadStoriesFromModule")
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
		source = Instance.new("ModuleScript"),
	}

	mockRoactStorybook = {
		name = "Roact Storybook",
		storyRoots = {},
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
		id = "Sample",
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

describe("multiple stories", function()
	test("loads an ordered array and inherits module defaults", function()
		local storybook: types.LoadedStorybook = {
			name = "Storybook",
			storyRoots = {},
			source = Instance.new("ModuleScript"),
			packages = {},
		}

		local storyModule = createMockStoryModule([[
			return {
				name = "Buttons",
				summary = "Shared summary",
				props = {
					size = "Medium",
					variant = "Default",
				},
				stories = {
					{
						id = "primary",
						name = "Primary",
						story = function() end,
					},
					{
						name = "Secondary",
						props = {
							variant = "Secondary",
						},
						story = function() end,
					},
				}
			}
		]])

		local stories = loadStoriesFromModule(storyModule, storybook)

		expect(#stories).toBe(2)
		expect(stories[1]).toMatchObject({
			id = "primary",
			name = "Primary",
			summary = "Shared summary",
			props = {
				size = "Medium",
				variant = "Default",
			},
		})
		expect(stories[2]).toMatchObject({
			id = "Secondary",
			name = "Secondary",
			summary = "Shared summary",
			props = {
				size = "Medium",
				variant = "Secondary",
			},
		})
	end)

	test("sorts dictionary stories alphabetically by key", function()
		local storyModule = createMockStoryModule([[
			return {
				stories = {
					Zebra = function() end,
					apple = function() end,
					Banana = {
						name = "Custom banana",
						story = function() end,
					},
				}
			}
		]])

		local stories = loadStoriesFromModule(storyModule, mockPlainStorybook)

		expect(stories[1]).toMatchObject({
			id = "apple",
			name = "apple",
		})
		expect(stories[2]).toMatchObject({
			id = "Custom banana",
			name = "Custom banana",
		})
		expect(stories[3]).toMatchObject({
			id = "Zebra",
			name = "Zebra",
		})
	end)

	test("keeps loadStoryModule compatible by returning the first story", function()
		local storyModule = createMockStoryModule([[
			return {
				stories = {
					{ name = "First", story = function() end },
					{ name = "Second", story = function() end },
				}
			}
		]])

		local story = loadStoryModule(storyModule, mockPlainStorybook)

		expect(story.id).toBe("First")
		expect(story.name).toBe("First")
	end)

	test("rejects duplicate story ids", function()
		local storyModule = createMockStoryModule([[
			return {
				stories = {
					{ id = "duplicate", story = function() end },
					{ id = "duplicate", story = function() end },
				}
			}
		]])

		expect(function()
			loadStoriesFromModule(storyModule, mockPlainStorybook)
		end).toThrow("duplicated")
	end)
end)
