local Fusion = require("@pkg/Fusion")
local JestGlobals = require("@pkg/JestGlobals")

local createStory = require("@root/test-utils/createStory")
local render = require("@root/render")

local beforeEach = JestGlobals.beforeEach
local expect = JestGlobals.expect
local test = JestGlobals.test

local New = Fusion.New
local Computed = Fusion.Computed
type StateObject<T> = Fusion.StateObject<T>

local function TextStory()
	return New("TextLabel")({
		Text = "Hello World",
	})
end

local function ButtonStory(props: {
	controls: {
		isDisabled: StateObject<boolean>,
	},
})
	return New("TextButton")({
		Text = Computed(function()
			return if props.controls.isDisabled:get() then "Disabled" else "Enabled"
		end),
	})
end

local function createFusionStory(element)
	return createStory(element, {
		Fusion = Fusion,
	})
end

local container

beforeEach(function()
	container = Instance.new("Folder")
end)

test("render a Fusion component", function()
	local story = createFusionStory(TextStory)

	render(container, story)

	expect(#container:GetChildren()).toBe(1)
	expect(container:FindFirstChildWhichIsA("TextLabel")).toBeDefined()
end)

test("unmount a Fusion component", function()
	local story = createStory(TextStory)
	local lifecycle = render(container, story)

	expect(#container:GetChildren()).toBe(1)

	lifecycle.unmount()

	expect(#container:GetChildren()).toBe(0)
end)

test("controls are transformed into Values", function()
	local story = createFusionStory(ButtonStory)
	story.controls = {
		isDisabled = true,
	}

	render(container, story)

	local element = container:FindFirstChildWhichIsA("TextButton")
	assert(element, "no element found")
	expect(element.Text).toBe("Disabled")
end)

test("update the component on arg changes", function()
	expect(#container:GetChildren()).toBe(0)

	local story = createFusionStory(ButtonStory)
	story.controls = {
		isDisabled = true,
	}

	local lifecycle = render(container, story)

	expect(#container:GetChildren()).toBe(1)

	local element = container:FindFirstChildWhichIsA("TextButton")
	assert(element, "no element found")
	expect(element.Text).toBe("Disabled")

	lifecycle.update({
		isDisabled = false,
	})

	expect(#container:GetChildren()).toBe(1)

	local prevElement = element
	element = container:FindFirstChildWhichIsA("TextButton")
	expect(element).toBe(prevElement)

	task.wait()

	expect(element.Text).toBe("Enabled")
end)
