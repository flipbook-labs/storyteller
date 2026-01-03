local JestGlobals = require("@pkg/JestGlobals")

local createRadioControl = require("./createRadioControl")

local expect = JestGlobals.expect
local test = JestGlobals.test

test("throws when the default value does not map to one of the options", function()
	expect(function()
		createRadioControl({
			"Option 1",
			"Option 2",
			"Option 3",
		}, "Bad Option")
	end).toThrow()

	expect(function()
		createRadioControl({
			["Option 1"] = 1,
			["Option 2"] = 2,
			["Option 3"] = 3,
		}, "Bad Option")
	end).toThrow()
end)
