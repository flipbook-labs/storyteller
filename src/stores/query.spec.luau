local Charm = require("@pkg/Charm")
local JestGlobals = require("@pkg/JestGlobals")

local isStoryModule = require("@root/isStoryModule")
local isStorybookModule = require("@root/isStorybookModule")
local new = require("@root/test-utils/new")
local types = require("@root/types")

local query = require("./query")

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

type LoadedStorybook = types.LoadedStorybook

describe("DataModel behavior", function()
	test("updates when adding a matching Instance", function()
		local root = Instance.new("Folder")
		local moduleScript = Instance.new("ModuleScript")

		local modulesQuery = query({
			selector = "ModuleScript",
			root = root,
		})

		expect(modulesQuery.get()).toEqual({})

		moduleScript.Parent = root
		task.wait()

		expect(modulesQuery.get()).toEqual({ moduleScript })
	end)

	test("updates when removing a matching Instance", function()
		local root = Instance.new("Folder")
		local moduleScript = Instance.new("ModuleScript")

		moduleScript.Parent = root
		task.wait()

		local modulesQuery = query({
			selector = "ModuleScript",
			root = root,
		})

		expect(modulesQuery.get()).toEqual({ moduleScript })

		moduleScript.Parent = nil
		task.wait()

		expect(modulesQuery.get()).toEqual({})
	end)

	test("updates when destroying a matching Instance", function()
		local root = Instance.new("Folder")
		local moduleScript = Instance.new("ModuleScript")

		moduleScript.Parent = root
		task.wait()

		local modulesQuery = query({
			selector = "ModuleScript",
			root = root,
		})

		expect(modulesQuery.get()).toEqual({ moduleScript })

		moduleScript:Destroy()
		task.wait()

		expect(modulesQuery.get()).toEqual({})
	end)

	test("updates when reparenting a matching Instance", function()
		local root = Instance.new("Folder")

		local child = Instance.new("Folder")
		child.Parent = root

		local moduleScript = Instance.new("ModuleScript")

		moduleScript.Parent = root
		task.wait()

		local modulesQuery = query({
			selector = "ModuleScript",
			root = root,
		})

		local snapshot = modulesQuery.get()

		expect(snapshot).toEqual({ moduleScript })

		moduleScript.Parent = child
		task.wait()

		-- The array of matches still has the same contents, but the table
		-- identity should change
		expect(modulesQuery.get()).toEqual({ moduleScript })
		expect(modulesQuery.get()).never.toBe(snapshot)
	end)

	test("updates when a non-matching Instance becomes a match", function()
		local root = Instance.new("Folder")
		local moduleScript = Instance.new("ModuleScript")

		moduleScript.Parent = root
		task.wait()

		local storybookModulesQuery = query({
			selector = "ModuleScript",
			matcher = isStorybookModule,
			root = root,
		})

		expect(storybookModulesQuery.get()).toEqual({})

		moduleScript.Name = "Foo.storybook"
		moduleScript.Source = [[
			return {
				storyRoot }
			}
		]]
		task.wait()

		expect(storybookModulesQuery.get()).toEqual({ moduleScript })
	end)

	test("updates when a matching Instance no longer matches", function()
		local root = Instance.new("Folder")

		local moduleScript = Instance.new("ModuleScript")
		moduleScript.Name = "Foo.storybook"
		moduleScript.Source = [[
			return {
				storyRoot }
			}
		]]
		moduleScript.Parent = root
		task.wait()

		local storybookModulesQuery = query({
			selector = "ModuleScript",
			matcher = isStorybookModule,
			root = root,
		})

		expect(storybookModulesQuery.get()).toEqual({ moduleScript })

		moduleScript.Name = "Foo"
		task.wait()

		expect(storybookModulesQuery.get()).toEqual({})
	end)
end)

