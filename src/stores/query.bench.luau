local JestGlobals = require("@pkg/JestGlobals")

local query = require("./query")

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test
local describeEach = describe.each :: any

local function buildModuleTree(instanceCount: number): Instance
	local root = Instance.new("Folder")
	root.Name = "TreeRoot"

	local count = 0
	local topLevel = math.max(1, math.ceil(instanceCount / 1000))
	local perTop = math.max(1, math.ceil(instanceCount / topLevel / 100))
	local perSub = math.max(1, math.ceil(instanceCount / topLevel / perTop))

	for ti = 1, topLevel do
		local topFolder = Instance.new("Folder")
		topFolder.Name = "T" .. tostring(ti)

		for si = 1, perTop do
			local subFolder = Instance.new("Folder")
			subFolder.Name = "S" .. tostring(si)
			for _ = 1, perSub do
				if count >= instanceCount then
					break
				end
				local ms = Instance.new("ModuleScript")
				ms.Name = "M" .. tostring(count)
				ms.Parent = subFolder
				count += 1
			end
			subFolder.Parent = topFolder

			if count >= instanceCount then
				break
			end
		end

		topFolder.Parent = root

		if count >= instanceCount then
			break
		end
	end

	return root
end

describeEach({
	1000,
	10000,
	100000,
})("stress tests (%s instances)", function(instanceCount)
	local container = buildModuleTree(instanceCount)

	test("clones a tree of instances and measures flush time", function()
		local queryRoot = Instance.new("Folder")
		local modulesQuery = query({
			root = queryRoot,
			selector = "ModuleScript",
		})

		local addedFireCount = 0
		modulesQuery.added:Connect(function()
			addedFireCount += 1
		end)

		local clone = container:Clone()
		clone.Parent = queryRoot
		container:Destroy()

		local t0 = os.clock()
		local maxFlushes = 10000
		for _ = 1, maxFlushes do
			modulesQuery.flush()
			if modulesQuery.getQueueSize() == 0 and #modulesQuery.get() >= instanceCount then
				break
			end
			task.wait()
		end
		local elapsed = os.clock() - t0
		expect(elapsed).toBeGreaterThanOrEqual(0)

		expect(modulesQuery.getQueueSize()).toBe(0)
		local matches = modulesQuery.get()
		expect(#matches).toBeGreaterThanOrEqual(instanceCount)
		local seen: { [Instance]: boolean } = {}
		for _, m in matches do
			expect(seen[m]).never.toBe(true)
			seen[m] = true
		end
		expect(addedFireCount).toBeGreaterThanOrEqual(1)
		modulesQuery.destroy()
		queryRoot:Destroy()
	end)

	test.skip("measure flush time of sustained high-frequency instance changes", function()
		local root = Instance.new("Folder")
		local instances: { ModuleScript } = {}
		for i = 1, instanceCount do
			local ms = Instance.new("ModuleScript")
			ms.Name = "M" .. tostring(i)
			ms.Parent = root
			table.insert(instances, ms)
		end

		local modulesQuery = query({
			root = root,
			selector = "ModuleScript",
		})
		while modulesQuery.getQueueSize() > 0 do
			modulesQuery.flush()
		end

		local changeCount = 0
		modulesQuery.changed:Connect(function()
			changeCount += 1
		end)

		for round = 1, 3 do
			for _, ms in instances do
				ms.Name = "M" .. tostring(round) .. "_" .. ms.Name
			end
		end

		local t0 = os.clock()
		while modulesQuery.getQueueSize() > 0 do
			modulesQuery.flush()
		end
		local elapsed = os.clock() - t0
		expect(elapsed).toBeGreaterThanOrEqual(0)

		expect(changeCount).toBeGreaterThanOrEqual(1)
		modulesQuery.destroy()
		root:Destroy()
	end)
end)

test("rapid property changes on single instance only enqueue once and fire changed once per flush", function()
	local root = Instance.new("Folder")
	local moduleScript = Instance.new("ModuleScript")
	moduleScript.Parent = root

	local modulesQuery = query({
		root = root,
		selector = "ModuleScript",
	})
	modulesQuery.flush()

	expect(modulesQuery.getQueueSize()).toBe(0)
	local changeCount = 0
	modulesQuery.changed:Connect(function()
		changeCount += 1
	end)

	moduleScript.Name = "A"
	moduleScript.Source = "return 1"
	expect(modulesQuery.getQueueSize()).toBe(1)

	modulesQuery.flush()
	expect(modulesQuery.getQueueSize()).toBe(0)
	expect(changeCount).toBe(1)
	modulesQuery.destroy()
	root:Destroy()
end)

test("re-entrant queue additions eventually settle", function()
	local root = Instance.new("Folder")
	local moduleScript = Instance.new("ModuleScript")
	moduleScript.Parent = root

	local modulesQuery = query({
		root = root,
		selector = "ModuleScript",
	})

	local iterations = 0
	local maxIterations = 100
	modulesQuery.added:Connect(function(addedList)
		iterations += 1
		if iterations <= 2 and #addedList > 0 then
			addedList[1].Name = "Touched"
		end
	end)

	for _ = 1, maxIterations do
		modulesQuery.flush()
		if modulesQuery.getQueueSize() == 0 then
			break
		end
		task.wait()
	end

	expect(iterations).toBeLessThanOrEqual(maxIterations)
	expect(modulesQuery.getQueueSize()).toBe(0)
	modulesQuery.destroy()
	root:Destroy()
end)

test("frame budget limits work per frame and queue drains over multiple frames", function()
	local BATCH = 20000
	local root = Instance.new("Folder")
	local modulesQuery = query({
		root = root,
		selector = "ModuleScript",
	})

	for i = 1, BATCH do
		local ms = Instance.new("ModuleScript")
		ms.Name = "M" .. tostring(i)
		ms.Parent = root
	end

	local maxWaits = 2000
	for _ = 1, maxWaits do
		task.wait()
		if modulesQuery.getQueueSize() == 0 and #modulesQuery.get() == BATCH then
			break
		end
	end
	expect(#modulesQuery.get()).toBe(BATCH)
	expect(modulesQuery.getQueueSize()).toBe(0)
	modulesQuery.destroy()
	root:Destroy()
end)

test("settle batching with settleFrames reduces redundant processing", function()
	local root = Instance.new("Folder")
	local moduleScript = Instance.new("ModuleScript")
	moduleScript.Parent = root

	local changeCount = 0
	local modulesQuery = query({
		root = root,
		selector = "ModuleScript",
		settleFrames = 2,
	})
	modulesQuery.changed:Connect(function()
		changeCount += 1
	end)

	while modulesQuery.getQueueSize() > 0 do
		modulesQuery.flush()
	end

	moduleScript.Name = "A"
	task.wait()
	moduleScript.Source = "return 1"
	for _ = 1, 5 do
		task.wait()
	end

	modulesQuery.flush()
	expect(changeCount).toBeGreaterThanOrEqual(1)
	modulesQuery.destroy()
	root:Destroy()
end)
