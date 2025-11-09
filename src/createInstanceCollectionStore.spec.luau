local RunService = game:GetService("RunService")
local JestGlobals = require("@pkg/JestGlobals")

local isStoryModule = require("@root/isStoryModule")
local isStorybookModule = require("@root/isStorybookModule")
local new = require("@root/test-utils/new")

local createInstanceCollectionStore = require("./createInstanceCollectionStore")

local expect = JestGlobals.expect
local test = JestGlobals.test

local function waitForEvents()
	RunService.Heartbeat:Wait()
end

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

	local storyCollection = createInstanceCollectionStore(root, "ModuleScript", isStoryModule)
	local storybookCollection = createInstanceCollectionStore(root, "ModuleScript", isStorybookModule)

	expect(storyCollection.getMatches(false)).toEqual({})
	expect(storybookCollection.getMatches(false)).toEqual({})

	storyCollection.collect()
	storybookCollection.collect()

	expect(storyCollection.getMatches(false)).toEqual(expect.arrayContaining({
		storyModuleA,
		storyModuleB,
		storyModuleC,
		storyModuleD,
	}))
	expect(storybookCollection.getMatches(false)).toEqual({ storybookModule })
end)

test("never updates so long as the instances stay descendants of the root", function()
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

	local partCollection = createInstanceCollectionStore(root, "Part")

	expect(partCollection.getMatches(false)).toEqual({})

	partCollection.collect()

	local snapshot = partCollection.getMatches(false)

	expect(snapshot).toEqual(expect.arrayContaining({
		partA,
		partB,
	}))

	partB.Parent = partA.Parent
	waitForEvents()

	-- The identities should be equal
	expect(partCollection.getMatches(false)).toBe(snapshot)

	partA.Parent = partB.Parent
	waitForEvents()

	-- Same thing. No changes to the collected instances since they're still
	-- descendants of the root. Identities should still match
	expect(partCollection.getMatches(false)).toBe(snapshot)

	-- Now we remove the part from the root, which should trigger an update
	partA.Parent = nil
	waitForEvents()

	expect(partCollection.getMatches(false)).never.toBe(snapshot)
	expect(partCollection.getMatches(false)).toEqual({ partB })
end)

test("updates when adding/removing instances from the DataModel", function()
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

	local partCollection = createInstanceCollectionStore(root, "Part")

	expect(partCollection.getMatches(false)).toEqual({})

	partCollection.collect()

	local snapshot = partCollection.getMatches(false)

	local folder = new("Folder", nil, {
		PartC = partC,
	})

	folder.Parent = partA.Parent

	expect(snapshot).never.toBe(partCollection.getMatches(false))
	expect(partCollection.getMatches(false)).toBe(expect.arrayContaining({ partA, partB, partC }))
end)

test("recalculates when an existing match has property changes", function()
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

	local partCollection = createInstanceCollectionStore(root, "Part#PartA")

	partCollection.collect()

	expect(partCollection.getMatches(false)).toEqual({ partA })

	partA.Name = "NoLongerMatches"
	waitForEvents()

	expect(partCollection.getMatches(false)).toEqual({})
end)
