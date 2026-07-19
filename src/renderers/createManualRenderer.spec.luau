local JestGlobals = require("@pkg/JestGlobals")

local ControlTypes = require("@root/controls/ControlTypes")
local createStory = require("@root/test-utils/createStory")
local render = require("@root/render")
local types = require("@root/types")

local beforeEach = JestGlobals.beforeEach
local expect = JestGlobals.expect
local test = JestGlobals.test

type StoryControlsSchema = ControlTypes.StoryControlsSchema
type StoryControls = ControlTypes.StoryControls
type LoadedStory<T> = types.LoadedStory<T>
type StoryProps = types.StoryProps

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

test("update re-renders a story that manages its own cleanup", function()
	local cleanups = 0

	local story = createStory({
		story = function(props)
			local label = Instance.new("TextLabel")
			label.Text = if props.controls.isDisabled then "Disabled" else "Enabled"
			label.Parent = props.container

			return function()
				cleanups += 1
				label:Destroy()
			end
		end,
	})

	story.controls = {
		isDisabled = true,
	} :: StoryControlsSchema

	local lifecycle = render(container, story)

	local label = container:FindFirstChildWhichIsA("TextLabel")
	assert(label, "no TextLabel found")
	expect(label.Text).toBe("Disabled")

	lifecycle.update({
		isDisabled = false,
	} :: StoryControls)

	-- The previous render is cleaned up and a fresh one is mounted, just as a
	-- full remount would do
	expect(cleanups).toBe(1)

	label = container:FindFirstChildWhichIsA("TextLabel")
	assert(label, "no TextLabel found")
	expect(label.Text).toBe("Enabled")
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

test("mapStory middleware wraps the story", function()
	local story = createStory({
		story = function()
			return Instance.new("TextLabel")
		end,
	})

	story.storybook.mapStory = function(originalStory)
		local storyFn = originalStory :: (StoryProps) -> TextLabel
		return function(props)
			local instance = storyFn(props)
			instance.Name = "Mapped"
			return instance
		end
	end

	render(container, story)

	expect(container:FindFirstChild("Mapped")).toBeDefined()
end)

test("mapDefinition is applied exactly once, at mount", function()
	local applications = 0

	local story = createStory({
		story = ButtonStory,
	})

	story.controls = {
		isDisabled = true,
	} :: StoryControlsSchema

	story.storybook.mapDefinition = function(storyDefinition)
		applications += 1
		return table.clone(storyDefinition :: LoadedStory<unknown>)
	end

	local lifecycle = render(container, story)

	expect(applications).toBe(1)

	local button = container:FindFirstChildWhichIsA("TextButton")
	assert(button, "no TextButton found")
	expect(button.Text).toBe("Disabled")

	lifecycle.update({
		isDisabled = false,
	} :: StoryControls)

	expect(applications).toBe(1)

	button = container:FindFirstChildWhichIsA("TextButton")
	assert(button, "no TextButton found")
	expect(button.Text).toBe("Enabled")
end)

test("mapDefinition can replace the story's component", function()
	local story = createStory({
		story = function()
			return Instance.new("TextButton")
		end,
	})

	story.storybook.mapDefinition = function(storyDefinition)
		local mapped = table.clone(storyDefinition :: LoadedStory<unknown>)
		mapped.story = function()
			local label = Instance.new("TextLabel")
			label.Text = "Replaced"
			return label
		end
		return mapped
	end

	render(container, story)

	local label = container:FindFirstChildWhichIsA("TextLabel")
	assert(label, "no TextLabel found")
	expect(label.Text).toBe("Replaced")
end)
