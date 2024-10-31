local JestGlobals = require("@pkg/JestGlobals")

local createManualRenderer = require("./createManualRenderer")
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
	local button = Instance.new("TextButton")
	button.Text = if props.controls.isDisabled then "Disabled" else "Enabled"

	return button
end

local container
local renderer

beforeEach(function()
	container = Instance.new("Folder")
	renderer = createManualRenderer()
end)

test("mounts and unmounts an Instance", function()
	local story = createStory(function()
		local label = Instance.new("TextLabel")
		return label
	end)

	local lifecycle = render(renderer, container, story)

	expect(#container:GetChildren()).toBe(1)

	lifecycle.unmount()

	expect(#container:GetChildren()).toBe(0)
end)

test("mounts and unmounts an Instance via cleanup function", function()
	local story = createStory(function(props)
		local label = Instance.new("TextLabel")

		label.Parent = props.container

		return function()
			label:Destroy()
		end
	end)

	local lifecycle = render(renderer, container, story)

	expect(#container:GetChildren()).toBe(1)

	lifecycle.unmount()

	expect(#container:GetChildren()).toBe(0)
end)

test("mounts and unmounts an Instance implicitly", function()
	local story = createStory(function(props)
		local label = Instance.new("TextLabel")
		label.Parent = props.container
	end)

	local lifecycle = render(renderer, container, story)

	expect(#container:GetChildren()).toBe(1)

	lifecycle.unmount()

	expect(#container:GetChildren()).toBe(0)
end)

test("render a GuiObject with args", function()
	local story = createStory(ButtonStory)
	story.controls = {
		isDisabled = true,
	}

	render(renderer, container, story)

	local element = container:FindFirstChildWhichIsA("TextButton")
	assert(element, "no element found")
	expect(element.Text).toBe("Disabled")
end)

test("update the GuiObject on arg changes", function()
	local story = createStory(ButtonStory)
	story.controls = {
		isDisabled = true,
	}

	local lifecycle = render(renderer, container, story)

	local button = container:FindFirstChildWhichIsA("TextButton")

	assert(button, "no TextButton found")
	expect(button.Text).toBe("Disabled")

	lifecycle.update({
		isDisabled = false,
	})

	button = container:FindFirstChildWhichIsA("TextButton")

	expect(button.Text).toBe("Enabled")
end)

test("lifecycle", function()
	expect(#container:GetChildren()).toBe(0)

	local story = createStory(ButtonStory)

	local lifecycle = render(renderer, container, story)

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
	expect(element).never.toBe(prevElement)
	expect(element.Text).toBe("Disabled")

	lifecycle.unmount()

	expect(#container:GetChildren()).toBe(0)
end)
