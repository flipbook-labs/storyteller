local JestGlobals = require("@pkg/JestGlobals")

local createObjectControl = require("./createObjectControl")

local expect = JestGlobals.expect
local test = JestGlobals.test

test("creates a control with no default", function()
	expect(function()
		createObjectControl()
	end).never.toThrow()
end)

test("creates a control with an Instance default", function()
	expect(function()
		createObjectControl(game)
	end).never.toThrow()
end)
