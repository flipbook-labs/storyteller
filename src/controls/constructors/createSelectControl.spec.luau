local JestGlobals = require("@pkg/JestGlobals")

local createSelectControl = require("./createSelectControl")

local expect = JestGlobals.expect
local test = JestGlobals.test

test("throws when the default value does not map to one of the options", function()
	expect(function()
		createSelectControl({ "Option 1", "Option 2", "Option 3" }, "Bad Option")
	end).toThrow()
end)

test("throws when the mapping is incomplete", function()
	expect(function()
		createSelectControl(
			{
				"Option 1",
				"Option 2",
			},
			"Option1",
			{
				Option1 = "Option 1",
			}
		)
	end).toThrow()
end)
