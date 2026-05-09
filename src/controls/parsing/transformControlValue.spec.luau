local JestGlobals = require("@pkg/JestGlobals")

local ControlTypes = require("@root/controls/ControlTypes")
local createCheckControl = require("@root/controls/constructors/createCheckControl")
local createMultiSelectControl = require("@root/controls/constructors/createMultiSelectControl")
local createRadioControl = require("@root/controls/constructors/createRadioControl")
local createSelectControl = require("@root/controls/constructors/createSelectControl")

local transformControlValue = require("./transformControlValue")

type StoryControl = ControlTypes.StoryControl
type InputStoryControlValue = ControlTypes.InputStoryControlValue

local expect = JestGlobals.expect
local test = JestGlobals.test

test("CheckControl default value", function()
	local selectMany = createCheckControl({
		"A",
		"B",
		"C",
	})

	expect(transformControlValue(selectMany, nil)).toEqual({})
end)

test("MultiSelectControl default value", function()
	local selectMany = createMultiSelectControl({
		"A",
		"B",
		"C",
	})

	expect(transformControlValue(selectMany, nil)).toEqual({})
end)

test("RadioControl default value", function()
	local selectOne = createRadioControl({
		"A",
		"B",
		"C",
	})

	expect(transformControlValue(selectOne, nil)).toEqual(nil)
end)

test("SelectControl default value", function()
	local selectOne = createSelectControl({
		"A",
		"B",
		"C",
	})

	-- This is a weird default but matches current behavior. Ideally this would
	-- evaluate to `nil` like RadioControl for consistency with single-selection
	-- list controls.
	expect(transformControlValue(selectOne, nil)).toEqual("A")
end)
