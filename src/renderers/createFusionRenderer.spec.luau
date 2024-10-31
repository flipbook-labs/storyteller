local Fusion = require("@pkg/Fusion")
local JestGlobals = require("@pkg/JestGlobals")

local createFusionRenderer = require("./createFusionRenderer")
local createStory = require("@root/test-utils/createStory")
local render = require("@root/render")

local beforeEach = JestGlobals.beforeEach
local expect = JestGlobals.expect
local test = JestGlobals.test

local New = Fusion.New
type StateObject<T> = Fusion.StateObject<T>

local function ButtonStory(props: {
	controls: {
		isDisabled: StateObject<boolean>,
	},
})
	return New("TextButton")({
		Text = if props.controls.isDisabled and props.controls.isDisabled:get() then "Disabled" else "Enabled",
	})
end

local container
local renderer

beforeEach(function()
	container = Instance.new("Folder")

	renderer = createFusionRenderer({
		Fusion = Fusion,
	})
end)

test("render a Fusion component", function()
	local story = createStory(ButtonStory)
	render(renderer, container, story)
	expect(container:FindFirstChildWhichIsA("TextButton")).toBeDefined()
end)

test("unmount a Fusion component", function()
	local story = createStory(ButtonStory)
	local lifecycle = render(renderer, container, story)

	expect(#container:GetChildren()).toBe(1)

	lifecycle.unmount()

	expect(#container:GetChildren()).toBe(0)
end)

test("controls are transformed into Values", function()
	local story = createStory(ButtonStory)
	story.controls = {
		isDisabled = true,
	}

	render(renderer, container, story)

	local element = container:FindFirstChildWhichIsA("TextButton")
	assert(element, "no element found")
	expect(element.Text).toBe("Disabled")
end)

test("update the component on arg changes", function()
	expect(#container:GetChildren()).toBe(0)

	local story = createStory(ButtonStory)
	story.controls = {
		isDisabled = true,
	}

	local lifecycle = render(renderer, container, story)

	expect(#container:GetChildren()).toBe(1)

	local element = container:FindFirstChildWhichIsA("TextButton")
	assert(element, "no element found")
	expect(element.Text).toBe("Disabled")

	lifecycle.update({
		isDisabled = false,
	})

	expect(#container:GetChildren()).toBe(1)
	expect(element.Text).toBe("Enabled")
end)
