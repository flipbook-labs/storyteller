local JestGlobals = require("@pkg/JestGlobals")
local Vide = require("@pkg/Vide")

local ControlTypes = require("@root/controls/ControlTypes")
local createStory = require("@root/test-utils/createStory")
local render = require("@root/render")
local types = require("@root/types")

local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

type StoryControlsSchema = ControlTypes.StoryControlsSchema
type StoryControls = ControlTypes.StoryControls
type LoadedStory<T> = types.LoadedStory<T>
type StoryProps = types.StoryProps

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

	test("mapStory middleware wraps the story", function()
		local story = createVideStory(TextStory)

		story.storybook.mapStory = function(originalStory)
			local storyFn = originalStory :: (StoryProps) -> Instance
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

		local story = createVideStory(ButtonStory)
		story.controls = { isDisabled = true } :: StoryControlsSchema

		story.storybook.mapDefinition = function(storyDefinition)
			applications += 1
			return table.clone(storyDefinition :: LoadedStory<unknown>)
		end

		local lifecycle = render(container, story)

		expect(applications).toBe(1)

		local button = container:FindFirstChildWhichIsA("TextButton")
		assert(button, "no element found")
		expect(button.Text).toBe("Disabled")

		lifecycle.update({ isDisabled = false } :: StoryControls)

		task.wait()

		expect(applications).toBe(1)
		expect(button.Text).toBe("Enabled")
	end)

	test("mapDefinition can replace the story's component", function()
		local story = createVideStory(TextStory)

		story.storybook.mapDefinition = function(storyDefinition)
			local mapped = table.clone(storyDefinition :: LoadedStory<unknown>)
			mapped.story = function()
				return Vide.create("TextLabel")({
					Text = "Replaced",
				})
			end
			return mapped
		end

		render(container, story)

		local label = container:FindFirstChildWhichIsA("TextLabel")
		assert(label, "no TextLabel found")
		expect(label.Text).toBe("Replaced")
	end)
end)
