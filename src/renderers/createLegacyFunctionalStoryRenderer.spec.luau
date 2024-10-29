local JestGlobals = require("@pkg/JestGlobals")

local createLegacyFunctionalStoryRenderer = require("./createLegacyFunctionalStoryRenderer")
local createStory = require("@root/test-utils/createStory")
local render = require("@root/render")

local beforeEach = JestGlobals.beforeEach
local expect = JestGlobals.expect
local test = JestGlobals.test

local function ButtonStory(
	target: Instance,
	props: {
		controls: {
			isDisabled: boolean?,
		},
	}
)
	local button = Instance.new("TextButton")
	button.Text = if props.controls.isDisabled then "Disabled" else "Enabled"
	button.Parent = target

	return function()
		button:Destroy()
	end
end

local container
local renderer

beforeEach(function()
	container = Instance.new("Folder")
	renderer = createLegacyFunctionalStoryRenderer()
end)

test("render a GuiObject", function()
	local story = createStory(function(target)
		local label = Instance.new("TextLabel")
		label.Parent = target

		return function()
			label:Destroy()
		end
	end)

	render(renderer, container, story)

	local element = container:GetChildren()[1]

	assert(element, "no element found")
	expect(typeof(element)).toBe("Instance")
	assert(element:IsA("TextLabel"), "not a TextButton")
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
