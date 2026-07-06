local JestGlobals = require("@pkg/JestGlobals")
local Vide = require("@pkg/Vide")

local ControlTypes = require("@root/controls/ControlTypes")
local createStory = require("@root/test-utils/createStory")
local render = require("@root/render")

local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

type StoryControlsSchema = ControlTypes.StoryControlsSchema
type StoryControls = ControlTypes.StoryControls

local container
beforeEach(function()
	container = Instance.new("Folder")
end)

describe("Vide", function()
	local function TextStory()
		return Vide.create("TextLabel")({
			Text = "Hello, world!",
		})
	end

	type Props = {
		controls: {
			isDisabled: () -> boolean,
		},
	}

	local function ButtonStory(props: Props)
		return Vide.create("TextButton")({
			Text = function()
				return if props.controls.isDisabled() then "Disabled" else "Enabled"
			end,
		})
	end

	local function createVideStory(component)
		return createStory({
			story = component,
			packages = { Vide = Vide },
		})
	end

	test("render a Vide component", function()
		local story = createVideStory(TextStory)

		render(container, story)

		expect(#container:GetChildren()).toBe(1)
		expect(container:FindFirstChildWhichIsA("TextLabel")).toBeDefined()
	end)

	test("unmount a Vide component", function()
		local story = createVideStory(TextStory)
		local lifecycle = render(container, story)

		expect(#container:GetChildren()).toBe(1)

		lifecycle.unmount()

		expect(#container:GetChildren()).toBe(0)
	end)

	test("controls are transformed into Sources", function()
		local story = createVideStory(ButtonStory)
		story.controls = { isDisabled = true } :: StoryControlsSchema

		render(container, story)

		local element = container:FindFirstChildWhichIsA("TextButton")
		assert(element, "no element found")
		expect(element.Text).toBe("Disabled")
	end)

	test("update the component on arg changes", function()
		expect(#container:GetChildren()).toBe(0)

		local story = createVideStory(ButtonStory)
		story.controls = { isDisabled = true } :: StoryControlsSchema

		local lifecycle = render(container, story)

		expect(#container:GetChildren()).toBe(1)

		local element = container:FindFirstChildWhichIsA("TextButton")
		assert(element, "no element found")
		expect(element.Text).toBe("Disabled")

		lifecycle.update({ isDisabled = false } :: StoryControls)

		expect(#container:GetChildren()).toBe(1)

		local prevElement = element
		element = container:FindFirstChildWhichIsA("TextButton")
		expect(element).toBe(prevElement)

		task.wait()

		expect(element.Text).toBe("Enabled")
	end)

	test("unmounting destroys the reactive scope", function()
		local cleaned = false

		local story = createVideStory(function()
			Vide.cleanup(function()
				cleaned = true
			end)

			return Vide.create("TextLabel")({
				Text = "Hello, world!",
			})
		end)

		local lifecycle = render(container, story)

		expect(cleaned).toBe(false)

		lifecycle.unmount()

		-- Stories rely on their `Vide.cleanup` callbacks running when the
		-- story is closed, so unmounting must destroy the reactive scope
		-- rather than only clearing the container
		expect(cleaned).toBe(true)
	end)

	test("mount and unmount a story that is an Instance", function()
		local instance = Vide.create("TextLabel")({
			Text = "Static",
		})
		local story = createVideStory(instance)

		local lifecycle = render(container, story)

		expect(#container:GetChildren()).toBe(1)
		expect(instance.Parent).toBe(container)

		lifecycle.unmount()

		expect(#container:GetChildren()).toBe(0)
		expect(instance.Parent).toBeNil()
	end)

	test("errors thrown by the story propagate out of render", function()
		local story = createVideStory(function()
			error("vide story blew up")
		end)

		expect(function()
			render(container, story)
		end).toThrow("vide story blew up")

		expect(#container:GetChildren()).toBe(0)
	end)

	test("mapStory middleware wraps the story", function()
		local story = createVideStory(TextStory)

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
end)
