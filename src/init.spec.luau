local JestGlobals = require("@pkg/JestGlobals")
local ModuleLoader = require("@pkg/ModuleLoader")

local expect = JestGlobals.expect
local test = JestGlobals.test

test("Storyteller can be required", function()
	local Storyteller
	expect(function()
		Storyteller = require("@self")
	end).never.toThrow()

	expect(Storyteller).toBeDefined()
end)

test("creates independent Storyteller stores", function()
	local Storyteller = require("@self")
	local rootA = Instance.new("Folder")
	local rootB = Instance.new("Folder")

	local storeA = Storyteller.createStore(rootA)
	local storeB = Storyteller.createStore(rootB)

	expect(storeA).never.toBe(storeB)

	storeA.destroy()
	storeB.destroy()
	rootA:Destroy()
	rootB:Destroy()
end)

test("Storyteller can be required in a ModuleLoader context", function()
	local loader = ModuleLoader.new()

	local Storyteller
	expect(function()
		Storyteller = loader:require(script.Parent)
	end).never.toThrow()

	expect(Storyteller).toBeDefined()
end)
