local JestGlobals = require("@pkg/JestGlobals")

local ControlTypes = require("@root/controls/ControlTypes")

local createSliderControl = require("./createSliderControl")

type StoryControlsSchema = ControlTypes.StoryControlsSchema
type StoryControls = ControlTypes.StoryControls
type StoryControl = ControlTypes.StoryControl
type Mapping = ControlTypes.Mapping

local expect = JestGlobals.expect
local test = JestGlobals.test

test("throws when the default is out of range", function()
	expect(function()
		createSliderControl(10000, NumberRange.new(1, 100))
	end).toThrow()

	expect(function()
		createSliderControl(-1000, NumberRange.new(1, 100))
	end).toThrow()
end)
