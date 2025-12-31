local JestGlobals = require("@pkg/JestGlobals")
local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")

local controls = require("@root/controls")
local createStory = require("@root/test-utils/createStory")
local render = require("@root/render")

local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local act = ReactRoblox.act

type StoryControls = controls.StoryControls

local function createReactStory(element)
	return createStory({
		story = element,
		packages = {
			React = React,
			ReactRoblox = ReactRoblox,
		},
	})
end

local function ButtonStory(props: {
	controls: {
		isDisabled: boolean?,
	},
})
	return React.createElement("TextButton", {
		Text = if props.controls.isDisabled then "Disabled" else "Enabled",
	})
end

local ButtonStoryClassComponent = React.Component:extend("ButtonStoryClassComponent")

function ButtonStoryClassComponent:render()
	return React.createElement("TextButton", {
		Text = if self.props.controls.isDisabled then "Disabled" else "Enabled",
	})
end

local container

beforeEach(function()
	container = Instance.new("Folder")
end)

test("render a functional componnet", function()
	local story = createReactStory(ButtonStory)
	render(container, story)

	act(function()
		task.wait()
	end)

	local element = container:GetChildren()[1]

	assert(element, "no element found")
	expect(typeof(element)).toBe("Instance")
	assert(element:IsA("TextButton"), "not a TextButton")
	expect(element.Text).toBe("Enabled")
end)

test("render a class component", function()
	render(container, createReactStory(ButtonStoryClassComponent))

	act(function()
		task.wait()
	end)

	local element = container:GetChildren()[1]

	assert(element, "no element found")
	expect(typeof(element)).toBe("Instance")
	assert(element:IsA("TextButton"), "not a TextButton")
	expect(element.Text).toBe("Enabled")
end)

test("render an element", function()
	local story = createReactStory(React.createElement(ButtonStory, {
		controls = {
			isDisabled = true,
		},
	}))

	render(container, story)

	act(function()
		task.wait()
	end)

	local button = container:FindFirstChildWhichIsA("TextButton")
	assert(button, "no TextButton found")
	expect(button.Text).toBe("Disabled")
end)

test("pass controls as props", function()
	local story = createReactStory(ButtonStory)
	local controls: StoryControls = {
		isDisabled = true,
	}

	story.controls = controls

	render(container, story)

	act(function()
		task.wait()
	end)

	local button = container:FindFirstChildWhichIsA("TextButton")
	assert(button, "no TextButton found")
	expect(button.Text).toBe("Disabled")
end)

test("update the component on arg changes", function()
	local story = createReactStory(ButtonStory)
	local controls: StoryControls = {
		isDisabled = true,
	}

	story.controls = controls

	local lifecycle = render(container, story)

	act(function()
		task.wait()
	end)

	local button = container:FindFirstChildWhichIsA("TextButton")
	assert(button, "no TextButton found")
	expect(button.Text).toBe("Disabled")

	lifecycle.update({
		isDisabled = false,
	} :: StoryControls)

	act(function()
		task.wait()
	end)

	expect(button.Text).toBe("Enabled")
end)

test("renders primitives", function()
	local story = createReactStory(React.createElement("TextLabel", {
		Text = "Hello, World",
	}))

	render(container, story)

	act(function()
		task.wait()
	end)

	local label = container:FindFirstChildWhichIsA("TextLabel")
	assert(label, "no TextLabel found")
	expect(label.Text).toBe("Hello, World")
end)

test("lifecycle", function()
	expect(#container:GetChildren()).toBe(0)

	local story = createReactStory(ButtonStory)
	local controls: StoryControls = {
		isDisabled = false,
	}

	story.controls = controls

	local lifecycle = render(container, story)

	act(function()
		task.wait()
	end)

	expect(#container:GetChildren()).toBe(1)

	local element = container:FindFirstChildWhichIsA("TextButton")
	assert(element, "no TextButton found")
	expect(element.Text).toBe("Enabled")

	lifecycle.update({
		isDisabled = true,
	} :: StoryControls)

	act(function()
		task.wait()
	end)

	expect(#container:GetChildren()).toBe(1)

	local prevElement = element
	element = container:FindFirstChildWhichIsA("TextButton")
	assert(element, "no TextButton found")
	expect(element).toBe(prevElement)
	expect(element.Text).toBe("Disabled")

	lifecycle.unmount()

	act(function()
		task.wait()
	end)

	expect(#container:GetChildren()).toBe(0)
end)

describe("middleware", function()
	test("supply context provider to all stories", function()
		local ThemeContext = React.createContext(nil)

		local function StoryThatNeedsContext()
			local theme = React.useContext(ThemeContext)

			return React.createElement("TextLabel", {
				Text = if theme == "Dark" then "Dark" else "Light",
			})
		end

		local story = createReactStory(StoryThatNeedsContext)

		story.storybook.mapStory = function(element)
			return function(props)
				return React.createElement(ThemeContext.Provider, {
					value = "Dark",
				}, React.createElement(element, props))
			end
		end

		render(container, story)

		act(function()
			task.wait()
		end)

		local element = container:FindFirstChildWhichIsA("TextLabel")
		assert(element, "no TextLabel found")
		expect(element.Text).toBe("Dark")
	end)
end)
