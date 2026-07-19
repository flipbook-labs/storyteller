local JestGlobals = require("@pkg/JestGlobals")

local new = require("@root/test-utils/new")
local waitFor = require("@root/test-utils/waitFor")

local StorytellerStore = require("./StorytellerStore")
local types = require("@root/types")

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test
local afterEach = JestGlobals.afterEach

type StoryModuleTarget = {
	storyModule: ModuleScript,
	storybook: types.LoadedStorybook,
}

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
	store.start()

	waitFor(function()
		expect(store.getStoryModules()).toEqual(expect.arrayContaining({ storyA, storyB, storyC, storyD }))
		expect(store.getStorybookModules()).toEqual(expect.arrayContaining({ storybookA, storybookB }))
	end)
end)

test("discovers hundreds of story modules without loading them", function()
	local root = Instance.new("Folder")
	local loadCount = Instance.new("IntValue")
	loadCount.Name = "LoadCount"
	loadCount.Parent = root

	for index = 1, 250 do
		local storyModule = Instance.new("ModuleScript")
		storyModule.Name = `Story{index}.story`
		storyModule.Source = [[
			script.Parent.LoadCount.Value += 1
			return {
				story = function() end,
			}
		]]
		storyModule.Parent = root
	end

	store = StorytellerStore.new(root)
	store.start()

	waitFor(function()
		expect(#store.getStoryModules()).toBe(250)
	end)

	expect(loadCount.Value).toBe(0)
	local firstRecord = next(store.getStoryModuleRecords())
	expect(firstRecord).toBeUndefined()
end)

test("creates the shared game store lazily and caches it", function()
	local StorytellerStoreModule = require(script.Parent.StorytellerStore) :: any

	-- The instance must not exist as a plain field: requiring the module
	-- cannot construct a store, only accessing the instance may.
	expect(rawget(StorytellerStoreModule, "instance")).toBeUndefined()

	local first = StorytellerStoreModule.instance
	store = first
	expect(first).toBeDefined()
	expect(StorytellerStoreModule.instance).toBe(first)
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
	store.start()

	waitFor(function()
		expect(#store.getLoadedStorybooks()).toBe(1)
		expect(#store.getUnavailableStorybooks()).toBe(2)
	end)
end)

describe("recomputing Story and Storybook modules", function()
	test("never recomputes when a non-matching ModuleScript is added or removed", function()
		local root = new("Folder")

		store = StorytellerStore.new(root)
		store.start()

		waitFor(function()
			expect(#store.getStoryModules()).toBe(0)
			expect(#store.getStorybookModules()).toBe(0)
		end)

		-- Any time a ModuleScript gets added or removed from the DM, or its Name or
		-- Source changes, we need to recompute the Story and Storybook modules

		local prevStoryModules = store.getStoryModules()
		local prevStorybookModules = store.getStorybookModules()

		local moduleScript = new("ModuleScript")

		moduleScript.Parent = root

		-- The new ModuleScript doesn't match either query yet, so we expect no
		-- changes
		waitFor(function()
			expect(store.getStoryModules()).toBe(prevStoryModules)
			expect(#store.getStoryModules()).toBe(0)
			expect(store.getStorybookModules()).toBe(prevStorybookModules)
			expect(#store.getStorybookModules()).toBe(0)
		end)

		moduleScript.Parent = nil

		-- Same as before. Non-matching ModuleScript was removed, so no changes
		-- necessary
		waitFor(function()
			expect(store.getStoryModules()).toBe(prevStoryModules)
			expect(#store.getStoryModules()).toBe(0)
			expect(store.getStorybookModules()).toBe(prevStorybookModules)
			expect(#store.getStorybookModules()).toBe(0)
		end)
	end)

	test("recomputes when a Story module is added or removed", function()
		local root = new("Folder")

		store = StorytellerStore.new(root)
		store.start()

		expect(#store.getStoryModules()).toBe(0)

		local prevStoryModules = store.getStoryModules()

		local moduleScript = Instance.new("ModuleScript")

		moduleScript.Parent = root
		task.wait()

		-- A new ModuleScript was added which means we need to recalculate the
		-- Story modules, but since the ModuleScript has no Story
		-- characteristics we still get back 0 modules and the same table
		local storyModules = store.getStoryModules()
		expect(#storyModules).toBe(0)
		expect(storyModules).toBe(prevStoryModules)
		prevStoryModules = storyModules

		moduleScript.Name = "Foo.story"

		-- The ModuleScript was renamed to become a Story. That's all that's
		-- needed to get picked up
		waitFor(function()
			storyModules = store.getStoryModules()
			expect(#storyModules).toBe(1)
			expect(storyModules).never.toBe(prevStoryModules)
		end)
		prevStoryModules = storyModules

		moduleScript.Parent = nil

		waitFor(function()
			storyModules = store.getStoryModules()
			expect(#storyModules).toBe(0)
			expect(storyModules).never.toBe(prevStoryModules)
		end)
	end)

	test("recomputes when a Storybook module is added or removed", function()
		local root = new("Folder")

		store = StorytellerStore.new(root)
		store.start()

		expect(#store.getStorybookModules()).toBe(0)

		local prevStorybookModules = store.getStorybookModules()

		local moduleScript = Instance.new("ModuleScript")

		moduleScript.Parent = root
		task.wait()

		-- A new ModuleScript was added which means we need to recalculate the
		-- Storybook modules, but since the ModuleScript has no Storybook
		-- characteristics we still get back 0 modules
		local storybookModules = store.getStorybookModules()
		expect(#storybookModules).toBe(0)
		expect(storybookModules).toBe(prevStorybookModules)
		prevStorybookModules = storybookModules

		moduleScript.Name = "Foo.storybook"

		-- The ModuleScript was renamed to become a Storybook. That's all that's
		-- needed to get picked up
		waitFor(function()
			storybookModules = store.getStorybookModules()
			expect(#storybookModules).toBe(1)
			expect(storybookModules).never.toBe(prevStorybookModules)
		end)
		prevStorybookModules = storybookModules

		moduleScript.Parent = nil

		waitFor(function()
			storybookModules = store.getStorybookModules()
			expect(#storybookModules).toBe(0)
			expect(storybookModules).never.toBe(prevStorybookModules)
		end)
	end)
end)

describe("user journeys", function()
	-- This captures a common user journey where a blank ModuleScript is
	-- inserted by the user, renamed to "Foo.storybook," and then filled out
	-- the contents so it becomes a valid storybook
	test("creating a new Storybook in Studio", function()
		local root = new("Folder")

		store = StorytellerStore.new(root)
		store.start()

		waitFor(function()
			expect(#store.getLoadedStorybooks()).toEqual(0)
			expect(#store.getUnavailableStorybooks()).toEqual(0)
		end)

		local storybookModule = Instance.new("ModuleScript")

		storybookModule.Parent = root

		waitFor(function()
			expect(#store.getLoadedStorybooks()).toEqual(0)
			expect(#store.getUnavailableStorybooks()).toEqual(0)
		end)

		storybookModule.Name = "Foo.storybook"

		waitFor(function()
			expect(#store.getLoadedStorybooks()).toEqual(0)
			expect(#store.getUnavailableStorybooks()).toEqual(1)
		end)

		storybookModule.Source = [[
			return {
				storyRoots = {
					script.Parent
				}
			}
		]]

		waitFor(function()
			expect(#store.getLoadedStorybooks()).toEqual(1)
			expect(#store.getUnavailableStorybooks()).toEqual(0)
		end)

		storybookModule.Parent = nil

		waitFor(function()
			expect(#store.getLoadedStorybooks()).toEqual(0)
			expect(#store.getUnavailableStorybooks()).toEqual(0)
		end)
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
		store.start()

		waitFor(function()
			expect(#store.getLoadedStorybooks()).toBe(1)
			expect(store.getOrphanedStoryModules()).toEqual({ storyB })
		end)
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
		store.start()

		waitFor(function()
			expect(#store.getLoadedStorybooks()).toBe(2)
			expect(store.getOrphanedStoryModules()).toEqual({})
		end)
	end)

	test("returns all story modules when no storybooks are present", function()
		local root = new("Folder")

		for _ = 1, 5 do
			local storyModule = Instance.new("ModuleScript")
			storyModule.Name = "Story.story"
			storyModule.Parent = root
		end

		store = StorytellerStore.new(root)
		store.start()

		waitFor(function()
			expect(#store.getOrphanedStoryModules()).toBe(5)
		end)
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
		store.start()

		waitFor(function()
			expect(store.getOrphanedStoryModules()).toEqual({ storybookModule, storyModuleB })
		end)
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
		store.start()

		waitFor(function()
			expect(#store.getLoadedStorybooks()).toBe(1)
			expect(store.getOrphanedStoryModules()).toEqual({})
		end)

		storyA.Parent = root

		waitFor(function()
			expect(store.getOrphanedStoryModules()).toEqual({ storyA })
		end)
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
		store.start()

		waitFor(function()
			expect(#store.getLoadedStorybooks()).toBe(1)
			expect(store.getOrphanedStoryModules()).toEqual({})
		end)

		storybookModule.Parent = nil

		waitFor(function()
			expect(#store.getLoadedStorybooks()).toBe(0)
			expect(store.getOrphanedStoryModules()).toEqual({ storyA, storyB })
		end)
	end)
end)

describe("requesting story modules", function()
	-- Request lifecycle behavior (sharing, priority, invalidation, cleanup)
	-- is covered by StoryModuleRecordStore.spec. These tests pin the
	-- composition between the store and the record store it delegates to.
	local function createTarget(name: string): StoryModuleTarget
		local storyModule = Instance.new("ModuleScript")
		storyModule.Name = `{name}.story`
		storyModule.Source = `return \{ name = "{name}", story = function() end \}`

		return {
			storyModule = storyModule,
			storybook = {
				name = "Storybook",
				source = Instance.new("ModuleScript"),
				storyRoots = {},
			},
		}
	end

	local function getRecord(target: StoryModuleTarget)
		local recordsForModule = store.getStoryModuleRecords()[target.storyModule]
		return if recordsForModule then recordsForModule[target.storybook.source] else nil
	end

	test("serves requests through the record store", function()
		store = StorytellerStore.new(new("Folder"))
		local target = createTarget("Delegated")

		store.requestStoryModules({ target })

		waitFor(function()
			local record = getRecord(target)
			assert(record and record.stories, "expected a loaded record for the requested story module")
			expect(record.stories[1].name).toBe("Delegated")
		end)
	end)

	test("clears records when the store is destroyed", function()
		store = StorytellerStore.new(new("Folder"))
		local target = createTarget("Ephemeral")

		store.requestStoryModules({ target })

		waitFor(function()
			expect(getRecord(target)).toBeDefined()
		end)

		store.destroy()

		local firstKey = next(store.getStoryModuleRecords())
		expect(firstKey).toBeUndefined()
	end)
end)