describe("reactive get()", function()
	test("can be listened to with `Charm.listen`", function()
		local root = Instance.new("Folder")
		local moduleScript = Instance.new("ModuleScript")

		local modulesQuery = query({
			root = root,
			selector = "ModuleScript",
		})

		local snapshots: { { Instance } } = {}
		local dispose = Charm.listen(modulesQuery.get, function(matches)
			table.insert(snapshots, matches)
		end)

		expect(#snapshots).toBe(1)
		expect(snapshots[1]).toEqual({})

		moduleScript.Parent = root
		task.wait()

		expect(#snapshots).toBe(2)
		expect(snapshots[2]).toEqual({ moduleScript })

		dispose()
	end)

	test("can be subscribed to with `Charm.subscribe`", function()
		local root = Instance.new("Folder")
		local moduleScript = Instance.new("ModuleScript")
		moduleScript.Parent = root

		local modulesQuery = query({
			root = root,
			selector = "ModuleScript",
		})

		local callbackCount = 0
		local dispose = Charm.subscribe(modulesQuery.get, function()
			callbackCount += 1
		end)

		expect(callbackCount).toBe(0)

		moduleScript.Name = "Renamed"
		task.wait()

		expect(callbackCount).toBe(1)

		dispose()
	end)

	test("returns updated snapshots when matches are removed", function()
		local root = Instance.new("Folder")

		local moduleScriptA = Instance.new("ModuleScript")
		moduleScriptA.Parent = root

		local moduleScriptB = Instance.new("ModuleScript")
		moduleScriptB.Parent = root

		local modulesQuery = query({
			root = root,
			selector = "ModuleScript",
		})

		expect(modulesQuery.get()).toEqual({ moduleScriptA, moduleScriptB })

		moduleScriptA.Parent = nil
		task.wait()
		expect(modulesQuery.get()).toEqual({ moduleScriptB })

		moduleScriptB:Destroy()
		task.wait()
		expect(modulesQuery.get()).toEqual({})
	end)
end)

describe("user journeys", function()
	-- This captures a common user journey where a blank ModuleScript is
	-- inserted by the user, renamed to "Foo.storybook," and then filled out
	-- the contents so it becomes a valid storybook
	test("creating a new Storybook in Studio", function()
		local root = Instance.new("Folder")

		local storybookModulesQuery = query({
			root = root,
			selector = "ModuleScript",
			matcher = isStorybookModule,
		})

		expect(#storybookModulesQuery.get()).toEqual(0)

		local storybookModule = Instance.new("ModuleScript")

		storybookModule.Parent = root
		task.wait()

		expect(#storybookModulesQuery.get()).toEqual(0)

		storybookModule.Name = "Foo.storybook"
		task.wait()

		expect(#storybookModulesQuery.get()).toEqual(1)

		storybookModule.Source = [[
			return {
				storyRoot=
					script.Parent
				}
			}
		]]
		task.wait()

		expect(#storybookModulesQuery.get()).toEqual(1)

		storybookModule.Parent = nil
		task.wait()

		expect(#storybookModulesQuery.get()).toEqual(0)
	end)
end)

describe("queue processing", function()
	test("processes items when they are newly added to the DM", function()
		local root = Instance.new("Folder")

		local storybookModulesQuery = query({
			root = root,
			selector = "ModuleScript",
			matcher = isStorybookModule,
		})

		local storyModulesQuery = query({
			root = root,
			selector = "ModuleScript",
			matcher = isStoryModule,
		})

		expect(#storybookModulesQuery.get()).toBe(0)
		expect(storybookModulesQuery.getQueueSize()).toBe(0)
		expect(#storyModulesQuery.get()).toBe(0)
		expect(storyModulesQuery.getQueueSize()).toBe(0)

		local storybookModule = new("ModuleScript", {
			Name = "Foo.storybook",
			Source = [[
				return {
					storyRoot=
						script.Parent
					}
				}
			]],
		})

		local storyModuleA = new("ModuleScript", {
			Name = "A.story",
		})

		local storyModuleB = new("ModuleScript", {
			Name = "B.story",
		})

		storybookModule.Parent = root
		storyModuleA.Parent = root
		storyModuleB.Parent = root

		expect(#storybookModulesQuery.get()).toBe(0)
		expect(storybookModulesQuery.getQueueSize()).toBe(3)
		expect(#storyModulesQuery.get()).toBe(0)
		expect(storyModulesQuery.getQueueSize()).toBe(3)

		storybookModulesQuery.flush()
		storyModulesQuery.flush()

		expect(#storybookModulesQuery.get()).toBe(1)
		expect(storybookModulesQuery.getQueueSize()).toBe(0)
		expect(#storyModulesQuery.get()).toBe(2)
		expect(storyModulesQuery.getQueueSize()).toBe(0)
	end)

	test("an instance being changed puts it back in the queue", function()
		local root = Instance.new("Folder")

		local storybookModule = new("ModuleScript", {
			Name = "Foo.storybook",
			Source = [[
				return {
					storyRoot=
						script.Parent
					}
				}
			]],
		})

		local storybookModulesQuery = query({
			root = root,
			selector = "ModuleScript",
			matcher = isStorybookModule,
		})

		storybookModule.Parent = root
		storybookModulesQuery.flush()

		expect(storybookModulesQuery.getQueueSize()).toBe(0)

		storybookModule.Name = "Bar.storybook"

		expect(storybookModulesQuery.getQueueSize()).toBe(1)

		storybookModulesQuery.flush()
		expect(storybookModulesQuery.getQueueSize()).toBe(0)
	end)

	test("prevents duplicates from being added to the queue", function()
		local root = Instance.new("Folder")

		local storybookModule = Instance.new("ModuleScript")
		storybookModule.Name = "Foo.storybook"
		storybookModule.Source = [[
			return {
				storyRoot=
					script.Parent
				}
			}
		]]

		local storybookModulesQuery = query({
			root = root,
			selector = "ModuleScript",
			matcher = isStorybookModule,
		})

		storybookModule.Parent = root

		storybookModulesQuery.flush()

		expect(storybookModulesQuery.getQueueSize()).toBe(0)

		storybookModule.Name = "Bar.storybook"
		storybookModule.Source = [[
			return {
				storyRoot=
					script.Parent.Parent
				}
			}
		]]

		expect(storybookModulesQuery.getQueueSize()).toBe(1)

		storybookModulesQuery.flush()

		expect(storybookModulesQuery.getQueueSize()).toBe(0)
	end)
end)

test("collects all relevant ModuleScripts under the root", function()
	local storyA = new("ModuleScript")
	local storyB = new("ModuleScript")
	local storyC = new("ModuleScript")
	local storyD = new("ModuleScript")

	local storybookA = new("ModuleScript")
	local storybookB = new("ModuleScript")

	local root = new("Folder", nil, {
		Folder = new("Folder", nil, {
			Folder = new("Folder", nil, {
				Folder = new("Folder", nil, {
					["A.story"] = storyA,
				}),
				AnotherFolder = new("Folder", nil, {
					["B.story"] = storyB,
				}),
				AndOneMoreFolder = new("Folder", nil, {
					Folder = new("Folder", nil, {
						Folder = new("Folder", nil, {
							Folder = new("Folder", nil, {
								["C.story"] = storyC,
							}),
						}),
					}),
					ModuleScriptA = new("ModuleScript"),
					ModuleScriptB = new("ModuleScript"),
					ModuleScriptC = new("ModuleScript"),
				}),
				["D.story"] = storyD,
				ModuleScript = new("ModuleScript"),
			}),
			["A.storybook"] = storybookA,
			ModuleScriptA = new("ModuleScript"),
			ModuleScriptB = new("ModuleScript"),
			ModuleScriptC = new("ModuleScript"),
		}),
		["B.storybook"] = storybookB,
	})

	local storyModulesQuery = query({
		root = root,
		selector = "ModuleScript",
		matcher = isStoryModule,
	})

	local storybookModulesQuery = query({
		root = root,
		selector = "ModuleScript",
		matcher = isStorybookModule,
	})

	expect(storyModulesQuery.get()).toEqual(expect.arrayContaining({ storyA, storyB, storyC, storyD }))
	expect(storybookModulesQuery.get()).toEqual(expect.arrayContaining({ storybookA, storybookB }))
end)
