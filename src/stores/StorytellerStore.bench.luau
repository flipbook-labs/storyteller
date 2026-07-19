local JestGlobals = require("@pkg/JestGlobals")

local StoryModuleRequestPriority = require("@root/stores/enums/StoryModuleRequestPriority")
local StorytellerStore = require("./StorytellerStore")
local isStoryModule = require("@root/isStoryModule")
local types = require("@root/types")

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test
local afterEach = JestGlobals.afterEach
local describeEach = describe.each :: any

type StoryModuleTarget = types.StoryModuleTarget

local TIMEOUT_MS = 2 * 60 * 1000

local store

afterEach(function()
	store.destroy()
end)

local function report(label: string, stats: { [string]: number })
	local parts = {}
	for key, value in stats do
		table.insert(parts, `{key}={string.format("%.1f", value)}`)
	end
	table.sort(parts)
	print(`[bench] {label}: {table.concat(parts, " ")}`)
end

-- Waits frame-by-frame until the condition passes, returning the elapsed time
-- and the number of frames waited. Errors when the ceiling is exceeded so a
-- regression fails fast instead of hanging the suite.
local function settle(ceilingSec: number, condition: () -> boolean): (number, number)
	local startTime = os.clock()
	local frames = 0
	while not condition() do
		task.wait()
		frames += 1
		if os.clock() - startTime > ceilingSec then
			error(`condition did not settle within {ceilingSec}s`)
		end
	end
	return os.clock() - startTime, frames
end

local MULTI_STORY_SOURCE = [[
return {
	summary = "Benchmark fixture",
	stories = {
		{ id = "primary", name = "Primary", story = function() end },
		{ id = "secondary", name = "Secondary", story = function() end },
		{ id = "tertiary", name = "Tertiary", story = function() end },
	},
}
]]

local COUNTING_MULTI_STORY_SOURCE = [[
script:SetAttribute("LoadCount", (script:GetAttribute("LoadCount") or 0) + 1)
return {
	stories = {
		{ id = "primary", name = "Primary", story = function() end },
		{ id = "secondary", name = "Secondary", story = function() end },
	},
}
]]

