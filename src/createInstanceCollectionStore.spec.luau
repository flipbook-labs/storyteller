local JestGlobals = require("@pkg/JestGlobals")

local isStoryModule = require("@root/isStoryModule")
local isStorybookModule = require("@root/isStorybookModule")
local new = require("@root/test-utils/new")

local createInstanceCollectionStore = require("./createInstanceCollectionStore")

local expect = JestGlobals.expect
local test = JestGlobals.test

-- TODO: Create a giant instance tree (100k instances or so?) to stress test it

test("satisfies Story and Storybook use case", function()
	local storybookModule = new("ModuleScript", {
		Source = [[
			return {
				storyRoots = {
					script.Parent
				}
			}
		]],
	})

	local templateStoryModule = new("ModuleScript", {
		Source = [[
			return {
				story = function() end
			}
		]],
	})

	local storyModuleA = templateStoryModule:Clone()
	local storyModuleB = templateStoryModule:Clone()
	local storyModuleC = templateStoryModule:Clone()
	local storyModuleD = templateStoryModule:Clone()

	local root = new("Folder", {}, {
		["Folder"] = new("Folder", {}, {
			["Sample.storybook"] = storybookModule,
			["A.story"] = storyModuleA,
			["Folder"] = new("Folder", {}, {
				["B.story"] = storyModuleB,
			}),
		}),
		["C.story"] = storyModuleC,
		["D.story"] = storyModuleD,
	})

	local instanceCollectionsStore = createInstanceCollectionStore()

	local getStories = instanceCollectionsStore.createCollection(isStoryModule)
	local getStorybooks = instanceCollectionsStore.createCollection(isStorybookModule)

	expect(getStories(false)).toEqual({})
	expect(getStorybooks(false)).toEqual({})

	instanceCollectionsStore.collect(root)

	expect(getStories(false)).toEqual(expect.arrayContaining({
		storyModuleA,
		storyModuleB,
		storyModuleC,
		storyModuleD,
	}))
	expect(getStorybooks(false)).toEqual({ storybookModule })
end)

test("does nothing so long as the instances stay descendants of the root", function()
	local instanceCollectionsStore = createInstanceCollectionStore()

	local partA = new("Part")
	local partB = new("Part")

	local root = new("Folder", nil, {
		Folder = new("Folder", nil, {
			Folder = new("Folder", nil, {
				Folder = new("Folder", nil, {
					PartA = partA,
				}),
			}),

			PartB = partB,
		}),
	})

	local getParts = instanceCollectionsStore.createCollection(function(instance)
		return instance:IsA("BasePart")
	end)

	expect(getParts(false)).toEqual({})

	instanceCollectionsStore.collect(root)

	local snapshot = getParts(false)

	expect(snapshot).toEqual(expect.arrayContaining({
		partA,
		partB,
	}))

	partB.Parent = partA.Parent

	-- The identities should be equal
	expect(getParts(false)).toBe(snapshot)

	partA.Parent = partB.Parent

	-- Same thing. No changes to the collected instances since they're still
	-- descendants of the root. Identities should still match
	expect(getParts(false)).toBe(snapshot)

	-- Now we remove the part from the root, which should trigger an update
	partA.Parent = nil

	expect(getParts(false)).never.toBe(snapshot)
	expect(getParts(false)).toEqual({ partB })
end)

test("updates when adding/removing instances from the DataModel", function()
	local instanceCollectionsStore = createInstanceCollectionStore()

	local partA = new("Part")
	local partB = new("Part")
	local partC = new("Part")

	local root = new("Folder", nil, {
		Folder = new("Folder", nil, {
			Folder = new("Folder", nil, {
				Folder = new("Folder", nil, {
					PartA = partA,
				}),
			}),

			PartB = partB,
		}),
	})

	local getParts = instanceCollectionsStore.createCollection(function(instance)
		return instance:IsA("BasePart")
	end)

	expect(getParts(false)).toEqual({})

	instanceCollectionsStore.collect(root)

	local snapshot = getParts(false)

	local folder = new("Folder", nil, {
		PartC = partC,
	})

	folder.Parent = partA.Parent

	expect(snapshot).never.toBe(getParts(false))
	expect(getParts(false)).toEqual(expect.arrayContaining({ partA, partB, partC }))
end)
