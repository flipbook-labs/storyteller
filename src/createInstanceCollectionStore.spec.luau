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

	local snapshot = partCollection.getMatches(false)

	expect(snapshot).toEqual(expect.arrayContaining({
		partA,
		partB,
	}))

	partB.Parent = partA.Parent
	waitForEvents()

	-- The identities should be equal
	expect(snapshot == partCollection.getMatches(false)).toBe(true)

	partA.Parent = partB.Parent
	waitForEvents()

	-- Same thing. No changes to the collected instances since they're still
	-- descendants of the root. Identities should still match
	expect(snapshot == partCollection.getMatches(false)).toBe(true)

	-- Now we remove the part from the root, which should trigger an update
	partA.Parent = nil
	waitForEvents()

	expect(snapshot == partCollection.getMatches(false)).toBe(false)
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

	expect(partCollection.getMatches(false)).toEqual(expect.arrayContaining({
		partA,
		partB,
	}))

	local folder = new("Folder", nil, {
		PartC = partC,
	})

	folder.Parent = partA.Parent
	waitForEvents()

	expect(partCollection.getMatches(false)).toEqual(expect.arrayContaining({
		partA,
		partB,
		partC,
	}))
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

	expect(partCollection.getMatches(false)).toEqual({ partA })

	-- Waiting for the initial PartA.Changed event to be connected
	waitForEvents()

	partA.Name = "NoLongerMatches"
	waitForEvents()

	expect(partCollection.getMatches(false)).toEqual({})
end)

test("stress testing", function()
	local maxInstances = 1e6
	local maxDepth = 20

	local root = Instance.new("Folder")
	local currentDepth = 1
	local currentParent = root

	local leaves = {}

	for _ = 1, maxInstances do
		local shouldBranch = currentDepth == maxDepth

		local instance = Instance.new("Folder")

		if shouldBranch then
			instance.Parent = root
			currentDepth = 1
			table.insert(leaves, currentParent)
		else
			instance.Parent = currentParent
			currentDepth += 1
		end

		currentParent = instance
	end

	expect(#root:GetDescendants()).toBe(maxInstances)

	for _, leaf in leaves do
		local part = Instance.new("Part")
		part.Parent = leaf
	end

	local partCollection = createInstanceCollectionStore(root, "Part")

	expect(#partCollection.getMatches(false)).toEqual(#leaves)
end)
