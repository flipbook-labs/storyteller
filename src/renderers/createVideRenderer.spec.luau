local JestGlobals = require("@pkg/JestGlobals")
local Vide = require("@pkg/Vide")

local ControlTypes = require("@root/controls/ControlTypes")
local createStory = require("@root/test-utils/createStory")
local render = require("@root/render")

local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

type StoryControlsSchema = ControlTypes.StoryControlsSchema
type StoryControls = ControlTypes.StoryControls

local container
beforeEach(function()
	container = Instance.new("Folder")
end)

describe("Vide", function()
	local function TextStory()
		return Vide.create("TextLabel")({
			Text = "Hello, world!",
		})
	end

	type Props = {
		controls: {
			isDisabled: () -> boolean,
		},
	}

	local function ButtonStory(props: Props)
		return Vide.create("TextButton")({
			Text = function()
				return if props.controls.isDisabled() then "Disabled" else "Enabled"
			end,
		})
	end

	local function createVideStory(component)
		return createStory({
			story = component,
			packages = { Vide = Vide },
		})
	end

	test("render a Vide component", function()
		local story = createVideStory(TextStory)

		render(container, story)

		expect(#container:GetChildren()).toBe(1)
		expect(container:FindFirstChildWhichIsA("TextLabel")).toBeDefined()
	end)

	test("unmount a Vide component", function()
		local story = createVideStory(TextStory)
		local lifecycle = render(container, story)

		expect(#container:GetChildren()).toBe(1)

		lifecycle.unmount()

		expect(#container:GetChildren()).toBe(0)
	end)

	test("controls are transformed into Sources", function()
		local story = createVideStory(ButtonStory)
		story.controls = { isDisabled = false } :: StoryControlsSchema

		render(container, story)

		local element = container:FindFirstChildWhichIsA("TextButton")
		assert(element, "no element found")
		expect(element.Text).toBe("Disabled")
	end)

	test("update the component on arg changes", function()
		expect(#container:GetChildren()).toBe(0)

		local story = createVideStory(ButtonStory)
		story.controls = { isDisabled = true } :: StoryControlsSchema

		local lifecycle = render(container, story)

		expect(#container:GetChildren()).toBe(1)

		local element = container:FindFirstChildWhichIsA("TextButton")
		assert(element, "no element found")
		expect(element.Text).toBe("Disabled")

		lifecycle.update({ isDisabled = false } :: StoryControls)

		expect(#container:GetChildren()).toBe(1)

		local prevElement = element
		element = container:FindFirstChildWhichIsA("TextButton")
		expect(element).toBe(prevElement)

		task.wait()

		expect(element.Text).toBe("Enabled")
	end)
end)
