local JestGlobals = require("@pkg/JestGlobals")
local ModuleLoader = require("@pkg/ModuleLoader")

local expect = JestGlobals.expect
local test = JestGlobals.test

test("Storyteller can be required", function()
	local Storyteller
	local success = pcall(function()
		Storyteller = require("@self")
	end)

	expect(success).toBe(true)
	expect(Storyteller).toBeDefined()
end)

test("Storyteller can be required in a ModuleLoader context", function()
	local loader = ModuleLoader.createProxyModuleLoader()

	local Storyteller
	local success = pcall(function()
		Storyteller = loader.require(script.Parent)
	end)

	expect(success).toBe(true)
	expect(Storyteller).toBeDefined()
end)