-- Builds a service-like folder tree: `storyCount` multi-story modules spread
-- across nested folders, padded with distractor Folders and plain
-- ModuleScripts until the tree holds roughly `instanceCount` instances.
local function buildSimulatedDataModel(
	instanceCount: number,
	storyCount: number,
	storySource: string?
): (Folder, { ModuleScript })
	local source = storySource or MULTI_STORY_SOURCE
	local root = Instance.new("Folder")
	root.Name = "SimulatedDataModel"

	local storyModules = {}
	local built = 0
	local folderIndex = 0
	local currentFolder = root

	local function nextFolder(): Folder
		folderIndex += 1
		local folder = Instance.new("Folder")
		folder.Name = `Service{folderIndex // 100}_Folder{folderIndex % 100}`
		-- Cycle parents so depth stays realistic (3-5 levels) instead of one
		-- enormous flat child list or an ever-deepening chain.
		folder.Parent = if folderIndex % 5 == 0 then root else currentFolder
		built += 1
		return folder
	end

	local storiesPerFolder = math.max(1, storyCount // math.max(1, instanceCount // 50))
	local storiesPlaced = 0

	while built < instanceCount do
		currentFolder = nextFolder()

		for _ = 1, 40 do
			if built >= instanceCount then
				break
			end

			if storiesPlaced < storyCount and built % 50 == 0 then
				for _ = 1, storiesPerFolder do
					if storiesPlaced >= storyCount then
						break
					end
					storiesPlaced += 1
					local storyModule = Instance.new("ModuleScript")
					storyModule.Name = `Bench{storiesPlaced}.story`
					storyModule.Source = source
					storyModule.Parent = currentFolder
					table.insert(storyModules, storyModule)
					built += 1
				end
			else
				local distractor = Instance.new("ModuleScript")
				distractor.Name = `Module{built}`
				distractor.Parent = currentFolder
				built += 1
			end
		end
	end

	-- Guarantee the full story count even if the distribution loop under-placed.
	while storiesPlaced < storyCount do
		storiesPlaced += 1
		local storyModule = Instance.new("ModuleScript")
		storyModule.Name = `Bench{storiesPlaced}.story`
		storyModule.Source = source
		storyModule.Parent = root
		table.insert(storyModules, storyModule)
	end

	return root, storyModules
end

local function createStorybook(): types.LoadedStorybook
	return {
		name = "BenchStorybook",
		source = Instance.new("ModuleScript"),
		storyRoots = {},
	}
end

describeEach({
	{ instances = 1000, stories = 100 },
	{ instances = 10000, stories = 500 },
	{ instances = 50000, stories = 1000 },
})("simulated DataModel (%s)", function(scale)
	test("discovers every story module without evaluating any", function()
		local root, storyModules = buildSimulatedDataModel(scale.instances, scale.stories)

		store = StorytellerStore.new(root)

		local startTime = os.clock()
		store.start()
		local elapsed, frames = settle(60, function()
			return #store.getStoryModules() >= #storyModules
		end)

		report(`discovery {scale.instances} instances / {scale.stories} stories`, {
			totalMs = (os.clock() - startTime) * 1000,
			settleMs = elapsed * 1000,
			frames = frames,
		})

		expect(#store.getStoryModules()).toBe(#storyModules)
		-- Discovery must never evaluate a module: no records should exist until
		-- something explicitly requests them.
		expect((next(store.getStoryModuleRecords()))).toBeUndefined()

		root:Destroy()
	end, TIMEOUT_MS)

	test("resolves requested metadata within budgeted frames", function()
		local root, storyModules = buildSimulatedDataModel(scale.instances, scale.stories)
		local storybook = createStorybook()

		store = StorytellerStore.new(root)
		store.start()
		settle(60, function()
			return #store.getStoryModules() >= #storyModules
		end)

		local targets: { StoryModuleTarget } = {}
		for _, storyModule in storyModules do
			table.insert(targets, {
				storyModule = storyModule,
				storybook = storybook,
			})
		end

		local function countRecords(): number
			local count = 0
			for _, recordsForModule in store.getStoryModuleRecords() do
				for _ in recordsForModule do
					count += 1
				end
			end
			return count
		end

		local startTime = os.clock()
		store.requestStoryModules(targets, StoryModuleRequestPriority.Background)

		local firstElapsed, firstFrames = settle(60, function()
			return countRecords() >= 1
		end)
		local _, allFrames = settle(120, function()
			return countRecords() >= #targets
		end)

		report(`metadata {scale.stories} multi-story modules`, {
			firstRecordMs = firstElapsed * 1000,
			allRecordsMs = (os.clock() - startTime) * 1000,
			framesToFirst = firstFrames,
			framesToAll = firstFrames + allFrames,
		})

		-- Every record carries the module's three stories.
		local sampleRecords = store.getStoryModuleRecords()[storyModules[1]]
		assert(sampleRecords, "expected records for the first story module")
		local sampleRecord = sampleRecords[storybook.source]
		assert(sampleRecord and sampleRecord.stories, "expected loaded stories for the first story module")
		expect(#sampleRecord.stories).toBe(3)

		-- The work budget must spread large batches across frames rather than
		-- stalling one frame with the entire load.
		if #targets >= 100 then
			expect(firstFrames + allFrames).toBeGreaterThan(1)
		end

		root:Destroy()
		storybook.source:Destroy()
	end, TIMEOUT_MS)
end)

test("interactive requests are serviced ahead of background backlog", function()
	local root, storyModules = buildSimulatedDataModel(5000, 300)
	local storybook = createStorybook()

	store = StorytellerStore.new(root)
	store.start()
	settle(60, function()
		return #store.getStoryModules() >= #storyModules
	end)

	local backgroundTargets: { StoryModuleTarget } = {}
	for index = 1, #storyModules - 1 do
		table.insert(backgroundTargets, {
			storyModule = storyModules[index],
			storybook = storybook,
		})
	end
	local interactiveTarget: StoryModuleTarget = {
		storyModule = storyModules[#storyModules],
		storybook = storybook,
	}

	local function getRecord(target: StoryModuleTarget)
		local recordsForModule = store.getStoryModuleRecords()[target.storyModule]
		return if recordsForModule then recordsForModule[target.storybook.source] else nil
	end

	local function countRecords(): number
		local count = 0
		for _, recordsForModule in store.getStoryModuleRecords() do
			for _ in recordsForModule do
				count += 1
			end
		end
		return count
	end

	store.requestStoryModules(backgroundTargets, StoryModuleRequestPriority.Background)
	store.requestStoryModules({ interactiveTarget }, StoryModuleRequestPriority.Interactive)

	local startTime = os.clock()
	local interactiveElapsed = settle(60, function()
		return getRecord(interactiveTarget) ~= nil
	end)
	local backgroundDoneAt = countRecords()

	settle(120, function()
		return countRecords() >= #storyModules
	end)
	local allElapsed = os.clock() - startTime

	report("priority 299 background + 1 interactive", {
		interactiveMs = interactiveElapsed * 1000,
		allMs = allElapsed * 1000,
		recordsWhenInteractiveLanded = backgroundDoneAt,
	})

	-- The interactive record must land well before the background backlog
	-- drains: it should not wait behind the majority of the queue.
	expect(backgroundDoneAt).toBeLessThan(#storyModules)

	root:Destroy()
	storybook.source:Destroy()
end, TIMEOUT_MS)

test("discovers a service-shaped DataModel with place noise", function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerStorage = game:GetService("ServerStorage")
	local SoundService = game:GetService("SoundService")

	local priorityRootA = buildSimulatedDataModel(2000, 150)
	priorityRootA.Name = "BenchPriorityA"
	priorityRootA.Parent = ReplicatedStorage
	local priorityRootB = buildSimulatedDataModel(2000, 150)
	priorityRootB.Name = "BenchPriorityB"
	priorityRootB.Parent = ServerStorage

	local lateRoot = buildSimulatedDataModel(2000, 150)
	lateRoot.Name = "BenchLate"
	lateRoot.Parent = SoundService

	-- The test place already contains story modules (Storyteller's own e2e
	-- fixtures under Packages), so expectations are relative to a baseline
	-- sweep rather than absolute counts.
	local expectedTotal = 0
	for _, descendant in game:GetDescendants() do
		if descendant:IsA("ModuleScript") and isStoryModule(descendant) then
			expectedTotal += 1
		end
	end

	store = StorytellerStore.new(game)

	local startTime = os.clock()
	store.start()
	local elapsed, frames = settle(120, function()
		return #store.getStoryModules() >= expectedTotal
	end)

	report("game-root discovery 6000 fixture instances / 450 stories + place noise", {
		totalMs = (os.clock() - startTime) * 1000,
		settleMs = elapsed * 1000,
		frames = frames,
		expectedTotal = expectedTotal,
	})

	expect(#store.getStoryModules()).toBe(expectedTotal)

	priorityRootA:Destroy()
	priorityRootB:Destroy()
	lateRoot:Destroy()
end, TIMEOUT_MS)

test("republishes a single edited story at scale without reloading siblings", function()
	local root, storyModules = buildSimulatedDataModel(10000, 500, COUNTING_MULTI_STORY_SOURCE)
	local storybook = createStorybook()

	store = StorytellerStore.new(root)
	store.start()
	settle(60, function()
		return #store.getStoryModules() >= #storyModules
	end)

	local targets: { StoryModuleTarget } = {}
	for _, storyModule in storyModules do
		table.insert(targets, {
			storyModule = storyModule,
			storybook = storybook,
		})
	end

	local function countRecords(): number
		local count = 0
		for _, recordsForModule in store.getStoryModuleRecords() do
			for _ in recordsForModule do
				count += 1
			end
		end
		return count
	end

	store.requestStoryModules(targets, StoryModuleRequestPriority.Background)
	settle(120, function()
		return countRecords() >= #targets
	end)

	local editedModule = storyModules[1]
	local recordBefore = store.getStoryModuleRecords()[editedModule][storybook.source]

	-- Prepend the marker: ModuleLoader wraps sources onto one line, so a
	-- trailing comment without a newline would swallow the closing tokens.
	editedModule.Source = "-- edited\n" .. COUNTING_MULTI_STORY_SOURCE
	local elapsed, frames = settle(60, function()
		local record = store.getStoryModuleRecords()[editedModule][storybook.source]
		return record ~= recordBefore and record.problem == nil
	end)

	-- ModuleLoader reports source changes asynchronously after the store's
	-- direct Source connection has already published the replacement.
	task.wait(0.2)

	local totalLoads = 0
	local minSibling, maxSibling = math.huge, 0
	for index, storyModule in storyModules do
		local count = (storyModule:GetAttribute("LoadCount") :: number?) or 0
		totalLoads += count
		if index > 1 then
			minSibling = math.min(minSibling, count)
			maxSibling = math.max(maxSibling, count)
		end
	end

	report("single edit with 500 records live", {
		republishMs = elapsed * 1000,
		frames = frames,
		editedLoads = (editedModule:GetAttribute("LoadCount") :: number?) or 0,
		minSiblingLoads = minSibling,
		maxSiblingLoads = maxSibling,
	})
	-- Every module loads exactly once up front; only the edited module loads
	-- a second time. Any sibling reload inflates this sum.
	expect(totalLoads).toBe(#storyModules + 1)

	root:Destroy()
	storybook.source:Destroy()
end, TIMEOUT_MS)

test("invalidates every dependent story when a shared dependency changes", function()
	local DEPENDENT_COUNT = 50

	local root = Instance.new("Folder")
	root.Name = "SharedDepCluster"

	local sharedDep = Instance.new("ModuleScript")
	sharedDep.Name = "SharedDep"
	sharedDep.Source = "return { value = 1 }"
	sharedDep.Parent = root

	local storyModules = {} :: { ModuleScript }
	for index = 1, DEPENDENT_COUNT do
		local storyModule = Instance.new("ModuleScript")
		storyModule.Name = `Dependent{index}.story`
		storyModule.Source = [[
			script:SetAttribute("LoadCount", (script:GetAttribute("LoadCount") or 0) + 1)
			local dep = require(script.Parent.SharedDep)
			return { story = function() return dep.value end }
		]]
		storyModule.Parent = root
		table.insert(storyModules, storyModule)
	end

	local storybook = createStorybook()

	store = StorytellerStore.new(root)
	store.start()
	settle(60, function()
		return #store.getStoryModules() >= DEPENDENT_COUNT
	end)

	local targets: { StoryModuleTarget } = {}
	for _, storyModule in storyModules do
		table.insert(targets, {
			storyModule = storyModule,
			storybook = storybook,
		})
	end

	local function countLoads(): number
		local total = 0
		for _, storyModule in storyModules do
			total += (storyModule:GetAttribute("LoadCount") :: number?) or 0
		end
		return total
	end

	store.requestStoryModules(targets, StoryModuleRequestPriority.Background)
	settle(120, function()
		return countLoads() >= DEPENDENT_COUNT
	end)

	sharedDep.Source = "return { value = 2 }"
	local elapsed, frames = settle(60, function()
		return countLoads() >= DEPENDENT_COUNT * 2
	end)

	report(`shared dependency change across {DEPENDENT_COUNT} dependents`, {
		reloadAllMs = elapsed * 1000,
		frames = frames,
	})

	-- Every dependent must reload exactly once: a missed dependent means the
	-- shared-loader invalidation dropped it, extra loads mean thrash.
	task.wait(0.2)
	expect(countLoads()).toBe(DEPENDENT_COUNT * 2)

	root:Destroy()
	storybook.source:Destroy()
end, TIMEOUT_MS)

-- Generates a module body with real compile weight (~40 lines of functions)
-- so loadstring cost resembles actual library modules instead of stubs.
local function heavyModuleSource(name: string, requiresLine: string?): string
	local lines = {}
	if requiresLine then
		table.insert(lines, requiresLine)
	end
	table.insert(lines, `local {name} = \{}`)
	for index = 1, 12 do
		table.insert(
			lines,
			`function {name}.method{index}(value) local out = \{} for i = 1, 8 do out[i] = value + i * {index} end return out end`
		)
	end
	table.insert(lines, `return {name}`)
	table.insert(lines, "")
	return table.concat(lines, "\n")
end

-- Builds a corpus shaped like real story collections: every story requires a
-- private dependency chain plus a shared library, so loading a story means
-- compiling its whole require graph the way React-style stories do.
local function buildHeavyCorpus(storyCount: number, chainDepth: number, sharedCount: number): (Folder, { ModuleScript })
	local root = Instance.new("Folder")
	root.Name = "HeavyCorpus"

	local sharedFolder = Instance.new("Folder")
	sharedFolder.Name = "Shared"
	sharedFolder.Parent = root
	for index = 1, sharedCount do
		local sharedModule = Instance.new("ModuleScript")
		sharedModule.Name = `Shared{index}`
		sharedModule.Source = heavyModuleSource(`Shared{index}`)
		sharedModule.Parent = sharedFolder
	end

	local storyModules = {}
	for storyIndex = 1, storyCount do
		local storyFolder = Instance.new("Folder")
		storyFolder.Name = `Story{storyIndex}`
		storyFolder.Parent = root

		local depsFolder = Instance.new("Folder")
		depsFolder.Name = "Deps"
		depsFolder.Parent = storyFolder

		for depIndex = chainDepth, 1, -1 do
			local depModule = Instance.new("ModuleScript")
			depModule.Name = `Dep{depIndex}`
			local requiresLine = if depIndex < chainDepth
				then `local nextDep = require(script.Parent.Dep{depIndex + 1})`
				else nil
			depModule.Source = heavyModuleSource(`Dep{depIndex}`, requiresLine)
			depModule.Parent = depsFolder
		end

		local storyModule = Instance.new("ModuleScript")
		storyModule.Name = `Heavy{storyIndex}.story`
		storyModule.Source = ([[
local corpus = script:FindFirstAncestor("HeavyCorpus")
local dep = require(script.Parent.Deps.Dep1)
local sharedA = require(corpus.Shared.Shared1)
local sharedB = require(corpus.Shared.Shared%d)
return {
	story = function()
		return { dep = dep, sharedA = sharedA, sharedB = sharedB }
	end,
}
]]):format((storyIndex % 28) + 2)
		storyModule.Parent = storyFolder
		table.insert(storyModules, storyModule)
	end

	return root, storyModules
end

test("loads a heavy dependency corpus lazily with fast selection", function()
	local root, storyModules = buildHeavyCorpus(200, 10, 30)
	local storybook = createStorybook()

	store = StorytellerStore.new(root)
	store.start()
	settle(60, function()
		return #store.getStoryModules() >= #storyModules
	end)

	local targets: { StoryModuleTarget } = {}
	for _, storyModule in storyModules do
		table.insert(targets, {
			storyModule = storyModule,
			storybook = storybook,
		})
	end

	local function getRecord(storyModule: ModuleScript)
		local recordsForModule = store.getStoryModuleRecords()[storyModule]
		return if recordsForModule then recordsForModule[storybook.source] else nil
	end

	local function countRecords(): number
		local count = 0
		for _, recordsForModule in store.getStoryModuleRecords() do
			for _ in recordsForModule do
				count += 1
			end
		end
		return count
	end

	-- Cold select-while-loading: the whole sidebar batch is queued background
	-- and the user immediately clicks one story.
	local selectedModule = storyModules[150]
	local startTime = os.clock()
	store.requestStoryModules(targets, StoryModuleRequestPriority.Background)
	store.requestStoryModules({
		{ storyModule = selectedModule, storybook = storybook },
	}, StoryModuleRequestPriority.Interactive)

	local selectElapsed, selectFrames = settle(60, function()
		local record = getRecord(selectedModule)
		return record ~= nil and record.problem == nil
	end)
	local recordsWhenSelected = countRecords()

	local allElapsed, allFrames = settle(300, function()
		return countRecords() >= #targets
	end)

	-- Warm re-select: a second consumer requests an already-loaded story.
	local warmStart = os.clock()
	local releaseWarm = store.requestStoryModules({
		{ storyModule = selectedModule, storybook = storybook },
	}, StoryModuleRequestPriority.Interactive)
	local warmRecord = getRecord(selectedModule)
	local warmMs = (os.clock() - warmStart) * 1000
	releaseWarm()

	report("heavy corpus 200 stories x (10-chain + shared lib): store", {
		selectedStoryMs = selectElapsed * 1000,
		selectedStoryFrames = selectFrames,
		recordsWhenSelected = recordsWhenSelected,
		backgroundAllMs = (os.clock() - startTime) * 1000,
		backgroundAllFrames = selectFrames + allFrames,
		warmReselectMs = warmMs,
	})

	assert(warmRecord ~= nil and warmRecord.problem == nil, "expected the warm re-select to hit a loaded record")
	expect(countRecords()).toBe(#targets)

	root:Destroy()
	storybook.source:Destroy()
end, TIMEOUT_MS)
