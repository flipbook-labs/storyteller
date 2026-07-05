local JestGlobals = require("@pkg/JestGlobals")

local createStory = require("@root/test-utils/createStory")
local types = require("@root/types")

local afterEach = JestGlobals.afterEach
local beforeEach = JestGlobals.beforeEach
local expect = JestGlobals.expect
local jest = JestGlobals.jest
local test = JestGlobals.test

type LoadedStory<T> = types.LoadedStory<T>

local ROACT_RENDERER = { kind = "Roact" }
local REACT_RENDERER = { kind = "React" }
local FUSION_RENDERER = { kind = "Fusion" }
local VIDE_RENDERER = { kind = "Vide" }
local IRIS_RENDERER = { kind = "Iris" }
local MANUAL_RENDERER = { kind = "Manual" }

local mockCreateRoactRenderer = jest.fn()
local mockCreateReactRenderer = jest.fn()
local mockCreateFusionRenderer = jest.fn()
local mockCreateVideRenderer = jest.fn()
local mockCreateIrisRenderer = jest.fn()
local mockCreateManualRenderer = jest.fn()

local createRendererForStory

beforeEach(function()
	mockCreateRoactRenderer.mockReturnValue(ROACT_RENDERER)
	mockCreateReactRenderer.mockReturnValue(REACT_RENDERER)
	mockCreateFusionRenderer.mockReturnValue(FUSION_RENDERER)
	mockCreateVideRenderer.mockReturnValue(VIDE_RENDERER)
	mockCreateIrisRenderer.mockReturnValue(IRIS_RENDERER)
	mockCreateManualRenderer.mockReturnValue(MANUAL_RENDERER)

	local renderers = script.Parent.renderers

	jest.mock(renderers.createRoactRenderer, function()
		return mockCreateRoactRenderer
	end)
	jest.mock(renderers.createReactRenderer, function()
		return mockCreateReactRenderer
	end)
	jest.mock(renderers.createFusionRenderer, function()
		return mockCreateFusionRenderer
	end)
	jest.mock(renderers.createVideRenderer, function()
		return mockCreateVideRenderer
	end)
	jest.mock(renderers.createIrisRenderer, function()
		return mockCreateIrisRenderer
	end)
	jest.mock(renderers.createManualRenderer, function()
		return mockCreateManualRenderer
	end)

	createRendererForStory = require("./createRendererForStory")
end)

afterEach(function()
	jest.resetAllMocks()
end)

local function createStoryWithPackages(packages: types.StoryPackages?): LoadedStory<any>
	return createStory({
		story = function() end,
		packages = packages,
	})
end

test("selects the Roact renderer when Roact is provided", function()
	local packages = { Roact = {} }
	local renderer = createRendererForStory(createStoryWithPackages(packages))

	expect(renderer).toBe(ROACT_RENDERER)
	expect(mockCreateRoactRenderer).toHaveBeenCalledWith(packages)
end)

test("selects the React renderer when React and ReactRoblox are provided", function()
	local packages = { React = {}, ReactRoblox = {} }
	local renderer = createRendererForStory(createStoryWithPackages(packages))

	expect(renderer).toBe(REACT_RENDERER)
	expect(mockCreateReactRenderer).toHaveBeenCalledWith(packages)
end)

test("falls back to the Manual renderer when React is provided without ReactRoblox", function()
	local renderer = createRendererForStory(createStoryWithPackages({ React = {} }))

	expect(renderer).toBe(MANUAL_RENDERER)
	expect(mockCreateReactRenderer).never.toHaveBeenCalled()
end)

test("selects the Fusion renderer when Fusion is provided", function()
	local packages = { Fusion = {} }
	local renderer = createRendererForStory(createStoryWithPackages(packages))

	expect(renderer).toBe(FUSION_RENDERER)
	expect(mockCreateFusionRenderer).toHaveBeenCalledWith(packages)
end)

test("selects the Vide renderer when Vide is provided", function()
	local packages = { Vide = {} }
	local renderer = createRendererForStory(createStoryWithPackages(packages))

	expect(renderer).toBe(VIDE_RENDERER)
	expect(mockCreateVideRenderer).toHaveBeenCalledWith(packages)
end)

test("selects the Iris renderer when Iris is provided", function()
	local packages = { Iris = {} }
	local renderer = createRendererForStory(createStoryWithPackages(packages))

	expect(renderer).toBe(IRIS_RENDERER)
	expect(mockCreateIrisRenderer).toHaveBeenCalledWith(packages)
end)

test("selects the Manual renderer when no packages are provided", function()
	local renderer = createRendererForStory(createStoryWithPackages(nil))

	expect(renderer).toBe(MANUAL_RENDERER)
end)

test("selects the Manual renderer when no packages match a UI library", function()
	local renderer = createRendererForStory(createStoryWithPackages({ SomethingElse = {} }))

	expect(renderer).toBe(MANUAL_RENDERER)
end)

test("prefers Roact over every other renderer", function()
	local packages = {
		Roact = {},
		React = {},
		ReactRoblox = {},
		Fusion = {},
		Vide = {},
		Iris = {},
	}
	local renderer = createRendererForStory(createStoryWithPackages(packages))

	expect(renderer).toBe(ROACT_RENDERER)
end)

test("prefers React over Fusion, Vide, and Iris", function()
	local packages = {
		React = {},
		ReactRoblox = {},
		Fusion = {},
		Vide = {},
		Iris = {},
	}
	local renderer = createRendererForStory(createStoryWithPackages(packages))

	expect(renderer).toBe(REACT_RENDERER)
end)

test("prefers Fusion over Vide and Iris", function()
	local packages = {
		Fusion = {},
		Vide = {},
		Iris = {},
	}
	local renderer = createRendererForStory(createStoryWithPackages(packages))

	expect(renderer).toBe(FUSION_RENDERER)
end)

test("prefers Vide over Iris", function()
	local packages = {
		Vide = {},
		Iris = {},
	}
	local renderer = createRendererForStory(createStoryWithPackages(packages))

	expect(renderer).toBe(VIDE_RENDERER)
end)

test("uses the storybook's packages when the story does not define its own", function()
	local packages = { Vide = {} }
	local story = createStoryWithPackages(nil)
	story.storybook.packages = packages

	local renderer = createRendererForStory(story)

	expect(renderer).toBe(VIDE_RENDERER)
	expect(mockCreateVideRenderer).toHaveBeenCalledWith(packages)
end)

test("the story's packages take precedence over the storybook's packages", function()
	local storyPackages = { Vide = {} }
	local story = createStoryWithPackages(storyPackages)
	story.storybook.packages = { Roact = {} }

	local renderer = createRendererForStory(story)

	expect(renderer).toBe(VIDE_RENDERER)
	expect(mockCreateVideRenderer).toHaveBeenCalledWith(storyPackages)
	expect(mockCreateRoactRenderer).never.toHaveBeenCalled()
end)
