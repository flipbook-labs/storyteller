local JestGlobals = require("@pkg/JestGlobals")
local Roact = require("@pkg/Roact")
local createStory = require("@root/test-utils/createStory")
local render = require("@root/render")

local beforeEach = JestGlobals.beforeEach
local expect = JestGlobals.expect
local test = JestGlobals.test

local function createRoactStory(element)
	return createStory(element, {
		Roact = Roact,
	})
end

local function ButtonStory(props: {
	controls: {
		isDisabled: boolean?,
	},
})
	return Roact.createElement("TextButton", {
		Text = if props.controls.isDisabled then "Disabled" else "Enabled",
	})
end

local ButtonStoryClassComponent = Roact.Component:extend("ButtonStoryClassComponent")

function ButtonStoryClassComponent:render()
	return Roact.createElement("TextButton", {
		Text = if self.props.controls.isDisabled then "Disabled" else "Enabled",
	})
end

local container

beforeEach(function()
	container = Instance.new("Folder")
end)

test("render a functional componnet", function()
	local story = createRoactStory(ButtonStory)

	render(container, story)

	local element = container:GetChildren()[1]

	assert(element, "no element found")
	expect(typeof(element)).toBe("Instance")
	assert(element:IsA("TextButton"), "not a TextButton")
	expect(element.Text).toBe("Enabled")
end)

test("render a class component", function()
	render(container, createRoactStory(ButtonStoryClassComponent))

	local element = container:GetChildren()[1]

	assert(element, "no element found")
	expect(typeof(element)).toBe("Instance")
	assert(element:IsA("TextButton"), "not a TextButton")
	expect(element.Text).toBe("Enabled")
end)

test("pass controls as props", function()
	local story = createRoactStory(ButtonStory)
	story.controls = {
		isDisabled = true,
	}

	render(container, story)

	local button = container:FindFirstChildWhichIsA("TextButton")

	assert(button, "no TextButton found")
	expect(button.Text).toBe("Disabled")
end)

test("update the component on arg changes", function()
	local story = createRoactStory(ButtonStory)
	story.controls = {
		isDisabled = true,
	}

	local lifecycle = render(container, story)

	local button = container:FindFirstChildWhichIsA("TextButton")

	assert(button, "no TextButton found")
	expect(button.Text).toBe("Disabled")

	lifecycle.update({
		isDisabled = false,
	})

	expect(button.Text).toBe("Enabled")
end)

test("render a pre-created Roact element", function()
	local function TextLabelStory()
		return Roact.createElement("TextLabel", {
			Text = "Hello, World",
		})
	end
	local story = createRoactStory(Roact.createElement(TextLabelStory))

	render(container, story)

	local element = container:FindFirstChildOfClass("TextLabel")
	assert(element, "no element found")
	expect(element.Text).toBe("Hello, World")
end)

test("renders primitives", function()
	local story = createRoactStory(Roact.createElement("TextLabel", {
		Text = "Hello, World",
	}))

	render(container, story)

	local label = container:FindFirstChildWhichIsA("TextLabel")
	assert(label, "no TextLabel found")
	expect(label.Text).toBe("Hello, World")
end)

test("lifecycle", function()
	expect(#container:GetChildren()).toBe(0)

	local story = createRoactStory(ButtonStory)
	story.controls = {
		isDisabled = false,
	}

	local lifecycle = render(container, story)

	expect(#container:GetChildren()).toBe(1)

	local element = container:FindFirstChildWhichIsA("TextButton")
	assert(element, "no TextButton found")
	expect(element.Text).toBe("Enabled")

	lifecycle.update({
		isDisabled = true,
	})

	expect(#container:GetChildren()).toBe(1)

	local prevElement = element
	element = container:FindFirstChildWhichIsA("TextButton")
	assert(element, "no TextButton found")
	expect(element).toBe(prevElement)
	expect(element.Text).toBe("Disabled")

	lifecycle.unmount()

	expect(#container:GetChildren()).toBe(0)
end)
