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

		-- Rename now correctly enqueues via the Changed connection set up on
		-- the first flush.
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
