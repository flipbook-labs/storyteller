local JestGlobals = require("@pkg/JestGlobals")

local createMultiSelectControl = require("./createMultiSelectControl")

local expect = JestGlobals.expect
local test = JestGlobals.test

test("throws when the default value does not map to one of the options", function()
	expect(function()
		createMultiSelectControl({
			"Option 1",
			"Option 2",
			"Option 3",
		}, {
			default = { "Bad Option" },
		})
	end).toThrow()
end)
