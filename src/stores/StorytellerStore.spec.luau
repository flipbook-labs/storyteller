local JestGlobals = require("@pkg/JestGlobals")

local new = require("@root/test-utils/new")

local StorytellerStore = require("./StorytellerStore")

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test
local afterEach = JestGlobals.afterEach

local store

afterEach(function()
	store.destroy()
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

	store = StorytellerStore.new(root)

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

	store = StorytellerStore.new(root)

	expect(#store.getLoadedStorybooks(false)).toBe(1)
	expect(#store.getUnavailableStorybooks(false)).toBe(2)
end)

describe("recomputing Story and Storybook modules", function()
	test("never recomputes when a non-matching ModuleScript is added or removed", function()
		local root = new("Folder")

		store = StorytellerStore.new(root)

		expect(#store.getStoryModules(false)).toBe(0)
		expect(#store.getStorybookModules(false)).toBe(0)

		-- Any time a ModuleScript gets added or removed from the DM, or its Name or
		-- Source changes, we need to recompute the Story and Storybook modules

		local prevStoryModules = store.getStoryModules(false)
		local prevStorybookModules = store.getStorybookModules(false)

		local moduleScript = new("ModuleScript")

		moduleScript.Parent = root
		task.wait()

		-- The new ModuleScript doesn't match either query yet, so we expect no
		-- changes
		expect(store.getStoryModules(false)).toBe(prevStoryModules)
		expect(#store.getStoryModules(false)).toBe(0)
		expect(store.getStorybookModules(false)).toBe(prevStorybookModules)
		expect(#store.getStorybookModules(false)).toBe(0)

		moduleScript.Parent = nil
		task.wait()

		-- Same as before. Non-matching ModuleScript was removed, so no changes
		-- necessary
		expect(store.getStoryModules(false)).toBe(prevStoryModules)
		expect(#store.getStoryModules(false)).toBe(0)
		expect(store.getStorybookModules(false)).toBe(prevStorybookModules)
		expect(#store.getStorybookModules(false)).toBe(0)
	end)

	test("recomputes when a Story module is added or removed", function()
		local root = new("Folder")

		store = StorytellerStore.new(root)

		expect(#store.getStoryModules(false)).toBe(0)

		local prevStoryModules = store.getStoryModules(false)

		local moduleScript = Instance.new("ModuleScript")

		moduleScript.Parent = root
		task.wait()

		-- A new ModuleScript was added which means we need to recalculate the
		-- Story modules, but since the ModuleScript has no Story
		-- characteristics we still get back 0 modules and the same table
		local storyModules = store.getStoryModules(false)
		expect(#storyModules).toBe(0)
		expect(storyModules).toBe(prevStoryModules)
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

	test("recomputes when a Storybook module is added or removed", function()
		local root = new("Folder")

		store = StorytellerStore.new(root)

		expect(#store.getStorybookModules(false)).toBe(0)

		local prevStorybookModules = store.getStorybookModules(false)

		local moduleScript = Instance.new("ModuleScript")

		moduleScript.Parent = root
		task.wait()

		-- A new ModuleScript was added which means we need to recalculate the
		-- Storybook modules, but since the ModuleScript has no Storybook
		-- characteristics we still get back 0 modules
		local storybookModules = store.getStorybookModules(false)
		expect(#storybookModules).toBe(0)
		expect(storybookModules).toBe(prevStorybookModules)
		prevStorybookModules = storybookModules

		moduleScript.Name = "Foo.storybook"
		task.wait()

		-- The ModuleScript was renamed to become a Storybook. That's all that's
		-- needed to get picked up
		storybookModules = store.getStorybookModules(false)
		expect(#storybookModules).toBe(1)
		expect(storybookModules).never.toBe(prevStorybookModules)
		prevStorybookModules = storybookModules

		moduleScript.Parent = nil
		task.wait()

		storybookModules = store.getStorybookModules(false)
		expect(#storybookModules).toBe(0)
		expect(storybookModules).never.toBe(prevStorybookModules)
	end)
end)

describe("user journeys", function()
	-- This captures a common user journey where a blank ModuleScript is
	-- inserted by the user, renamed to "Foo.storybook," and then filled out
	-- the contents so it becomes a valid storybook
	test("creating a new Storybook in Studio", function()
		local root = new("Folder")

		store = StorytellerStore.new(root)

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

		storybookModule.Parent = nil
		task.wait()

		expect(#store.getLoadedStorybooks(false)).toEqual(0)
		expect(#store.getUnavailableStorybooks(false)).toEqual(0)
	end)
end)

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
					return {
						storyRoots = {
							script.Parent.FolderA
						}
					}
				]],
			}),
		})

		store = StorytellerStore.new(root)

		expect(#store.getLoadedStorybooks(false)).toBe(1)
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
					return {
						storyRoots = {
							script.Parent.FolderA
						}
					}
				]],
			}),
			["B.storybook"] = new("ModuleScript", {
				Source = [[
					return {
						storyRoots = {
							script.Parent.FolderB
						}
					}
				]],
			}),
		})

		store = StorytellerStore.new(root)

		expect(#store.getLoadedStorybooks(false)).toBe(2)
		expect(store.getOrphanedStoryModules(false)).toEqual({})
	end)

	test("returns all story modules when no storybooks are present", function()
		local root = new("Folder")

		for _ = 1, 5 do
			local storyModule = Instance.new("ModuleScript")
			storyModule.Name = "Story.story"
			storyModule.Parent = root
		end

		store = StorytellerStore.new(root)

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

		store = StorytellerStore.new(root)

		expect(store.getOrphanedStoryModules(false)).toEqual({ storybookModule, storyModuleB })
	end)

	test("updates when a story moves around the DataModel", function()
		local storyA = new("ModuleScript")
		local storyB = new("ModuleScript")

		local root = new("Folder", nil, {
			Folder = new("Folder", nil, {
				["A.story"] = storyA,
				["B.story"] = storyB,
			}),
			["Foo.storybook"] = new("ModuleScript", {
				Source = [[
					return {
						storyRoots = {
							script.Parent.Folder
						}
					}
				]],
			}),
		})

		store = StorytellerStore.new(root)

		expect(#store.getLoadedStorybooks(false)).toBe(1)
		expect(store.getOrphanedStoryModules(false)).toEqual({})

		storyA.Parent = root
		task.wait()

		expect(store.getOrphanedStoryModules(false)).toEqual({ storyA })
	end)

	test("updates when a storybook is removed", function()
		local storyA = new("ModuleScript")
		local storyB = new("ModuleScript")

		local storybookModule = new("ModuleScript", {
			Source = [[
				return {
					storyRoots = {
						script.Parent
					}
				}
			]],
		})

		local root = new("Folder", nil, {
			["A.story"] = storyA,
			["B.story"] = storyB,
			["Foo.storybook"] = storybookModule,
		})

		store = StorytellerStore.new(root)

		expect(#store.getLoadedStorybooks(false)).toBe(1)
		expect(store.getOrphanedStoryModules(false)).toEqual({})

		storybookModule.Parent = nil
		task.wait()

		expect(#store.getLoadedStorybooks(false)).toBe(0)
		expect(store.getOrphanedStoryModules(false)).toEqual({ storyA, storyB })
	end)
end)
