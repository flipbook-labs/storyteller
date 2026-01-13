local JestGlobals = require("@pkg/JestGlobals")

local createNumberControl = require("./createNumberControl")

local expect = JestGlobals.expect
local test = JestGlobals.test

test("throws when the default is out of range", function()
	expect(function()
		createNumberControl(10000, NumberRange.new(1, 100))
	end).toThrow()

	expect(function()
		createNumberControl(-1000, NumberRange.new(1, 100))
	end).toThrow()
end)
