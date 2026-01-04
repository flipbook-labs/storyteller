local JestGlobals = require("@pkg/JestGlobals")

local ControlTypes = require("@root/controls/ControlTypes")

local createCheckControl = require("./createCheckControl")

type Mapping = ControlTypes.Mapping

local expect = JestGlobals.expect
local test = JestGlobals.test

test("throws when the default value does not map to one of the options", function()
	expect(function()
		createCheckControl({ "Option 1", "Option 2", "Option 3" }, { "Bad Option" })
	end).toThrow()
end)

test("throws when the mapping is incomplete", function()
	expect(function()
		createCheckControl(
			{
				"Option 1",
				"Option 2",
			},
			{
				"Option1",
			},
			{
				Option1 = "Option 1",
			} :: Mapping
		)
	end).toThrow()
end)
