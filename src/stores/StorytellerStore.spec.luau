local JestGlobals = require("@pkg/JestGlobals")
local ModuleLoader = require("@pkg/ModuleLoader")

local new = require("@root/test-utils/new")
local types = require("@root/types")

local StorytellerStore = require("./StorytellerStore")

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

-- 1. Listen for all ModuleScripts in the DataModel
-- 2. Filter to just the ones that match the .storybook name
-- 3. Require each one and parse them into a LoadedStorybook or UnavailableStorybook
-- 4. Keep track of an IsLoading state when discovering Storybooks
-- 5. As ModuleScripts get added/removed/renamed or have their Source changed we need to do all these steps again
--    1. useQueryDescendants should already take care of added/removed, so useStorybooks needs to track Name and Source changes

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

	local store = StorytellerStore.new(root)

	expect(store.getStoryModules(false)).toEqual(expect.arrayContaining({ storyA, storyB, storyC, storyD }))
	expect(store.getStorybookModules(false)).toEqual(expect.arrayContaining({ storybookA, storybookB }))
end)

test("parses each Storybook module into a LoadedStorybook or UnavailableStorybook", function()
	local validStorybook = Instance.new("ModuleScript")
	validStorybook.Source = [[
		return {
			storyRoots = {}
		}
	]]

	local storybookThatThrows = Instance.new("ModuleScript")
	storybookThatThrows.Source = [[
		error("Something went wrong!")
	]]

	local invalidStorybook = Instance.new("ModuleScript")
	invalidStorybook.Source = [[
		return {}
	]]

	local root = new("Folder", nil, {
		["ValidStorybook.storybook"] = validStorybook :: Instance,
		["StorybookThatThrows.storybook"] = storybookThatThrows :: Instance,
		["InvalidStorybook.storybook"] = invalidStorybook :: Instance,
	})

	local store = StorytellerStore.new(root)

	expect(#store.getLoadedStorybooks(false)).toBe(1)
	expect(#store.getUnavailableStorybooks(false)).toBe(2)
end)

describe("recomputing Story and Storybook modules", function()
	test("recomputes when any ModuleScript is added or removed", function()
		-- Add to root
		-- Remove from root
		-- Rename
		-- Change source

		local root = new("Folder")

		local store = StorytellerStore.new(root)

		expect(#store.getStoryModules(false)).toBe(0)
		expect(#store.getStorybookModules(false)).toBe(0)

		-- Any time a ModuleScript gets added or removed from the DM, or its Name or
		-- Source changes, we need to recompute the Story and Storybook modules

		local prevStoryModules = store.getStoryModules(false)
		local prevStorybookModules = store.getStorybookModules(false)

		local moduleScript = new("ModuleScript")

		moduleScript.Parent = root
		task.wait()

		-- Verify that the identities changed (and thus were recomputed) and that we
		-- still have 0 Stories and Storybooks
		expect(store.getStoryModules(false)).never.toBe(prevStoryModules)
		expect(#store.getStoryModules(false)).toBe(0)
		expect(store.getStorybookModules(false)).never.toBe(prevStorybookModules)
		expect(#store.getStorybookModules(false)).toBe(0)

		prevStoryModules = store.getStoryModules(false)
		prevStorybookModules = store.getStorybookModules(false)

		moduleScript.Parent = nil
		task.wait()

		-- Same as before. The ModuleScript was removed so we need to recompute,
		-- but there shouldn't be any change to the sizes
		expect(store.getStoryModules(false)).never.toBe(prevStoryModules)
		expect(#store.getStoryModules(false)).toBe(0)
		expect(store.getStorybookModules(false)).never.toBe(prevStorybookModules)
		expect(#store.getStorybookModules(false)).toBe(0)
	end)

	test("recomputes when a Story module is added or removed", function()
		local root = new("Folder")

		local store = StorytellerStore.new(root)

		expect(#store.getStoryModules(false)).toBe(0)

		local prevStoryModules = store.getStoryModules(false)

		local moduleScript = Instance.new("ModuleScript")

		moduleScript.Parent = root
		task.wait()

		-- A new ModuleScript was added which means we need to recalculate the
		-- Story modules, but since the ModuleScript has no Story
		-- characteristics we still get back 0 modules
		local storyModules = store.getStoryModules(false)
		expect(#storyModules).toBe(0)
		expect(storyModules).never.toBe(prevStoryModules)
		prevStoryModules = storyModules

		moduleScript.Name = "Foo.story"
		task.wait()

		-- The ModuleScript was renamed to become a Story. That's all that's
		-- needed to get picked up
		storyModules = store.getStoryModules(false)
		expect(#storyModules).toBe(1)
		expect(storyModules).never.toBe(prevStoryModules)
		prevStoryModules = storyModules

		moduleScript.Parent = nil
		task.wait()

		storyModules = store.getStoryModules(false)
		expect(#storyModules).toBe(0)
		expect(storyModules).never.toBe(prevStoryModules)
	end)

	test("recomputes when a Storybook module is added or removed", function() end)
end)

describe("user journeys", function()
	-- This captures a common user journey where a blank ModuleScript is
	-- inserted by the user, renamed to "Foo.storybook," and then filled out
	-- the contents so it becomes a valid storybook
	test("creating a new Storybook in Studio", function()
		local root = new("Folder")

		local store = StorytellerStore.new(root)

		expect(#store.getLoadedStorybooks(false)).toEqual(0)
		expect(#store.getUnavailableStorybooks(false)).toEqual(0)

		local storybookModule = Instance.new("ModuleScript")

		storybookModule.Parent = root
		task.wait()

		expect(#store.getLoadedStorybooks(false)).toEqual(0)
		expect(#store.getUnavailableStorybooks(false)).toEqual(0)

		storybookModule.Name = "Foo.storybook"
		task.wait()

		expect(#store.getLoadedStorybooks(false)).toEqual(0)
		expect(#store.getUnavailableStorybooks(false)).toEqual(1)

		storybookModule.Source = [[
			return {
				storyRoots = {
					script.Parent
				}
			}
		]]
		task.wait()

		expect(#store.getLoadedStorybooks(false)).toEqual(1)
		expect(#store.getUnavailableStorybooks(false)).toEqual(0)
	end)
end)

-- test("stops listening once destroyed", function() end)

describe("orphaned stories", function()
	test("finds all Story modules that aren't managed by a Storybook", function()
		local storyB = new("ModuleScript")

		local root = new("Folder", nil, {
			FolderA = new("Folder", nil, {
				["A.story"] = new("ModuleScript"),
			}),
			FolderB = new("Folder", nil, {
				["B.story"] = storyB,
			}),
			["Foo.storybook"] = new("ModuleScript", {
				Source = [[
					storyRoots = {
						script.Parent.FolderA
					}
				]],
			}),
		})

		local store = StorytellerStore.new(root)

		expect(store.getOrphanedStoryModules(false)).toEqual({ storyB })
	end)

	test("returns empty list when all Story modules are managed by Storybooks", function()
		local root = new("Folder", nil, {
			FolderA = new("Folder", nil, {
				["A.story"] = new("ModuleScript"),
			}),
			FolderB = new("Folder", nil, {
				["B.story"] = new("ModuleScript"),
			}),
			["A.storybook"] = new("ModuleScript", {
				Source = [[
					storyRoots = {
						script.Parent.FolderA
					}
				]],
			}),
			["B.storybook"] = new("ModuleScript", {
				Source = [[
					storyRoots = {
						script.Parent.FolderB
					}
				]],
			}),
		})

		local store = StorytellerStore.new(root)

		expect(store.getOrphanedStoryModules(false)).toEqual({})
	end)

	test("returns all story modules when no storybooks are present", function()
		local root = new("Folder")

		for _ = 1, 5 do
			local storyModule = Instance.new("ModuleScript")
			storyModule.Name = "Story.story"
			storyModule.Parent = root
		end

		local store = StorytellerStore.new(root)

		expect(#store.getOrphanedStoryModules(false)).toBe(5)
	end)

	test("keeps going after hitting a story along the way", function()
		local root = new("Folder")

		local storybookModule = Instance.new("ModuleScript")
		storybookModule.Name = "StoryA.story"
		storybookModule.Parent = root

		-- Add Folders above the root to build out a nested hierarchy
		for _ = 1, 5 do
			local folder = Instance.new("Folder")
			root.Parent = folder
			root = folder
		end

		-- Place a story in the middle to make sure StoryB will still get picked up
		local storyModuleB = Instance.new("ModuleScript")
		storyModuleB.Name = "StoryB.story"
		storyModuleB.Parent = root

		for _ = 1, 5 do
			local folder = Instance.new("Folder")
			root.Parent = folder
			root = folder
		end

		local store = StorytellerStore.new(root)

		expect(store.getOrphanedStoryModules(false)).toEqual({ storybookModule, storyModuleB })
	end)
end)
