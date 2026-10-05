local JestGlobals = require("@pkg/JestGlobals")

local waitFor = require("@root/test-utils/waitFor")

local observeModuleCollection = require("./observeModuleCollection")

local afterEach = JestGlobals.afterEach
local expect = JestGlobals.expect
local test = JestGlobals.test

type ModuleCollection = observeModuleCollection.ModuleCollection

local root: Folder
local collection: ModuleCollection
local members: { Instance }
local snapshots: { { Instance } }
local destroyCount: number
local dispose: (() -> ())?

JestGlobals.beforeEach(function()
	root = Instance.new("Folder")
	members = {}
	snapshots = {}
	destroyCount = 0
	collection = {
		OnPropertyChanged = {},
		ForEach = function(_, callback)
			for _, member in members do
				callback(member)
			end
		end,
		Destroy = function()
			destroyCount += 1
		end,
	}
end)

afterEach(function()
	if dispose then
		dispose()
		dispose = nil
	end
	root:Destroy()
end)

local function recordSnapshot(snapshot: { Instance })
	table.insert(snapshots, snapshot)
end

test("coalesces additions into one snapshot and publishes nothing while idle", function()
	dispose = observeModuleCollection(collection, root, recordSnapshot)

	for _ = 1, 100 do
		local module = Instance.new("ModuleScript")
		module.Parent = root
		table.insert(members, module)
		assert(collection.OnAdded, "expected an added callback")
		collection.OnAdded(module)
	end

	waitFor(function()
		expect(#snapshots).toBe(1)
	end)
	expect(snapshots[1]).toEqual(members)

	task.wait(0.5)
	expect(#snapshots).toBe(1)
end)

test("republishes renamed members and removes departed members", function()
	local module = Instance.new("ModuleScript")
	module.Parent = root
	table.insert(members, module)
	dispose = observeModuleCollection(collection, root, recordSnapshot)

	waitFor(function()
		expect(#snapshots).toBe(1)
	end)

	module.Name = "Example.story"
	assert(collection.OnPropertyChanged.Name, "expected a name callback")
	collection.OnPropertyChanged.Name(module)

	waitFor(function()
		expect(#snapshots).toBe(2)
	end)
	expect(snapshots[2]).toEqual({ module })
	expect(snapshots[2]).never.toBe(snapshots[1])

	table.clear(members)
	assert(collection.OnRemoved, "expected a removed callback")
	collection.OnRemoved(module)

	waitFor(function()
		expect(snapshots[3]).toEqual({})
	end)
end)

test("includes a ModuleScript root once and observes its name", function()
	local module = Instance.new("ModuleScript")
	module.Parent = root
	table.insert(members, module)
	dispose = observeModuleCollection(collection, module, recordSnapshot)

	waitFor(function()
		expect(snapshots[1]).toEqual({ module })
	end)

	module.Name = "Root.storybook"
	waitFor(function()
		expect(#snapshots).toBe(2)
	end)
end)

test("destroy cancels pending snapshots and ignores late collection callbacks", function()
	local destroy = observeModuleCollection(collection, root, recordSnapshot)
	dispose = destroy
	destroy()
	destroy()

	assert(collection.OnAdded, "expected an added callback")
	collection.OnAdded(root)
	task.wait(0.5)

	expect(snapshots).toEqual({})
	expect(destroyCount).toBe(1)
end)
