local JestGlobals = require("@pkg/JestGlobals")
local createStory = require("@root/test-utils/createStory")
local types = require("@root/types")

local afterEach = JestGlobals.afterEach
local beforeEach = JestGlobals.beforeEach
local expect = JestGlobals.expect
local jest = JestGlobals.jest
local test = JestGlobals.test

type StoryRenderer<T> = types.StoryRenderer<T>

local container: Instance
local story: types.LoadedStory<TextLabel>
local mockCreateRendererForStory = jest.fn()
local render

beforeEach(function()
	container = Instance.new("Folder")
	story = createStory(Instance.new("TextLabel"))

	jest.mock(script.Parent.createRendererForStory, function()
		return mockCreateRendererForStory
	end)

	render = require("./render")
end)

afterEach(function()
	container:Destroy()
	jest.resetAllMocks()
end)

test("call `mount` immediately", function()
	local mockMount = jest.fn()

	mockCreateRendererForStory.mockReturnValue({
		mount = mockMount,
	})

	render(container, story)

	expect(mockMount).toHaveBeenCalledTimes(1)
end)

test("returns a function to trigger a re-render", function()
	local mockMount = jest.fn()
	mockMount.mockReturnValue = Instance.new("ScreenGui")

	mockCreateRendererForStory.mockReturnValue({
		mount = mockMount,
	})

	local lifecycle = render(container, story)

	expect(mockMount).toHaveBeenCalledTimes(1)

	lifecycle.update()

	expect(mockMount).toHaveBeenCalledTimes(2)
end)

test("current props and prev props are passed to shouldUpdate", function()
	local props, prevProps

	mockCreateRendererForStory.mockReturnValue({
		mount = function() end,
		shouldUpdate = function(_props, _prevProps)
			props = _props
			prevProps = _prevProps
			return true
		end,
	})

	local lifecycle = render(container, story)

	expect(props).toBeDefined()
	expect(prevProps).toBeNil()

	lifecycle.update()

	expect(props).toBeDefined()
	expect(prevProps).toBeDefined()
end)

test("props are passed to shouldUpdate", function()
	local props

	local controls = {
		foo = true,
	}

	story.controls = controls

	mockCreateRendererForStory.mockReturnValue({
		shouldUpdate = function(_props)
			props = _props
			return true
		end,
		mount = function() end,
	})

	render(container, story)

	expect(props).toMatchObject({
		container = container,
		controls = controls,
	})
end)

test("only rerender if shouldUpdate returns true", function()
	local mockMount = jest.fn()
	local mockShouldUpdate = jest.fn().mockReturnValue(true)

	mockCreateRendererForStory.mockReturnValue({
		shouldUpdate = mockShouldUpdate,
		mount = mockMount,
	})

	local lifecycle = render(container, story)

	expect(mockMount).toHaveBeenCalledTimes(1)

	lifecycle.update()

	expect(mockMount).toHaveBeenCalledTimes(2)

	mockShouldUpdate.mockReturnValue(false)
	lifecycle.update()

	expect(mockMount).toHaveBeenCalledTimes(2)
end)

test("destroy all children of the container when rerendering if shouldUpdate is true", function()
	local mockShouldUpdate = jest.fn().mockReturnValue(true)

	mockCreateRendererForStory.mockReturnValue({
		mount = function(otherContainer, otherStory)
			(otherStory.story :: Instance).Parent = otherContainer
		end,
		shouldUpdate = mockShouldUpdate,
	})

	local lifecycle = render(container, story)

	expect(#container:GetChildren()).toBe(1)

	lifecycle.unmount()

	expect(#container:GetChildren()).toBe(0)
end)

test("prevProps is nil on the first render", function()
	local renders = 0

	local mockShouldUpdate = jest.fn().mockImplementation(function()
		return true
	end)

	mockCreateRendererForStory.mockReturnValue({
		shouldUpdate = mockShouldUpdate,
		mount = function()
			renders += 1
			return Instance.new("Folder")
		end,
	})

	local lifecycle = render(container, story)

	local props = mockShouldUpdate.mock.lastCall[1]
	expect(props).toBeDefined()
	--[[
		Jest is sending back the second arg as a Symbol representing nil, which
		doesn't match with toBeNil. There needs to be an upstream change before
		we can use the commented expect() call.
	]]
	-- expect(mockShouldUpdate.mock.lastCall[2]).toBeNil()
	expect(tostring(mockShouldUpdate.mock.lastCall[2])).toEqual("Symbol($$nil)")

	lifecycle.update()

	expect(mockShouldUpdate.mock.lastCall[1]).toBeDefined()
	expect(mockShouldUpdate.mock.lastCall[2]).toEqual(props)
end)

test("array controls are collapsed to the first story", function()
	story.controls = {
		font = {
			Enum.Font.BuilderSans,
			Enum.Font.RobotoMono,
			Enum.Font.Merriweather,
		},
	}

	local font: Enum.Font?

	mockCreateRendererForStory.mockReturnValue({
		mount = function(_otherContainer, _otherStory, initialProps)
			font = if initialProps.controls then initialProps.controls.font else nil
		end,
	})

	render(container, story)

	expect(font).toBe(Enum.Font.BuilderSans)
end)

test("extra props can be supplied for things like the UI theme", function()
	local mockMount = jest.fn()

	mockCreateRendererForStory.mockReturnValue({
		mount = mockMount,
	})

	render(container, story, {
		theme = "Light",
	})

	expect(mockMount).toHaveBeenCalledWith(
		expect.anything(),
		expect.anything(),
		expect.objectContaining({
			container = container,
			theme = "Light",
		})
	)
end)
