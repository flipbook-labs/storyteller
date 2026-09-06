local Fusion2 = require("@pkg/Fusion")
local Fusion3 = require("@pkg/Fusion3")
local JestGlobals = require("@pkg/JestGlobals")

local ControlTypes = require("@root/controls/ControlTypes")
local createStory = require("@root/test-utils/createStory")
local render = require("@root/render")
local types = require("@root/types")

local beforeEach = JestGlobals.beforeEach
local expect = JestGlobals.expect
local test = JestGlobals.test
local describe = JestGlobals.describe

type StoryControlsSchema = ControlTypes.StoryControlsSchema
type StoryControls = ControlTypes.StoryControls
type LoadedStory<T> = types.LoadedStory<T>
type StoryProps = types.StoryProps

local container

beforeEach(function()
	container = Instance.new("Folder")
end)

describe("Fusion 0.3.0", function()
	local scope = Fusion3:scoped()

	type StateObject<T> = Fusion3.StateObject<T>

	local function TextStory()
		return scope:New("TextLabel")({
			Text = "Hello World",
		})
	end

	local function ButtonStory(props: {
		controls: {
			isDisabled: Fusion3.StateObject<boolean>,
		},
	})
		local text = scope:Computed(function(use)
			return if use(props.controls.isDisabled) then "Disabled" else "Enabled"
		end)

		return scope:New("TextButton")({
			Text = text,
		})
	end

	local function createFusionStory(element)
		return createStory({
			story = element,
			packages = {
				Fusion = Fusion3,
			},
		})
	end

	test("render a Fusion component", function()
		local story = createFusionStory(TextStory)

		render(container, story)

		expect(#container:GetChildren()).toBe(1)
		expect(container:FindFirstChildWhichIsA("TextLabel")).toBeDefined()
	end)

	test("unmount a Fusion component", function()
		local story = createStory({
			story = TextStory,
		})
		local lifecycle = render(container, story)

		expect(#container:GetChildren()).toBe(1)

		lifecycle.unmount()

		expect(#container:GetChildren()).toBe(0)
	end)

	test("controls are transformed into Values", function()
		local story = createFusionStory(ButtonStory)

		story.controls = {
			isDisabled = true,
		} :: StoryControlsSchema

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
		} :: StoryControlsSchema

		local lifecycle = render(container, story)

		expect(#container:GetChildren()).toBe(1)

		local element = container:FindFirstChildWhichIsA("TextButton")
		assert(element, "no element found")
		expect(element.Text).toBe("Disabled")

		lifecycle.update({
			isDisabled = false,
		} :: StoryControls)

		expect(#container:GetChildren()).toBe(1)

		local prevElement = element
		element = container:FindFirstChildWhichIsA("TextButton")
		expect(element).toBe(prevElement)

		task.wait()

		expect(element.Text).toBe("Enabled")
	end)

	test("mapStory middleware wraps the story", function()
		local story = createFusionStory(ButtonStory)

		story.controls = {
			isDisabled = true,
		} :: StoryControlsSchema

		story.storybook.mapStory = function(originalStory)
			local storyFn = originalStory :: (StoryProps) -> Instance
			return function(props)
				local instance = storyFn(props)
				instance.Name = "Mapped"
				return instance
			end
		end

		local lifecycle = render(container, story)

		local mapped = container:FindFirstChild("Mapped")
		assert(mapped, "no mapped element found")
		assert(mapped:IsA("TextButton"), "mapped element is not the story's TextButton")
		expect(mapped.Text).toBe("Disabled")

		-- Controls must keep working through the middleware
		lifecycle.update({
			isDisabled = false,
		} :: StoryControls)

		task.wait()

		expect(mapped.Text).toBe("Enabled")
	end)

	test("mapDefinition is applied exactly once, at mount", function()
		local applications = 0

		local story = createFusionStory(ButtonStory)

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

		task.wait()

		expect(applications).toBe(1)
		expect(button.Text).toBe("Enabled")
	end)

	test("mapDefinition can replace the story's component", function()
		local story = createFusionStory(TextStory)

		story.storybook.mapDefinition = function(storyDefinition)
			local mapped = table.clone(storyDefinition :: LoadedStory<unknown>)
			mapped.story = function()
				return scope:New("TextLabel")({
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

describe("Fusion 0.2.0", function()
	local New = Fusion2.New
	local Computed = Fusion2.Computed
	type StateObject<T> = Fusion2.StateObject<T>

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
		return createStory({
			story = element,
			packages = {
				Fusion = Fusion2,
			},
		})
	end

	test("render a Fusion component", function()
		local story = createFusionStory(TextStory)

		render(container, story)

		expect(#container:GetChildren()).toBe(1)
		expect(container:FindFirstChildWhichIsA("TextLabel")).toBeDefined()
	end)

	test("unmount a Fusion component", function()
		local story = createStory({
			story = TextStory,
		})
		local lifecycle = render(container, story)

		expect(#container:GetChildren()).toBe(1)

		lifecycle.unmount()

		expect(#container:GetChildren()).toBe(0)
	end)

	test("controls are transformed into Values", function()
		local story = createFusionStory(ButtonStory)

		story.controls = {
			isDisabled = true,
		} :: StoryControlsSchema

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
		} :: StoryControlsSchema

		local lifecycle = render(container, story)

		expect(#container:GetChildren()).toBe(1)

		local element = container:FindFirstChildWhichIsA("TextButton")
		assert(element, "no element found")
		expect(element.Text).toBe("Disabled")

		lifecycle.update({
			isDisabled = false,
		} :: StoryControls)

		expect(#container:GetChildren()).toBe(1)

		local prevElement = element
		element = container:FindFirstChildWhichIsA("TextButton")
		expect(element).toBe(prevElement)

		task.wait()

		expect(element.Text).toBe("Enabled")
	end)

	test("mapStory middleware wraps the story", function()
		local story = createFusionStory(TextStory)

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

		local story = createFusionStory(ButtonStory)

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

		task.wait()

		expect(applications).toBe(1)
		expect(button.Text).toBe("Enabled")
	end)

	test("mapDefinition can replace the story's component", function()
		local story = createFusionStory(TextStory)

		story.storybook.mapDefinition = function(storyDefinition)
			local mapped = table.clone(storyDefinition :: LoadedStory<unknown>)
			mapped.story = function()
				return New("TextLabel")({
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
