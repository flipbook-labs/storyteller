local JestGlobals = require("@pkg/JestGlobals")
local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")

local createStory = require("@root/test-utils/createStory")

local StoryContainer = require("./StoryContainer")

local act = ReactRoblox.act
local beforeEach = JestGlobals.beforeEach
local expect = JestGlobals.expect
local test = JestGlobals.test
local describe = JestGlobals.describe

local container
local root
local storyModule

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
		local storyProps

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
				},
			}))
		end)

		expect(storyProps.controls).toMatchObject({
			foo = false,
			bar = "Hello, World!",
			font = Enum.Font.GothamBold,
		})
	end)
end)

describe("extraProps", function()
	test("extraProps get combined to StoryProps", function()
		local storyProps

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
		local storyProps

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
		local storyProps

		local story = createStory({
			story = function(_storyProps)
				storyProps = _storyProps
				return nil
			end,
		})

		local setExtraProps

		local function Wrapper()
			local extraProps
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

test("onError is called when a story experiences an error", function()
	-- storyModule
	-- storybook
	-- onError
end)
