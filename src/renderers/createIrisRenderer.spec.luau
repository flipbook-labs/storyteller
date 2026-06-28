local Iris = require("@pkg/Iris")
local JestGlobals = require("@pkg/JestGlobals")

local ControlTypes = require("@root/controls/ControlTypes")
local createStory = require("@root/test-utils/createStory")
local render = require("@root/render")

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

test("render an Iris component", function()
	local story = createIrisStory(function()
		Iris.Window({ "My Window" })
		Iris.Text({ "Hello, World" })
		Iris.End()
	end)

	render(container, story)

	-- Iris renders on its next cycle, so wait a frame before asserting.
	task.wait()

	expect(#container:GetChildren()).toBe(1)

	local wrapper = container:FindFirstChildWhichIsA("Frame")
	assert(wrapper, "no wrapper Frame was created")
	expect(#wrapper:GetDescendants() > 0).toBe(true)
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
end)
