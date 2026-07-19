local JestGlobals = require("@pkg/JestGlobals")

local StorytellerStore = require("./StorytellerStore")
local isStoryModule = require("@root/isStoryModule")
local loadStoryModule = require("@root/loadStoryModule")
local types = require("@root/types")

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test
local afterEach = JestGlobals.afterEach
local describeEach = describe.each :: any

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

local SINGLE_STORY_SOURCE = [[
return {
	summary = "Benchmark fixture",
	story = function() end,
}
]]

-- Mirrors the tree builder on the feature branches so discovery numbers are
-- comparable: story modules spread across nested folders, padded with
-- distractor Folders and plain ModuleScripts.
local function buildSimulatedDataModel(instanceCount: number, storyCount: number): (Folder, { ModuleScript })
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
					storyModule.Source = SINGLE_STORY_SOURCE
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

	while storiesPlaced < storyCount do
		storiesPlaced += 1
		local storyModule = Instance.new("ModuleScript")
		storyModule.Name = `Bench{storiesPlaced}.story`
		storyModule.Source = SINGLE_STORY_SOURCE
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
	test("discovers every story module", function()
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

		root:Destroy()
	end, TIMEOUT_MS)

	test("eagerly loads every discovered story module", function()
		-- On main, story loading lives in each caller: building sidebar
		-- metadata means synchronously evaluating every module. This measures
		-- that pattern over the same corpus the feature branches load lazily.
		local root, storyModules = buildSimulatedDataModel(scale.instances, scale.stories)
		local storybook = createStorybook()

		store = StorytellerStore.new(root)
		store.start()
		settle(60, function()
			return #store.getStoryModules() >= #storyModules
		end)

		local startTime = os.clock()
		local loaded = 0
		for _, storyModule in storyModules do
			local ok = pcall(function()
				loadStoryModule(storyModule, storybook)
			end)
			if ok then
				loaded += 1
			end
		end
		local elapsed = os.clock() - startTime

		report(`eager metadata {scale.stories} single-story modules`, {
			allLoadsMs = elapsed * 1000,
			loaded = loaded,
		})

		expect(loaded).toBe(#storyModules)

		root:Destroy()
		storybook.source:Destroy()
	end, TIMEOUT_MS)
end)

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

test("eagerly loads a heavy dependency corpus per caller", function()
	local root, storyModules = buildHeavyCorpus(200, 10, 30)
	local storybook = createStorybook()

	store = StorytellerStore.new(root)
	store.start()
	settle(60, function()
		return #store.getStoryModules() >= #storyModules
	end)

	-- Sidebar-open pattern on main: synchronously evaluate every story module.
	-- Each loadStoryModule call owns a fresh ModuleLoader, so shared library
	-- modules recompile for every story, and everything runs in one frame.
	local startTime = os.clock()
	local loaded = 0
	for _, storyModule in storyModules do
		local ok = pcall(function()
			loadStoryModule(storyModule, storybook)
		end)
		if ok then
			loaded += 1
		end
	end
	local eagerAllMs = (os.clock() - startTime) * 1000

	-- Selection on main: useStory mounts with its own loader and evaluates the
	-- story again, even though the sidebar already loaded it.
	local selectStart = os.clock()
	local selected
	local ok = pcall(function()
		selected = loadStoryModule(storyModules[150], storybook)
	end)
	local selectMs = (os.clock() - selectStart) * 1000

	report("heavy corpus 200 stories x (10-chain + shared lib): main eager", {
		eagerAllMs = eagerAllMs,
		loaded = loaded,
		selectAfterEagerMs = selectMs,
	})

	assert(ok and selected ~= nil, "expected the selected story to load")
	expect(loaded).toBe(#storyModules)

	root:Destroy()
	storybook.source:Destroy()
end, TIMEOUT_MS)
