local JestGlobals = require("@pkg/JestGlobals")
local Roact = require("@pkg/Roact")
local createRoactRenderer = require("./createRoactRenderer")
local createStory = require("@root/test-utils/createStory")
local render = require("@root/render")

local beforeEach = JestGlobals.beforeEach
local expect = JestGlobals.expect
local test = JestGlobals.test

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
local renderer

beforeEach(function()
	container = Instance.new("Folder")

	renderer = createRoactRenderer({
		Roact = Roact,
	})
end)

test("render a functional componnet", function()
	local story = createStory(ButtonStory)

	render(renderer, container, story)

	local element = container:GetChildren()[1]

	assert(element, "no element found")
	expect(typeof(element)).toBe("Instance")
	assert(element:IsA("TextButton"), "not a TextButton")
	expect(element.Text).toBe("Enabled")
end)

test("render a class component", function()
	render(renderer, container, createStory(ButtonStoryClassComponent))

	local element = container:GetChildren()[1]

	assert(element, "no element found")
	expect(typeof(element)).toBe("Instance")
	assert(element:IsA("TextButton"), "not a TextButton")
	expect(element.Text).toBe("Enabled")
end)

test("pass controls as props", function()
	local story = createStory(ButtonStory)

	render(renderer, container, story, {
		isDisabled = true,
	})

	local button = container:FindFirstChildWhichIsA("TextButton")

	assert(button, "no TextButton found")
	expect(button.Text).toBe("Disabled")
end)

test("update the component on arg changes", function()
	local story = createStory(ButtonStory)

	local lifecycle = render(renderer, container, story, {
		isDisabled = true,
	})

	local button = container:FindFirstChildWhichIsA("TextButton")

	assert(button, "no TextButton found")
	expect(button.Text).toBe("Disabled")

	lifecycle.update({
		isDisabled = false,
	})

	expect(button.Text).toBe("Enabled")
end)

test("lifecycle", function()
	expect(#container:GetChildren()).toBe(0)

	local story = createStory(ButtonStory)

	local lifecycle = render(renderer, container, story, {
		isDisabled = false,
	})

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
