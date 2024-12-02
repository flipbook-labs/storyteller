local JestGlobals = require("@pkg/JestGlobals")
local ModuleLoader = require("@pkg/ModuleLoader")

local loadStoryModule = require("./loadStoryModule")
local types = require("@root/types")

local describe = JestGlobals.describe
local jest = JestGlobals.jest
local test = JestGlobals.test
local expect = JestGlobals.expect

local MOCK_PLAIN_STORYBOOK: types.LoadedStorybook = {
	name = "Plain Storybook",
	storyRoots = {},
}

local MOCK_ROACT_STORYBOOK: types.LoadedStorybook = {
	name = "Roact Storybook",
	storyRoots = {},
	packages = {
		Roact = {
			createElement = jest.fn(),
			mount = jest.fn(),
			unmount = jest.fn(),
		},
	},
}

local MOCK_REACT_STORYBOOK: types.LoadedStorybook = {
	name = "React Storybook",
	storyRoots = {},
	packages = {
		React = {
			createElement = jest.fn(),
		},
		ReactRoblox = {
			createRoot = jest.fn(),
		},
	},
}

local function createMockStoryModule(source: string): ModuleScript
	local storyModule = Instance.new("ModuleScript")
	storyModule.Name = "Foo.story"
	storyModule.Source = source

	return storyModule
end

test("load a story module as a table", function()
	local loader = ModuleLoader.new()
	local storyModule = createMockStoryModule([[
		return {
			name = "Sample",
			story = function() end
		}
	]])

	local story = loadStoryModule(loader, storyModule, MOCK_PLAIN_STORYBOOK)

	expect(story).toEqual({
		name = "Sample",
		source = expect.anything(),
		story = expect.any("function"),
		storybook = MOCK_PLAIN_STORYBOOK,
	})
end)

test("handle Hoarcekat stories", function()
	local loader = ModuleLoader.new()
	local storyModule = createMockStoryModule([[
		return function(target)
			local gui = Instance.new("TextLabel")
			gui.Parent = target

			return function()
				gui:Destroy()
			end
		end
	]])

	local story = loadStoryModule(loader, storyModule, MOCK_PLAIN_STORYBOOK)

	expect(story).toBeDefined()
end)

test("use the name of the story module for the story name", function()
	local loader = ModuleLoader.new()
	local storyModule = createMockStoryModule([[
			return {
				story = function() end
			}
		]])
	storyModule.Name = "SampleName.story"

	local story = loadStoryModule(loader, storyModule, MOCK_PLAIN_STORYBOOK)

	assert(story ~= nil, "story not defined")
	expect(story.name).toEqual("SampleName")
end)

test("pass the storybook's renderer to the story", function()
	local loader = ModuleLoader.new()
	local storyModule = createMockStoryModule([[
		return {
			story = function() end
		}
	]])

	local story = loadStoryModule(loader, storyModule, MOCK_REACT_STORYBOOK)

	expect(story).toBeDefined()

	story = loadStoryModule(loader, storyModule, MOCK_ROACT_STORYBOOK)

	expect(story).toBeDefined()
end)

test("generic failures for stories", function()
	local loader = ModuleLoader.new()
	local storyModule = createMockStoryModule([[
			syntax error
			return {

			}
		]])

	expect(function()
		loadStoryModule(loader, storyModule, MOCK_PLAIN_STORYBOOK)
	end).toThrow("Failed to load story")
end)

test("malformed stories", function()
	local loader = ModuleLoader.new()
	local storyModule = createMockStoryModule([[
		return {
			name = false,
			story = "should be a function"
		}
	]])

	expect(function()
		loadStoryModule(loader, storyModule, MOCK_PLAIN_STORYBOOK)
	end).toThrow("Story is malformed")
end)

describe("legacy support", function()
	test("packages attached to the story get grouped in `packages` object", function()
		local loader = ModuleLoader.new()

		local storybook: types.LoadedStorybook = {
			name = "Storybook",
			storyRoots = {},
		}

		local storyModule = createMockStoryModule([[
			return {
				story = function() end,
				react = {},
				reactRoblox = {},
			}
		]])

		local story = loadStoryModule(loader, storyModule, storybook)

		expect(story).toMatchObject({
			story = expect.anything(),
			packages = {
				React = expect.anything(),
				ReactRoblox = expect.anything(),
			},
		})
	end)

	test("packages attached to the story take precedence over the storybook", function()
		local loader = ModuleLoader.new()

		local storybook: types.LoadedStorybook = {
			name = "Storybook",
			storyRoots = {},
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

		local story = loadStoryModule(loader, storyModule, storybook)

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
