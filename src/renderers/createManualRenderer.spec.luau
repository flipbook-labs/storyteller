local JestGlobals = require("@pkg/JestGlobals")

local ControlTypes = require("@root/controls/ControlTypes")
local createStory = require("@root/test-utils/createStory")
local render = require("@root/render")

local beforeEach = JestGlobals.beforeEach
local expect = JestGlobals.expect
local test = JestGlobals.test

type StoryControlsSchema = ControlTypes.StoryControlsSchema
type StoryControls = ControlTypes.StoryControls

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

beforeEach(function()
	container = Instance.new("Folder")
end)

test("mounts and unmounts an Instance", function()
	local story = createStory({
		story = function()
			local label = Instance.new("TextLabel")
			return label
		end,
	})

	local lifecycle = render(container, story)

	expect(#container:GetChildren()).toBe(1)

	lifecycle.unmount()

	expect(#container:GetChildren()).toBe(0)
end)

test("mounts and unmounts an Instance via cleanup function", function()
	local story = createStory({
		story = function(props)
			local label = Instance.new("TextLabel")

			label.Parent = props.container

			return function()
				label:Destroy()
			end
		end,
	})

	local lifecycle = render(container, story)

	expect(#container:GetChildren()).toBe(1)

	lifecycle.unmount()

	expect(#container:GetChildren()).toBe(0)
end)

test("mounts and unmounts an Instance implicitly", function()
	local story = createStory({
		story = function(props)
			local label = Instance.new("TextLabel")
			label.Parent = props.container
		end,
	})

	local lifecycle = render(container, story)

	expect(#container:GetChildren()).toBe(1)

	lifecycle.unmount()

	expect(#container:GetChildren()).toBe(0)
end)

test("render a GuiObject with args", function()
	local story = createStory({
		story = ButtonStory,
	})

	story.controls = {
		isDisabled = true,
	} :: StoryControlsSchema

	render(container, story)

	local element = container:FindFirstChildWhichIsA("TextButton")
	assert(element, "no element found")
	expect(element.Text).toBe("Disabled")
end)

test("update the GuiObject on arg changes", function()
	local story = createStory({
		story = ButtonStory,
	})

	story.controls = {
		isDisabled = true,
	} :: StoryControlsSchema

	local lifecycle = render(container, story)

	local button = container:FindFirstChildWhichIsA("TextButton")

	assert(button, "no TextButton found")
	expect(button.Text).toBe("Disabled")

	lifecycle.update({
		isDisabled = false,
	} :: StoryControls)

	button = container:FindFirstChildWhichIsA("TextButton")

	expect(button.Text).toBe("Enabled")
end)

test("lifecycle", function()
	expect(#container:GetChildren()).toBe(0)

	local story = createStory({
		story = ButtonStory,
	})

	story.controls = {
		isDisabled = false,
	} :: StoryControlsSchema

	local lifecycle = render(container, story)

	expect(#container:GetChildren()).toBe(1)

	local element = container:FindFirstChildWhichIsA("TextButton")
	assert(element, "no TextButton found")
	expect(element.Text).toBe("Enabled")

	lifecycle.update({
		isDisabled = true,
	} :: StoryControls)

	expect(#container:GetChildren()).toBe(1)

	local prevElement = element
	element = container:FindFirstChildWhichIsA("TextButton")
	assert(element, "no TextButton found")
	expect(element).never.toBe(prevElement)
	expect(element.Text).toBe("Disabled")

	lifecycle.unmount()

	expect(#container:GetChildren()).toBe(0)
end)

test("mounts and unmounts a story that is an Instance", function()
	local instance = Instance.new("TextLabel")
	local story = createStory({
		story = instance,
	})

	local lifecycle = render(container, story)

	expect(#container:GetChildren()).toBe(1)
	expect(instance.Parent).toBe(container)

	lifecycle.unmount()

	expect(#container:GetChildren()).toBe(0)
end)

test("a story function with two parameters receives the container first", function()
	local receivedTarget
	local receivedProps

	local story = createStory({
		story = function(target, props)
			receivedTarget = target
			receivedProps = props

			local label = Instance.new("TextLabel")
			label.Parent = target
		end,
	})

	render(container, story)

	expect(receivedTarget).toBe(container)
	expect(receivedProps).toMatchObject({
		container = container,
	})
	expect(#container:GetChildren()).toBe(1)
end)

test("the previous render is cleaned up exactly once per update", function()
	local cleanups = 0

	local story = createStory({
		story = function(props)
			local label = Instance.new("TextLabel")
			label.Parent = props.container

			return function()
				cleanups += 1
			end
		end,
	})

	story.controls = {
		isDisabled = false,
	} :: StoryControlsSchema

	local lifecycle = render(container, story)

	expect(cleanups).toBe(0)

	lifecycle.update({
		isDisabled = true,
	} :: StoryControls)

	-- The update remounts from scratch, cleaning up the previous render
	expect(cleanups).toBe(1)
	expect(#container:GetChildren()).toBe(1)

	lifecycle.unmount()

	expect(cleanups).toBe(2)
	expect(#container:GetChildren()).toBe(0)
end)

test("errors thrown by the story propagate out of render", function()
	local story = createStory({
		story = function()
			error("manual story blew up")
		end,
	})

	expect(function()
		render(container, story)
	end).toThrow("manual story blew up")

	expect(#container:GetChildren()).toBe(0)
end)

test("mapStory middleware wraps the story", function()
	local story = createStory({
		story = function()
			return Instance.new("TextLabel")
		end,
	})

	story.storybook.mapStory = function(originalStory)
		return function(props)
			local instance = originalStory(props)
			instance.Name = "Mapped"
			return instance
		end
	end

	render(container, story)

	expect(container:FindFirstChild("Mapped")).toBeDefined()
end)
