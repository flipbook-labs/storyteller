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

test("only exposes the required multi-story runtime API", function()
	local Storyteller = require("@self")
	local publicApi = Storyteller :: any

	expect(Storyteller.useStoryModuleSnapshots).toBeDefined()
	expect(publicApi.loadStoriesFromModule).toBeUndefined()
	expect(publicApi.loadStoryModuleSnapshot).toBeUndefined()
	expect(publicApi.useStoriesForModule).toBeUndefined()
end)

test("Storyteller can be required in a ModuleLoader context", function()
	local loader = ModuleLoader.new()

	local Storyteller
	expect(function()
		Storyteller = loader:require(script.Parent)
	end).never.toThrow()

	expect(Storyteller).toBeDefined()
end)
