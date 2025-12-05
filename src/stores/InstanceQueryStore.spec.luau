local JestGlobals = require("@pkg/JestGlobals")

local new = require("@root/test-utils/new")
local types = require("@root/types")

local InstanceQueryStore = require("./InstanceQueryStore")

local expect = JestGlobals.expect
local test = JestGlobals.test

type LoadedStorybook = types.LoadedStorybook

test("the initial arguments get attached to the returned store", function()
	local root = Instance.new("Folder")

	local store = InstanceQueryStore.new(root, "ModuleScript")

	expect(store.root).toEqual(root)
	expect(store.selector).toEqual("ModuleScript")
end)

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

	local store = InstanceQueryStore.new(container, "ModuleScript")

	expect(store.getMatches(false)).toEqual(expect.arrayContaining({
		moduleA,
		moduleB,
	}))

	moduleC.Parent = container
	task.wait()

	moduleA.Parent = nil
	task.wait()

	expect(store.getMatches(false)).toEqual(expect.arrayContaining({
		moduleB,
		moduleC,
	}))

	moduleB.Parent = container
	task.wait()

	expect(store.getMatches(false)).toEqual(expect.arrayContaining({
		moduleB,
		moduleC,
	}))
end)
