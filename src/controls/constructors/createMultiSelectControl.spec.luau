local JestGlobals = require("@pkg/JestGlobals")

local createMultiSelectControl = require("./createMultiSelectControl")

local expect = JestGlobals.expect
local test = JestGlobals.test

test("throws when the mapping is incomplete", function()
	expect(function()
		createMultiSelectControl({
			"Option 1",
			"Option 2",
		}, {
			Option1 = "Option 1",
		})
	end).toThrow()
end)
