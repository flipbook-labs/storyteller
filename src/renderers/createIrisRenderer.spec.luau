local Iris = require("@pkg/Iris")
local JestGlobals = require("@pkg/JestGlobals")

local ControlTypes = require("@root/controls/ControlTypes")
local createStory = require("@root/test-utils/createStory")
local render = require("@root/render")
local waitFor = require("@root/test-utils/waitFor")

local beforeEach = JestGlobals.beforeEach
local expect = JestGlobals.expect
local test = JestGlobals.test

type StoryControls = ControlTypes.StoryControls
type StoryControlsSchema = ControlTypes.StoryControlsSchema

local container

beforeEach(function()
	container = Instance.new("Folder")
end)

local function createIrisStory(story)
	return createStory({
		story = story,
		packages = {
			Iris = Iris,
		},
	})
end

local function findTextLabelWithText(root: Instance, text: string): TextLabel?
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("TextLabel") and descendant.Text == text then
			return descendant
		end
	end
	return nil
end

test("render an Iris component", function()
	local story = createIrisStory(function()
		Iris.Window({ "My Window" })
		Iris.Text({ "Hello, World" })
		Iris.End()
	end)

	local lifecycle = render(container, story)

	-- Iris renders on its next cycle, so wait a frame before asserting.
	task.wait()

	expect(#container:GetChildren()).toBe(1)

	local wrapper = container:FindFirstChildWhichIsA("Frame")
	assert(wrapper, "no wrapper Frame was created")

	-- The first Iris cycle can take a couple of frames to draw widgets, so
	-- poll rather than waiting a fixed number of frames
	waitFor(function()
		expect(findTextLabelWithText(wrapper, "Hello, World")).toBeDefined()
	end)

	lifecycle.unmount()
end)

test("unmount an Iris component", function()
	local story = createIrisStory(function()
		Iris.Window({ "My Window" })
		Iris.End()
	end)

	local lifecycle = render(container, story)

	task.wait()

	expect(#container:GetChildren()).toBe(1)

	lifecycle.unmount()

	expect(#container:GetChildren()).toBe(0)
end)

test("a story can mount after a previous story unmounted", function()
	local firstStory = createIrisStory(function()
		Iris.Window({ "First Window" })
		Iris.Text({ "First" })
		Iris.End()
	end)

	local firstLifecycle = render(container, firstStory)

	task.wait()

	firstLifecycle.unmount()

	-- Iris is a global singleton that can only be initialized once, so a
	-- second mount must re-point the existing instance at the new container
	local secondContainer = Instance.new("Folder")
	local secondStory = createIrisStory(function()
		Iris.Window({ "Second Window" })
		Iris.Text({ "Second" })
		Iris.End()
	end)

	local secondLifecycle = render(secondContainer, secondStory)

	task.wait()

	local wrapper = secondContainer:FindFirstChildWhichIsA("Frame")
	assert(wrapper, "no wrapper Frame was created on the second mount")

	waitFor(function()
		expect(findTextLabelWithText(wrapper, "Second")).toBeDefined()
	end)

	-- The first story was unmounted, so its widgets must not leak into the
	-- second story's render
	expect(findTextLabelWithText(wrapper, "First")).toBeNil()

	secondLifecycle.unmount()

	expect(#secondContainer:GetChildren()).toBe(0)
end)

test("mapStory middleware wraps the story", function()
	local story = createIrisStory(function()
		Iris.Window({ "My Window" })
		Iris.Text({ "FromStory" })
		Iris.End()
	end)

	story.storybook.mapStory = function(originalStory)
		return function(props)
			originalStory(props)

			Iris.Window({ "Middleware Window" })
			Iris.Text({ "FromMiddleware" })
			Iris.End()

			return nil
		end
	end

	local lifecycle = render(container, story)

	local wrapper = container:FindFirstChildWhichIsA("Frame")
	assert(wrapper, "no wrapper Frame was created")

	waitFor(function()
		expect(findTextLabelWithText(wrapper, "FromStory")).toBeDefined()
		expect(findTextLabelWithText(wrapper, "FromMiddleware")).toBeDefined()
	end)

	lifecycle.unmount()
end)

test("mapStory continues to wrap the story on updates", function()
	local story = createIrisStory(function(props)
		Iris.Window({ "My Window" })
		Iris.Text({ props.controls.value })
		Iris.End()
	end)

	story.controls = {
		value = "First",
	} :: StoryControlsSchema

	story.storybook.mapStory = function(originalStory)
		return function(props)
			originalStory(props)

			Iris.Window({ "Middleware Window" })
			Iris.Text({ "FromMiddleware" })
			Iris.End()

			return nil
		end
	end

	local lifecycle = render(container, story)

	local wrapper = container:FindFirstChildWhichIsA("Frame")
	assert(wrapper, "no wrapper Frame was created")

	waitFor(function()
		expect(findTextLabelWithText(wrapper, "First")).toBeDefined()
		expect(findTextLabelWithText(wrapper, "FromMiddleware")).toBeDefined()
	end)

	lifecycle.update({
		value = "Second",
	} :: StoryControls)

	-- The middleware wraps the story once at mount, but immediate-mode reads
	-- controls every frame, so the wrapper must keep applying as controls change
	waitFor(function()
		expect(findTextLabelWithText(wrapper, "Second")).toBeDefined()
		expect(findTextLabelWithText(wrapper, "FromMiddleware")).toBeDefined()
	end)

	lifecycle.unmount()
end)

test("update passes new controls to the story", function()
	local rendered = {}

	local story = createIrisStory(function(props)
		rendered.value = props.controls.value
		Iris.Window({ "My Window" })
		Iris.End()
	end)

	story.controls = {
		value = "initial",
	} :: StoryControlsSchema

	local lifecycle = render(container, story)

	task.wait()

	expect(rendered.value).toBe("initial")

	lifecycle.update({
		value = "updated",
	} :: StoryControls)

	task.wait()

	expect(rendered.value).toBe("updated")

	lifecycle.unmount()
end)

test("mapDefinition is applied exactly once, at mount", function()
	local applications = 0
	local rendered = {}

	local story = createIrisStory(function(props)
		rendered.value = props.controls.value
		Iris.Window({ "My Window" })
		Iris.Text({ props.controls.value })
		Iris.End()
	end)

	story.controls = {
		value = "initial",
	} :: StoryControlsSchema

	story.storybook.mapDefinition = function(storyDefinition)
		applications += 1
		return table.clone(storyDefinition)
	end

	local lifecycle = render(container, story)

	task.wait()

	expect(applications).toBe(1)
	expect(rendered.value).toBe("initial")

	lifecycle.update({
		value = "updated",
	} :: StoryControls)

	task.wait()

	-- Immediate-mode reads props every frame, so the update must re-render the
	-- already-mapped story rather than re-applying the definition
	expect(applications).toBe(1)
	expect(rendered.value).toBe("updated")

	lifecycle.unmount()
end)

test("mapDefinition can replace the story's component", function()
	local story = createIrisStory(function()
		Iris.Window({ "My Window" })
		Iris.Text({ "Original" })
		Iris.End()
	end)

	story.storybook.mapDefinition = function(storyDefinition)
		local mapped = table.clone(storyDefinition)
		mapped.story = function()
			Iris.Window({ "Replaced Window" })
			Iris.Text({ "Replaced" })
			Iris.End()
		end
		return mapped
	end

	local lifecycle = render(container, story)

	local wrapper = container:FindFirstChildWhichIsA("Frame")
	assert(wrapper, "no wrapper Frame was created")

	waitFor(function()
		expect(findTextLabelWithText(wrapper, "Replaced")).toBeDefined()
	end)

	-- The original definition's widgets must not leak through once it's replaced
	expect(findTextLabelWithText(wrapper, "Original")).toBeNil()

	lifecycle.unmount()
end)
