local JestGlobals = require("@pkg/JestGlobals")
local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")

local ControlTypes = require("@root/controls/ControlTypes")
local createStory = require("@root/test-utils/createStory")
local types = require("@root/types")

local StoryContainer = require("./StoryContainer")

type StoryControls = ControlTypes.StoryControls
type StoryControlsSchema = ControlTypes.StoryControlsSchema
type LoadedStory<T> = types.LoadedStory<T>

local act = ReactRoblox.act
local jest = JestGlobals.jest
local beforeEach = JestGlobals.beforeEach
local expect = JestGlobals.expect
local test = JestGlobals.test
local describe = JestGlobals.describe

local container: Folder
local root: ReactRoblox.RootType
local storyModule: ModuleScript

beforeEach(function()
	container = Instance.new("Folder")

	root = ReactRoblox.createRoot(container)

	storyModule = Instance.new("ModuleScript")
	storyModule.Name = "Foo.story"
end)

test("render and unmount a basic Frame", function()
	local story = createStory({
		story = function()
			local frame = Instance.new("Frame")
			frame.Name = "TestFrame"
			frame.Size = UDim2.fromOffset(100, 100)
			frame.BackgroundColor3 = Color3.fromRGB(255, 0, 255)

			return frame
		end,
	})

	act(function()
		root:render(React.createElement(StoryContainer, {
			story = story,
		}))
	end)

	expect(container:FindFirstChild("TestFrame", true)).toBeDefined()

	act(function()
		root:unmount()
	end)

	expect(#container:GetDescendants()).toBe(0)
end)

describe("controls", function()
	test("controls get overlaid on the ControlsSchema", function()
		local storyProps: types.StoryProps

		local story = createStory({
			controls = {
				foo = true,
				bar = "Hello, World!",
				font = {
					Enum.Font.BuilderSans,
					Enum.Font.GothamBold,
				},
			},
			story = function(_storyProps)
				storyProps = _storyProps
				return nil
			end,
		})

		act(function()
			root:render(React.createElement(StoryContainer, {
				story = story,
			}))
		end)

		expect(storyProps).toBeDefined()

		expect(storyProps.controls).toBeDefined()
		expect(storyProps.controls).toMatchObject({
			foo = true,
			bar = "Hello, World!",
			font = Enum.Font.BuilderSans,
		})

		act(function()
			root:render(React.createElement(StoryContainer, {
				story = story,
				controls = {
					foo = false,
					font = Enum.Font.GothamBold,
				} :: StoryControls,
			}))
		end)

		expect(storyProps.controls).toMatchObject({
			foo = false,
			bar = "Hello, World!",
			font = Enum.Font.GothamBold,
		})
	end)

	test("component updates when controls change", function()
		local storyProps: types.StoryProps

		local story = createStory({
			controls = {
				foo = true,
				bar = "Hello, World!",
			},
			story = function(_storyProps)
				storyProps = _storyProps
				return nil
			end,
		})

		local setControls: (controls: StoryControls) -> ()

		local initialControls: StoryControls = {
			foo = true,
			bar = "Hello, World!",
		}

		local function Wrapper()
			local storyControls: StoryControls
			storyControls, setControls = React.useState(initialControls)

			return React.createElement(StoryContainer, {
				story = story,
				controls = storyControls,
			})
		end

		act(function()
			root:render(React.createElement(Wrapper))
		end)

		local snapshot = storyProps

		act(function()
			local nextControls: StoryControls = {
				foo = false,
				bar = "Goodbye!",
			}
			setControls(nextControls)
		end)

		expect(storyProps).never.toBe(snapshot)
		expect(storyProps.controls.foo).toBe(false)
		expect(storyProps.controls.bar).toBe("Goodbye!")
	end)
end)

describe("extraProps", function()
	test("extraProps get combined to StoryProps", function()
		local storyProps: types.StoryProps

		local story = createStory({
			story = function(_storyProps)
				storyProps = _storyProps
				return nil
			end,
		})

		local extraProps = {
			theme = "Dark",
			locale = "en-us",
		}

		act(function()
			root:render(React.createElement(StoryContainer, {
				story = story,
				extraProps = extraProps,
			}))
		end)

		expect(storyProps).toBeDefined()
		expect(storyProps).toMatchObject({
			-- Extra props
			theme = "Dark",
			locale = "en-us",

			-- Storyteller
			container = expect.any("Instance"),
			story = story,
		})
	end)

	test("extraProps cannot override certain default props", function()
		local storyProps: types.StoryProps

		local story = createStory({
			story = function(_storyProps)
				storyProps = _storyProps
				return nil
			end,
		})

		-- These are props that Storyteller specifically manages and cannot be
		-- overridden by the consumer
		local extraProps = {
			container = { foo = true },
			story = false,
		}

		act(function()
			root:render(React.createElement(StoryContainer, {
				story = story,
				extraProps = extraProps,
			}))
		end)

		expect(storyProps).toBeDefined()
		expect(storyProps).toMatchObject({
			container = expect.any("Instance"),
			story = story,
		})
	end)

	test("component updates when extraProps changes", function()
		local storyProps: types.StoryProps

		local story = createStory({
			story = function(_storyProps)
				storyProps = _storyProps
				return nil
			end,
		})

		local setExtraProps: (extraProps: types.ExtraStoryProps) -> ()

		local function Wrapper()
			local extraProps: types.ExtraStoryProps
			extraProps, setExtraProps = React.useState({
				theme = "Dark",
				locale = "en-us",
			})

			return React.createElement(StoryContainer, {
				story = story,
				extraProps = extraProps,
			})
		end

		act(function()
			root:render(React.createElement(Wrapper))
		end)

		local snapshot = storyProps

		act(function()
			setExtraProps({
				theme = "Light",
				locale = "en-us",
			})
		end)

		expect(storyProps).never.toBe(snapshot)
		expect(storyProps.theme).toBe("Light")
	end)
end)

test("unmounts old story and mounts new story when story changes", function()
	local story1 = createStory({
		story = function()
			local frame = Instance.new("Frame")
			frame.Name = "Story1Frame"

			return frame
		end,
	})

	local story2 = createStory({
		story = function()
			local frame = Instance.new("Frame")
			frame.Name = "Story2Frame"

			return frame
		end,
	})

	local setStory: (story: typeof(story1)) -> ()

	local function Wrapper()
		local story: typeof(story1)
		story, setStory = React.useState(story1)

		return React.createElement(StoryContainer, {
			story = story,
		})
	end

	act(function()
		root:render(React.createElement(Wrapper))
	end)

	expect(container:FindFirstChild("Story1Frame", true)).toBeDefined()

	act(function()
		setStory(story2)
	end)

	expect(container:FindFirstChild("Story1Frame", true)).toBeUndefined()
	expect(container:FindFirstChild("Story2Frame", true)).toBeDefined()
end)

describe("story props", function()
	test("props defined on the story get joined with StoryProps", function()
		local storyProps: types.StoryProps

		local story = createStory({
			props = {
				foo = true,
			},
			story = function(_storyProps)
				storyProps = _storyProps
				return nil
			end,
		})

		local extraProps = {
			theme = "Dark",
			locale = "en-us",
		}

		act(function()
			root:render(React.createElement(StoryContainer, {
				story = story,
				extraProps = extraProps,
			}))
		end)

		expect(storyProps).toBeDefined()
		expect(storyProps).toMatchObject({
			foo = true,
			theme = "Dark",
			locale = "en-us",
			container = expect.any("Instance"),
			story = story,
		})
	end)

	test("a story's props cannot override reserved props", function()
		local storyProps: types.StoryProps

		local story = createStory({
			props = {
				story = { foo = true },
				container = "This is supposed to be an Instance",
			},
			story = function(_storyProps)
				storyProps = _storyProps
				return nil
			end,
		})

		local extraProps = {
			theme = "Dark",
			locale = "en-us",
		}

		act(function()
			root:render(React.createElement(StoryContainer, {
				story = story,
				extraProps = extraProps,
			}))
		end)

		expect(storyProps).toBeDefined()
		expect(storyProps).toMatchObject({
			theme = "Dark",
			locale = "en-us",
			container = expect.any("Instance"),
			story = story,
		})
	end)
end)

test("lifecycle cleanup is verified after unmount", function()
	local story = createStory({
		story = function()
			local frame = Instance.new("Frame")
			frame.Name = "CleanupTestFrame"

			return frame
		end,
	})

	act(function()
		root:render(React.createElement(StoryContainer, {
			story = story,
		}))
	end)

	expect(container:FindFirstChild("CleanupTestFrame", true)).toBeDefined()

	act(function()
		root:unmount()
	end)

	expect(container:FindFirstChild("CleanupTestFrame", true)).toBeUndefined()
end)

test("onError is called when a story experiences an error during mount", function()
	local mockOnError = jest.fn()

	local story = createStory({
		story = function()
			error("Test error during update")
			return nil
		end,
	})

	expect(mockOnError).never.toHaveBeenCalled()

	act(function()
		root:render(React.createElement(StoryContainer, {
			story = story,
			controls = {
				foo = false,
			} :: StoryControls,
			onError = mockOnError,
		}))
	end)

	expect(mockOnError).toHaveBeenCalled()
end)

describe("a story whose teardown throws", function()
	local function createStoryWithFailingTeardown(frameName: string)
		return createStory({
			story = function(storyContainer: Instance, _props: types.StoryProps)
				local frame = Instance.new("Frame")
				frame.Name = frameName
				frame.Parent = storyContainer

				return function()
					error("teardown failed")
				end
			end,
		})
	end

	test("mounts the next story without the error escaping", function()
		local mockOnError = jest.fn()
		local brokenStory = createStoryWithFailingTeardown("BrokenStoryFrame")
		local nextStory = createStory({
			story = function()
				local frame = Instance.new("Frame")
				frame.Name = "NextStoryFrame"

				return frame
			end,
		})

		local setStory: (story: LoadedStory<unknown>) -> ()

		local function Wrapper()
			local story: LoadedStory<unknown>
			story, setStory = React.useState(brokenStory :: LoadedStory<unknown>)

			return React.createElement(StoryContainer, {
				story = story,
				onError = mockOnError,
			})
		end

		act(function()
			root:render(React.createElement(Wrapper))
		end)

		expect(container:FindFirstChild("BrokenStoryFrame", true)).toBeDefined()

		expect(function()
			act(function()
				setStory(nextStory :: LoadedStory<unknown>)
			end)
		end).never.toThrow()

		expect(container:FindFirstChild("NextStoryFrame", true)).toBeDefined()
		expect(mockOnError).never.toHaveBeenCalled()
	end)

	test("unmounts without the error escaping", function()
		local story = createStoryWithFailingTeardown("BrokenStoryFrame")

		act(function()
			root:render(React.createElement(StoryContainer, {
				story = story,
			}))
		end)

		expect(container:FindFirstChild("BrokenStoryFrame", true)).toBeDefined()

		expect(function()
			act(function()
				root:unmount()
			end)
		end).never.toThrow()
	end)
end)
