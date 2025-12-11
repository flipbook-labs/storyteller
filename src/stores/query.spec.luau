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

	local modulesQuery = query({
		selector = "ModuleScript",
		roots = { container },
	})

	expect(modulesQuery.get()).toEqual(expect.arrayContaining({
		moduleA,
		moduleB,
	}))

	moduleC.Parent = container
	task.wait()

	moduleA.Parent = nil
	task.wait()

	expect(modulesQuery.get()).toEqual(expect.arrayContaining({
		moduleB,
		moduleC,
	}))

	moduleB.Parent = container
	task.wait()

	expect(modulesQuery.get()).toEqual(expect.arrayContaining({
		moduleB,
		moduleC,
	}))
end)

-- test("updates when watched properties change", function()
-- 	local root = Instance.new("Folder")

-- 	local moduleScript = Instance.new("ModuleScript")
-- 	moduleScript.Parent = root

-- 	local modulesQuery = query({
-- 		roots = { root },
-- 		selector = "ModuleScript",
-- 		watchedProperties = { "Name" },
-- 	})

-- 	local changeCount = 0

-- 	modulesQuery.changed:Connect(function()
-- 		changeCount += 1
-- 	end)

-- 	local snapshot = modulesQuery.get()
-- 	expect(changeCount).toBe(0)
-- 	expect(snapshot).toEqual({ moduleScript })

-- 	moduleScript.Name = "NewName"
-- 	task.wait()

-- 	expect(changeCount).toBe(1)
-- 	expect(modulesQuery.get()).never.toBe(snapshot)
-- 	expect(modulesQuery.get()).toEqual({ moduleScript })
-- end)

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
		roots = { root },
		selector = "ModuleScript",
		matcher = isStoryModule,
		-- watchedProperties = { "Name", "Source" },
	})

	local storybookModulesQuery = query({
		roots = { root },
		selector = "ModuleScript",
		matcher = isStorybookModule,
		-- watchedProperties = { "Name", "Source" },
	})

	expect(storyModulesQuery.get()).toEqual(expect.arrayContaining({ storyA, storyB, storyC, storyD }))
	expect(storybookModulesQuery.get()).toEqual(expect.arrayContaining({ storybookA, storybookB }))
end)

test("recomputes when any matched Instance is added or removed", function()
	local root = new("Folder")

	local storyModulesQuery = query({
		roots = { root },
		selector = "ModuleScript",
		matcher = isStoryModule,
		-- watchedProperties = { "Name", "Source" },
	})

	local storybookModulesQuery = query({
		roots = { root },
		selector = "ModuleScript",
		matcher = isStorybookModule,
		-- watchedProperties = { "Name", "Source" },
	})

	expect(#storyModulesQuery.get()).toBe(0)
	expect(#storybookModulesQuery.get()).toBe(0)

	-- Any time a ModuleScript gets added or removed from the DM, or its Name or
	-- Source changes, we need to recompute the Story and Storybook modules

	local prevStoryModules = storyModulesQuery.get()
	local prevStorybookModules = storybookModulesQuery.get()

	local moduleScript = new("ModuleScript")

	moduleScript.Parent = root
	task.wait()

	-- Verify that the identities changed (and thus were recomputed) and that we
	-- still have 0 Stories and Storybooks
	expect(storyModulesQuery.get()).never.toBe(prevStoryModules)
	expect(#storyModulesQuery.get()).toBe(0)
	expect(storybookModulesQuery.get()).never.toBe(prevStorybookModules)
	expect(#storybookModulesQuery.get()).toBe(0)

	prevStoryModules = storyModulesQuery.get()
	prevStorybookModules = storybookModulesQuery.get()

	moduleScript.Parent = nil
	task.wait()

	-- Same as before. The ModuleScript was removed so we need to recompute,
	-- but there shouldn't be any change to the sizes
	expect(storyModulesQuery.get()).never.toBe(prevStoryModules)
	expect(#storyModulesQuery.get()).toBe(0)
	expect(storybookModulesQuery.get()).never.toBe(prevStorybookModules)
	expect(#storybookModulesQuery.get()).toBe(0)
end)

describe("user journeys", function()
	-- This captures a common user journey where a blank ModuleScript is
	-- inserted by the user, renamed to "Foo.storybook," and then filled out
	-- the contents so it becomes a valid storybook
	test("creating a new Storybook in Studio", function()
		local root = new("Folder")

		local changeCount = 0

		local storybookModulesQuery = query({
			roots = { root },
			selector = "ModuleScript",
			matcher = isStorybookModule,
			-- watchedProperties = { "Name", "Source" },
		})

		storybookModulesQuery.changed:Connect(function()
			changeCount += 1
		end)

		expect(#storybookModulesQuery.get()).toEqual(0)

		local storybookModule = Instance.new("ModuleScript")

		storybookModule.Parent = root
		task.wait()

		expect(changeCount).toEqual(1)
		expect(#storybookModulesQuery.get()).toEqual(0)

		storybookModule.Name = "Foo.storybook"
		task.wait()

		expect(changeCount).toEqual(2)
		expect(#storybookModulesQuery.get()).toEqual(1)

		storybookModule.Source = [[
			return {
				storyRoots = {
					script.Parent
				}
			}
		]]
		task.wait()

		expect(changeCount).toEqual(3)
		expect(#storybookModulesQuery.get()).toEqual(1)

		storybookModule.Parent = nil
		task.wait()

		expect(changeCount).toEqual(4)
		expect(#storybookModulesQuery.get()).toEqual(0)
	end)
end)

describe("queue processing", function()
	test("processes items when they are newly added to the DM", function()
		local root = Instance.new("Folder")

		local storybookModulesQuery = query({
			roots = { root },
			selector = "ModuleScript",
			matcher = isStorybookModule,
			-- watchedProperties = { "Name", "Source" },
		})

		local storyModulesQuery = query({
			roots = { root },
			selector = "ModuleScript",
			matcher = isStoryModule,
			-- watchedProperties = { "Name", "Source" },
		})

		expect(#storybookModulesQuery.get()).toBe(0)
		expect(storybookModulesQuery.getQueueSize()).toBe(0)
		expect(#storyModulesQuery.get()).toBe(0)
		expect(storyModulesQuery.getQueueSize()).toBe(0)

		local storybookModule = new("ModuleScript", {
			Name = "Foo.storybook",
			Source = [[
				return {
					storyRoots = {
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
		expect(storybookModulesQuery.getQueueSize()).toBe(1)
		expect(#storyModulesQuery.get()).toBe(0)
		expect(storyModulesQuery.getQueueSize()).toBe(2)

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
					storyRoots = {
						script.Parent
					}
				}
			]],
		})

		local storybookModulesQuery = query({
			roots = { root },
			selector = "ModuleScript",
			matcher = isStorybookModule,
			-- watchedProperties = { "Name", "Source" },
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
				storyRoots = {
					script.Parent
				}
			}
		]]

		local storybookModulesQuery = query({
			roots = { root },
			selector = "ModuleScript",
			matcher = isStorybookModule,
			-- watchedProperties = { "Name", "Source" },
		})

		storybookModule.Parent = root

		storybookModulesQuery.flush()

		expect(storybookModulesQuery.getQueueSize()).toBe(0)

		storybookModule.Name = "Bar.storybook"
		storybookModule.Source = [[
			return {
				storyRoots = {
					script.Parent.Parent
				}
			}
		]]

		expect(storybookModulesQuery.getQueueSize()).toBe(1)

		storybookModulesQuery.flush()

		expect(storybookModulesQuery.getQueueSize()).toBe(0)
	end)
end)
