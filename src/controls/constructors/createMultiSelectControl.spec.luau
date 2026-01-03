local JestGlobals = require("@pkg/JestGlobals")

local createMultiSelectControl = require("./createMultiSelectControl")

local expect = JestGlobals.expect
local test = JestGlobals.test

test("throws when a default value does not map to any of the options", function()
	expect(function()
		createMultiSelectControl({
			"Option 1",
			"Option 2",
			"Option 3",
		}, {
			"Bad Option",
		})
	end).toThrow()

	expect(function()
		createMultiSelectControl({
			["Option 1"] = 1,
			["Option 2"] = 2,
			["Option 3"] = 3,
		}, {
			"Bad Option",
		})
	end).toThrow()
end)
