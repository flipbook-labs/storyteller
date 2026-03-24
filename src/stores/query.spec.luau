local JestGlobals = require("@pkg/JestGlobals")

local isStoryModule = require("@root/isStoryModule")
local isStorybookModule = require("@root/isStorybookModule")
local new = require("@root/test-utils/new")
local types = require("@root/types")
local waitFor = require("@root/test-utils/waitFor")

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

		waitFor(function()
			expect(modulesQuery.get()).toEqual({ moduleScript })
		end)
	end)

	test("updates when removing a matching Instance", function()
		local root = Instance.new("Folder")
		local moduleScript = Instance.new("ModuleScript")

		moduleScript.Parent = root

		local modulesQuery = query({
			selector = "ModuleScript",
			root = root,
		})

		waitFor(function()
			expect(modulesQuery.get()).toEqual({ moduleScript })
		end)

		moduleScript.Parent = nil

		waitFor(function()
			expect(modulesQuery.get()).toEqual({})
		end)
	end)

	test("updates when destroying a matching Instance", function()
		local root = Instance.new("Folder")
		local moduleScript = Instance.new("ModuleScript")

		moduleScript.Parent = root

		local modulesQuery = query({
			selector = "ModuleScript",
			root = root,
		})

		waitFor(function()
			expect(modulesQuery.get()).toEqual({ moduleScript })
		end)

		moduleScript:Destroy()

		waitFor(function()
			expect(modulesQuery.get()).toEqual({})
		end)
	end)

	test("updates when reparenting a matching Instance", function()
		local root = Instance.new("Folder")

		local child = Instance.new("Folder")
		child.Parent = root

		local moduleScript = Instance.new("ModuleScript")

		moduleScript.Parent = root

		local modulesQuery = query({
			selector = "ModuleScript",
			root = root,
		})

		local snapshot

		waitFor(function()
			snapshot = modulesQuery.get()

			expect(snapshot).toEqual({ moduleScript })
		end)

		moduleScript.Parent = child

		waitFor(function()
			-- The array of matches still has the same contents, but the table
			-- identity should change
			expect(modulesQuery.get()).toEqual({ moduleScript })
			expect(modulesQuery.get()).never.toBe(snapshot)
		end)
	end)

	test("updates when a non-matching Instance becomes a match", function()
		local root = Instance.new("Folder")
		local moduleScript = Instance.new("ModuleScript")

		moduleScript.Parent = root

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

		waitFor(function()
			expect(storybookModulesQuery.get()).toEqual({ moduleScript })
		end)
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

		local storybookModulesQuery = query({
			selector = "ModuleScript",
			matcher = isStorybookModule,
			root = root,
		})

		waitFor(function()
			expect(storybookModulesQuery.get()).toEqual({ moduleScript })
		end)

		moduleScript.Name = "Foo"

		waitFor(function()
			expect(storybookModulesQuery.get()).toEqual({})
		end)
	end)
end)

