local JestGlobals = require("@pkg/JestGlobals")

local ControlTypes = require("@root/controls/ControlTypes")

local getPossibleControlOptions = require("./getPossibleControlOptions")

type StoryControlsSchema = ControlTypes.StoryControlsSchema
type StoryControls = ControlTypes.StoryControls
type StoryControl = ControlTypes.StoryControl
type ControlOptions = ControlTypes.ControlOptions

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

test("returns an empty array when there are no options", function()
	local options: ControlOptions = {}

	local possibleOptions = getPossibleControlOptions(options)

	expect(possibleOptions).toEqual({})
	expect(possibleOptions).never.toBe(options)
end)

describe("SimpleControlOptions", function()
	test("returns a copy of the SimpleControlOptions value", function()
		local options: ControlOptions = {
			"Option 1",
			"Option 2",
			"Option 3",
		}

		local possibleOptions = getPossibleControlOptions(options)

		expect(possibleOptions).toEqual({
			"Option 1",
			"Option 2",
			"Option 3",
		})
		expect(possibleOptions).never.toBe(options)
	end)
end)

describe("MappedControlOptions", function()
	test("returns the keys of a MappedControlOptions", function()
		local options: ControlOptions = {
			["Builder Sans"] = Enum.Font.BuilderSans,
			["Builder Sans (Bold)"] = Enum.Font.BuilderSansBold,
			["Builder Sans (Extra Bold)"] = Enum.Font.BuilderSansExtraBold,
		}

		local possibleOptions = getPossibleControlOptions(options)

		expect(possibleOptions).toEqual({
			"Builder Sans",
			"Builder Sans (Bold)",
			"Builder Sans (Extra Bold)",
		})
		expect(possibleOptions).never.toBe(options)
	end)
end)
