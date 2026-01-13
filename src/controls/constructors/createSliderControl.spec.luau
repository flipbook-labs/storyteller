local JestGlobals = require("@pkg/JestGlobals")

local createSliderControl = require("./createSliderControl")

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