describe("events", function()
	test("fires `changed` when any matching Instances are changed", function()
		local root = Instance.new("Folder")

		local moduleScript = Instance.new("ModuleScript")
		moduleScript.Parent = root

		local modulesQuery = query({
			root = root,
			selector = "ModuleScript",
		})

		local snapshot
		waitFor(function()
			snapshot = modulesQuery.get()
			expect(snapshot).toEqual({ moduleScript })
		end)

		local changeCount = 0

		modulesQuery.changed:Connect(function()
			changeCount += 1
		end)

		expect(changeCount).toBe(0)

		moduleScript.Name = "NewName"

		waitFor(function()
			expect(changeCount).toBe(1)
		end)

		moduleScript.Source = [[
			return "Hello, World!"
		]]

		waitFor(function()
			expect(changeCount).toBe(2)
		end)

		expect(modulesQuery.get()).never.toBe(snapshot)
		expect(modulesQuery.get()).toEqual({ moduleScript })
	end)

	test("fires `added` when any matching Instances are added to a root", function()
		local root = Instance.new("Folder")

		local moduleScriptA = Instance.new("ModuleScript")
		local moduleScriptB = Instance.new("ModuleScript")
		local moduleScriptC = Instance.new("ModuleScript")

		local modulesQuery = query({
			root = root,
			selector = "ModuleScript",
		})

		local addCount = 0

		modulesQuery.added:Connect(function()
			addCount += 1
		end)

		moduleScriptA.Parent = root

		waitFor(function()
			expect(addCount).toBe(1)
		end)

		moduleScriptB.Parent = root

		waitFor(function()
			expect(addCount).toBe(2)
		end)

		moduleScriptC.Parent = root

		waitFor(function()
			expect(addCount).toBe(3)
		end)

		expect(modulesQuery.get()).toEqual({ moduleScriptA, moduleScriptB, moduleScriptC })
	end)

	test("fires `removed` when any matching Instances are removed from a root", function()
		local root = Instance.new("Folder")

		local moduleScriptA = Instance.new("ModuleScript")
		moduleScriptA.Parent = root

		local moduleScriptB = Instance.new("ModuleScript")
		moduleScriptB.Parent = root

		local modulesQuery = query({
			root = root,
			selector = "ModuleScript",
		})

		waitFor(function()
			expect(modulesQuery.get()).toEqual({ moduleScriptA, moduleScriptB })
		end)

		local removeCount = 0

		modulesQuery.removed:Connect(function()
			removeCount += 1
		end)

		moduleScriptA.Parent = nil

		waitFor(function()
			expect(removeCount).toBe(1)
		end)

		moduleScriptB.Parent = nil

		waitFor(function()
			expect(removeCount).toBe(2)
		end)

		expect(modulesQuery.get()).toEqual({})
	end)

	test("fires `removed` when any matching Instances are destroyed", function()
		local root = Instance.new("Folder")

		local moduleScriptA = Instance.new("ModuleScript")
		moduleScriptA.Parent = root

		local moduleScriptB = Instance.new("ModuleScript")
		moduleScriptB.Parent = root

		local modulesQuery = query({
			root = root,
			selector = "ModuleScript",
		})

		waitFor(function()
			expect(modulesQuery.get()).toEqual({ moduleScriptA, moduleScriptB })
		end)

		local removeCount = 0

		modulesQuery.removed:Connect(function()
			removeCount += 1
		end)

		moduleScriptA:Destroy()

		waitFor(function()
			expect(removeCount).toBe(1)
		end)

		moduleScriptB:Destroy()

		waitFor(function()
			expect(removeCount).toBe(2)
		end)

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

		waitFor(function()
			expect(#storybookModulesQuery.get()).toEqual(0)
		end)

		storybookModule.Name = "Foo.storybook"

		waitFor(function()
			expect(#storybookModulesQuery.get()).toEqual(1)
		end)

		storybookModule.Source = [[
			return {
				storyRoot=
					script.Parent
				}
			}
		]]

		expect(#storybookModulesQuery.get()).toEqual(1)

		storybookModule.Parent = nil

		waitFor(function()
			expect(#storybookModulesQuery.get()).toEqual(0)
		end)
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
		expect(#storyModulesQuery.get()).toBe(0)

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

		waitFor(function()
			expect(#storybookModulesQuery.get()).toBe(1)
			expect(#storyModulesQuery.get()).toBe(2)
		end)
	end)

	test("an instance being changed puts it at the end of the matches", function()
		local root = Instance.new("Folder")

		local storybookModuleA = new("ModuleScript", {
			Name = "Foo.storybook",
			Source = [[
				return {
					storyRoot = script.Parent
					}
				}
			]],
		})

		local storybookModuleB = new("ModuleScript", {
			Name = "Bar.storybook",
			Source = [[
				return {
					storyRoot = script.Parent
					}
				}
			]],
		})

		local storybookModulesQuery = query({
			root = root,
			selector = "ModuleScript",
			matcher = isStorybookModule,
		})

		storybookModuleA.Parent = root
		storybookModuleB.Parent = root

		waitFor(function()
			expect(storybookModulesQuery.get()).toEqual({ storybookModuleA, storybookModuleB })
		end)

		storybookModuleA.Name = "SecretThirdThing.storybook"

		waitFor(function()
			expect(storybookModulesQuery.get()).toEqual({ storybookModuleB, storybookModuleA })
		end)
	end)

	test("prevents duplicates from being added to the queue", function()
		local root = Instance.new("Folder")

		local storybookModule = Instance.new("ModuleScript")
		storybookModule.Name = "Foo.storybook"

		local storybookModulesQuery = query({
			root = root,
			selector = "ModuleScript",
			matcher = isStorybookModule,
		})

		storybookModule.Parent = root

		waitFor(function()
			expect(storybookModulesQuery.getQueueSize()).toBe(0)
		end)

		storybookModule.Name = "Bar.storybook"
		storybookModule.Source = [[
			return {
				storyRoot=
					script.Parent.Parent
				}
			}
		]]

		waitFor(function()
			expect(storybookModulesQuery.getQueueSize()).toBe(1)
		end)

		waitFor(function()
			expect(storybookModulesQuery.getQueueSize()).toBe(0)
		end)
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

	waitFor(function()
		expect(storyModulesQuery.get()).toEqual(expect.arrayContaining({ storyA, storyB, storyC, storyD }))
		expect(storybookModulesQuery.get()).toEqual(expect.arrayContaining({ storybookA, storybookB }))
	end)
end)
