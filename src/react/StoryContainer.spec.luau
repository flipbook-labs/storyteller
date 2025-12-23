local HttpService = game:GetService("HttpService")
local JestGlobals = require("@pkg/JestGlobals")
local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")

local createStorybook = require("@root/test-utils/createStorybook")

local StoryContainer = require("./StoryContainer")

local beforeEach = JestGlobals.beforeEach
local expect = JestGlobals.expect
local test = JestGlobals.test
local describe = JestGlobals.describe

local container
local root
local storyModule
local storybook

beforeEach(function()
	container = Instance.new("Folder")

	root = ReactRoblox.createRoot(container)

	storyModule = Instance.new("ModuleScript")
	storyModule.Name = "Foo.story"

	storybook = createStorybook()
end)

test("render a basic Frame", function()
	storyModule.Source = [[
		return {
			story = function(props)
				local frame = Instance.new("Frame")
				frame.Name = "TestFrame"
				frame.Size = UDim2.fromOffset(100, 100)
				frame.BackgroundColor3 = Color3.fromRGB(255, 0, 255)

				return frame
			end
		}
	]]

	root:render(React.createElement(StoryContainer, {
		storyModule = storyModule,
		storybook = storybook,
	}))

	expect(container:FindFirstChild("TestFrame", true)).toBeDefined()
end)

describe("extraProps", function()
	test("extraProps get combined to StoryProps", function()
		storyModule.Source = [[
			local HttpService = game:GetService("HttpService")

			return {
				story = function(props)
					local label = Instance.new("TextLabel")
					label.Text = HttpService:JSONEncode(props)

					return label
				end
			}
		]]

		local extraProps = {
			container = Instance.new("Folder"),
			story = false,
		}

		root:render(React.createElement(StoryContainer, {
			storyModule = storyModule,
			storybook = storybook,
			extraProps = extraProps,
		}))

		local label = container:FindFirstChild("TextLabel", true)
		assert(label and label:IsA("TextLabel"), "must be a text label")

		local props = HttpService:JSONDecode(label.Text)

		expect(props).toMatchObject({
			container = container,
			story = expect.any("boolean"),
		})
	end)

	test("extraProps cannot override certain default props", function()
		local extraProps = {
			container = Instance.new("Folder"),
			story = false,
		}
	end)

	test("component updates when extraProps changes", function() end)
end)

test("onError is called when a story experiences an error", function()
	-- storyModule
	-- storybook
	-- onError
end)
