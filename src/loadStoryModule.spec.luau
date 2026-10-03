local JestGlobals = require("@pkg/JestGlobals")

local loadStoriesFromModule = require("./loadStoriesFromModule")
local loadStoryModule = require("./loadStoryModule")
local render = require("@root/render")
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
		} :: types.StoryPackages,
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
		} :: types.StoryPackages,
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
	expect(story.id).toBe("default")
	expect(story.name).toBe("Foo")

	local container = Instance.new("Folder")
	local lifecycle = render(container, story)
	expect(container:FindFirstChildWhichIsA("TextLabel")).toBeDefined()

	lifecycle.unmount()
	expect(#container:GetChildren()).toBe(0)
end)

test("legacy function stories never inherit storybook packages", function()
	local storybook: types.LoadedStorybook = {
		name = "Storybook",
		storyRoots = {},
		source = Instance.new("ModuleScript"),
		packages = {
			React = {},
		} :: types.StoryPackages,
	}

	local storyModule = createMockStoryModule([[
		return function() end
	]])

	local story = loadStoryModule(storyModule, storybook)

	expect(story.packages).toEqual({})
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

test("pass the storybook's renderer packages to the story", function()
	local storyModule = createMockStoryModule([[
		return {
			story = function() end
		}
	]])

	local story = loadStoryModule(storyModule, mockReactStorybook)

	expect(story.packages).toBe(mockReactStorybook.packages)

	story = loadStoryModule(storyModule, mockRoactStorybook)

	expect(story.packages).toBe(mockRoactStorybook.packages)
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
			} :: types.StoryPackages,
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

		local stories = loadStoriesFromModule(storyModule, mockPlainStorybook)

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
			id = "Banana",
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

	test("rejects modules that define both story and stories", function()
		local storyModule = createMockStoryModule([[
			return {
				story = function() end,
				stories = {
					{ story = function() end },
				},
			}
		]])

		expect(function()
			loadStoriesFromModule(storyModule, mockPlainStorybook)
		end).toThrow("both `story` and `stories`")
	end)

	test("rejects empty story groups", function()
		local storyModule = createMockStoryModule([[
			return {
				stories = {},
			}
		]])

		expect(function()
			loadStoriesFromModule(storyModule, mockPlainStorybook)
		end).toThrow("at least one story")
	end)

	test("rejects story entries without content", function()
		local storyModule = createMockStoryModule([[
			return {
				stories = {
					{ name = "Missing" },
				},
			}
		]])

		expect(function()
			loadStoriesFromModule(storyModule, mockPlainStorybook)
		end).toThrow('Story "Missing" is malformed')
	end)

	test("assigns index-based ids to bare function entries in an array", function()
		local storyModule = createMockStoryModule([[
			return {
				stories = {
					function() end,
					function() end,
				},
			}
		]])

		local stories = loadStoriesFromModule(storyModule, mockPlainStorybook)

		expect(#stories).toBe(2)
		expect(stories[1]).toMatchObject({
			id = "1",
			name = "1",
			story = expect.any("function"),
		})
		expect(stories[2]).toMatchObject({
			id = "2",
			name = "2",
			story = expect.any("function"),
		})
	end)

	test("merges module-level controls into each story with per-story overrides", function()
		local storyModule = createMockStoryModule([[
			return {
				controls = {
					isDisabled = false,
					size = "Medium",
				},
				stories = {
					{
						name = "Inherits",
						story = function() end,
					},
					{
						name = "Overrides",
						controls = {
							size = "Large",
						},
						story = function() end,
					},
				},
			}
		]])

		local stories = loadStoriesFromModule(storyModule, mockPlainStorybook)

		expect(stories[1].controls).toEqual({
			isDisabled = false,
			size = "Medium",
		})
		expect(stories[2].controls).toEqual({
			isDisabled = false,
			size = "Large",
		})
	end)

	test("story packages merge with module defaults and fall back to the storybook's", function()
		-- Real packages are libraries such as React. These marker tables only
		-- make the merge result easy to inspect.
		local storybook: types.LoadedStorybook = {
			name = "Storybook",
			storyRoots = {},
			source = Instance.new("ModuleScript"),
			packages = {
				React = { fromStorybook = true },
			} :: types.StoryPackages,
		}

		local storyModule = createMockStoryModule([[
			return {
				packages = {
					Shared = { fromModule = true },
				},
				stories = {
					{
						name = "MergesModuleDefaults",
						packages = {
							Extra = { fromStory = true },
						},
						story = function() end,
					},
				},
			}
		]])

		local stories = loadStoriesFromModule(storyModule, storybook)

		expect(stories[1].packages).toEqual({
			Shared = { fromModule = true },
			Extra = { fromStory = true },
		})

		local plainModule = createMockStoryModule([[
			return {
				stories = {
					{ name = "UsesStorybook", story = function() end },
				},
			}
		]])

		local plainStories = loadStoriesFromModule(plainModule, storybook)

		expect(plainStories[1].packages).toEqual({
			React = { fromStorybook = true },
		})
	end)

	test("rejects non-string story ids", function()
		local storyModule = createMockStoryModule([[
			return {
				stories = {
					{ id = 123, story = function() end },
				},
			}
		]])

		expect(function()
			loadStoriesFromModule(storyModule, mockPlainStorybook)
		end).toThrow("Story at index 1 is malformed")
	end)

	test("rejects stories tables with non-string keys", function()
		local storyModule = createMockStoryModule([[
			return {
				stories = {
					[1] = function() end,
					Named = function() end,
				},
			}
		]])

		expect(function()
			loadStoriesFromModule(storyModule, mockPlainStorybook)
		end).toThrow("`stories` must be an array or a dictionary with string keys")
	end)
end)

describe("legacy passthrough", function()
	-- Loaded Stories carry every field their source defines. That passthrough
	-- is not a supported contract and may be removed. Update or delete these
	-- tests if it is.
	test("keeps custom fields from a single Story's source", function()
		local storyModule = createMockStoryModule([[
				return {
					customField = "single",
					story = function() end,
				}
			]])

		local story = loadStoryModule(storyModule, mockPlainStorybook)

		expect(story).toMatchObject({ customField = "single" })
	end)

	test("keeps custom fields from grouped Stories and their module defaults", function()
		local storyModule = createMockStoryModule([[
				return {
					groupField = "group",
					stories = {
						{ name = "First", entryField = "entry", story = function() end },
						{ name = "Second", groupField = "override", story = function() end },
					},
				}
			]])

		local stories = loadStoriesFromModule(storyModule, mockPlainStorybook)

		expect(stories[1]).toMatchObject({ groupField = "group", entryField = "entry" })
		expect(stories[1]).never.toHaveProperty("stories")
		expect(stories[2]).toMatchObject({ groupField = "override" })
	end)
end)

describe("storybook middleware", function()
	test("mapDefinition receives the loaded Story", function()
		local receivedStory: unknown
		mockPlainStorybook.mapDefinition = function(storyDefinition)
			receivedStory = storyDefinition
			return storyDefinition
		end

		local storyModule = createMockStoryModule([[
			return {
				summary = "From the source",
				story = function(props)
					local label = Instance.new("TextLabel")
					label.Parent = props.container
				end,
			}
		]])

		local story = loadStoryModule(storyModule, mockPlainStorybook)
		local container = Instance.new("Folder")
		local lifecycle = render(container, story)

		expect(receivedStory).toMatchObject({ summary = "From the source" })
		expect(container:FindFirstChildWhichIsA("TextLabel")).toBeDefined()

		lifecycle.unmount()
	end)

	test("mapStory wraps the loaded Story", function()
		local receivedStory: unknown
		mockPlainStorybook.mapStory = function(originalStory)
			receivedStory = originalStory
			return function()
				local wrapper = Instance.new("Frame")
				wrapper.Name = "Wrapper"
				return wrapper
			end
		end

		local storyModule = createMockStoryModule([[
			return {
				story = function() end,
			}
		]])

		local story = loadStoryModule(storyModule, mockPlainStorybook)
		local container = Instance.new("Folder")
		local lifecycle = render(container, story)

		expect(receivedStory).toBe(story.story)
		expect(container:FindFirstChild("Wrapper")).toBeDefined()

		lifecycle.unmount()
	end)
end)

describe("storybook freshness", function()
	test("prefers the storybook reloaded from source over the provided copy", function()
		local storybookModule = Instance.new("ModuleScript")
		storybookModule.Name = "Fresh.storybook"
		storybookModule.Source = [[
			return {
				name = "Fresh",
				storyRoots = {},
			}
		]]

		local staleStorybook: types.LoadedStorybook = {
			name = "Stale",
			storyRoots = {},
			source = storybookModule,
		}

		local storyModule = createMockStoryModule([[
			return {
				story = function() end,
			}
		]])

		local story = loadStoryModule(storyModule, staleStorybook)

		expect(story.storybook.name).toBe("Fresh")
	end)

	test("falls back to the provided storybook when its source cannot load", function()
		local storybookModule = Instance.new("ModuleScript")
		storybookModule.Name = "Broken.storybook"
		storybookModule.Source = "syntax error"

		local staleStorybook: types.LoadedStorybook = {
			name = "Stale",
			storyRoots = {},
			source = storybookModule,
		}

		local storyModule = createMockStoryModule([[
			return {
				story = function() end,
			}
		]])

		local story = loadStoryModule(storyModule, staleStorybook)

		expect(story.storybook).toBe(staleStorybook)
	end)
end)

test("rejects malformed props", function()
	local storyModule = createMockStoryModule([[
		return {
			story = function() end,
			props = "not a dictionary",
		}
	]])

	expect(function()
		loadStoryModule(storyModule, mockPlainStorybook)
	end).toThrow("Story is malformed")
end)
