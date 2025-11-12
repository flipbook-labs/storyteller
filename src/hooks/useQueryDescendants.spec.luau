local JestGlobals = require("@pkg/JestGlobals")
local ReactRoblox = require("@pkg/ReactRoblox")

local new = require("@root/test-utils/new")
local renderHook = require("@root/test-utils/renderHook")
local types = require("@root/types")
local waitForEvents = require("@root/test-utils/waitForEvents")

local useQueryDescendants = require("./useQueryDescendants")

local expect = JestGlobals.expect
local test = JestGlobals.test

local act = ReactRoblox.act

type LoadedStorybook = types.LoadedStorybook

test("updates when moving instances around the DataModel", function()
	local moduleA = new("ModuleScript")
	local moduleB = new("ModuleScript")
	local moduleC = new("ModuleScript")

	local container = new("Folder", nil, {
		["Folder"] = new("Folder", nil, {
			["ModuleA"] = moduleA,
			["Folder"] = new("Folder", nil, {
				["ModuleB"] = moduleB,
			}),
		}),
	})

	local getDescendants = renderHook(function()
		return useQueryDescendants(container, "ModuleScript")
	end)

	expect(getDescendants()).toEqual(expect.arrayContaining({
		moduleA,
		moduleB,
	}))

	act(function()
		moduleC.Parent = container
		waitForEvents()
	end)

	act(function()
		moduleA.Parent = nil
		waitForEvents()
	end)

	expect(getDescendants()).toEqual(expect.arrayContaining({
		moduleB,
		moduleC,
	}))

	act(function()
		moduleB.Parent = container
		waitForEvents()
	end)

	expect(getDescendants()).toEqual(expect.arrayContaining({
		moduleB,
		moduleC,
	}))
end)
