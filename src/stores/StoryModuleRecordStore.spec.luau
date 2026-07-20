local Charm = require("@pkg/Charm")
local JestGlobals = require("@pkg/JestGlobals")

local StoryModuleRecordStore = require("./StoryModuleRecordStore")
local StoryModuleRequestPriority = require("@root/stores/enums/StoryModuleRequestPriority")
local types = require("@root/types")
local waitFor = require("@root/test-utils/waitFor")

local expect = JestGlobals.expect
local test = JestGlobals.test
local afterEach = JestGlobals.afterEach

type StoryModuleTarget = StoryModuleRecordStore.StoryModuleTarget

local recordStore: StoryModuleRecordStore.StoryModuleRecordStore
local wasCharmFrozen = Charm.flags.frozen

afterEach(function()
	recordStore.destroy()
	Charm.flags.frozen = wasCharmFrozen
end)

local function createTarget(name: string): StoryModuleTarget
	local storyModule = Instance.new("ModuleScript")
	storyModule.Name = `{name}.story`
	storyModule.Source = `return \{ name = "{name}", summary = "{name} summary", story = function() end \}`

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
	return recordStore.getRecords(target.storyModule)
end

-- Builds a batch of story modules that stamp the order they were evaluated in,
-- so queue-ordering behavior is observable without timing assumptions.
local function createOrderedTargets(count: number, storybook: types.LoadedStorybook): { StoryModuleTarget }
	local root = Instance.new("Folder")
	local counter = Instance.new("IntValue")
	counter.Name = "Counter"
	counter.Parent = root

	local targets = {}
	for index = 1, count do
		local storyModule = Instance.new("ModuleScript")
		storyModule.Name = `Ordered{index}.story`
		storyModule.Source = [[
			local counter = script.Parent.Counter
			counter.Value += 1
			script:SetAttribute("Order", counter.Value)
			script:SetAttribute("LoadCount", (script:GetAttribute("LoadCount") or 0) + 1)
			return { story = function() end }
		]]
		storyModule.Parent = root
		table.insert(targets, {
			storyModule = storyModule,
			storybook = storybook,
		})
	end
	return targets
end

test("loads a requested story module", function()
	recordStore = StoryModuleRecordStore.new()
	local target = createTarget("Button")

	recordStore.request(StoryModuleRequestPriority.Background, target)

	waitFor(function()
		local record = getRecord(target)
		assert(record and record.story, "expected a loaded record for the requested story module")
		expect(record.problem).toBeUndefined()
		expect(record.story).toMatchObject({
			name = "Button",
			summary = "Button summary",
			source = target.storyModule,
			storybook = target.storybook,
		})
	end)
end)

test("keeps loaded story packages mutable under Charm's Studio freeze", function()
	Charm.flags.frozen = true
	recordStore = StoryModuleRecordStore.new()
	local target = createTarget("Mutable")
	local packageState = {}
	target.storybook.packages = {
		Package = {
			state = packageState,
		},
	}

	recordStore.request(StoryModuleRequestPriority.Background, target)

	waitFor(function()
		local record = getRecord(target)
		assert(record and record.story, "expected a loaded record for the requested story module")
		-- Records enter Charm state, which deep-freezes in Studio. Package
		-- modules like React mutate internal state while rendering, so the
		-- loaded story's object graph must stay outside that freeze.
		expect(table.isfrozen(packageState)).toBe(false)
	end)
end)

test("evaluates the storybook and story through the same loader", function()
	recordStore = StoryModuleRecordStore.new()

	local root = Instance.new("Folder")
	local marker = Instance.new("ModuleScript")
	marker.Name = "Marker"
	marker.Source = "return {}"
	marker.Parent = root

	local storybookModule = Instance.new("ModuleScript")
	storybookModule.Name = "Identity.storybook"
	storybookModule.Source = [[
		return {
			storyRoots = {},
			packages = {
				Marker = require(script.Parent.Marker),
			},
		}
	]]
	storybookModule.Parent = root

	local storyModule = Instance.new("ModuleScript")
	storyModule.Name = "Identity.story"
	storyModule.Source = [[
		local marker = require(script.Parent.Marker)
		return { story = function() return marker end }
	]]
	storyModule.Parent = root

	-- The caller supplies a storybook whose packages were evaluated by some
	-- other loader, the way discovery-side loading does.
	local target: StoryModuleTarget = {
		storyModule = storyModule,
		storybook = {
			name = "Stale",
			source = storybookModule,
			storyRoots = {},
			packages = {
				Marker = {},
			},
		},
	}

	recordStore.request(StoryModuleRequestPriority.Background, target)

	waitFor(function()
		local record = getRecord(target)
		assert(record and record.story, "expected a loaded record for the requested story module")
		-- A package instance the story requires must be identity-equal to the
		-- one in its storybook's packages: libraries like React break when a
		-- story renders against a different instance than it required.
		local storyMarker = (record.story.story :: () -> unknown)()
		local packages = record.story.packages
		assert(packages, "expected the loaded story to carry its storybook's packages")
		expect(packages.Marker).toBe(storyMarker)
	end)
end)

test("reports a story module load problem", function()
	recordStore = StoryModuleRecordStore.new()
	local target = createTarget("Broken")
	target.storyModule.Source = "syntax error"

	recordStore.request(StoryModuleRequestPriority.Background, target)

	waitFor(function()
		local record = getRecord(target)
		assert(record, "expected a record for the requested story module")
		expect(record.story).toBeUndefined()
		expect(record.problem).toBeDefined()
	end)
end)

test("reuses the cached record across overlapping requests", function()
	recordStore = StoryModuleRecordStore.new()
	local target = createTarget("Shared")

	recordStore.request(StoryModuleRequestPriority.Background, target)

	local cachedRecord
	waitFor(function()
		cachedRecord = getRecord(target)
		expect(cachedRecord).toBeDefined()
	end)

	recordStore.request(StoryModuleRequestPriority.Interactive, target)

	-- Give a queued reload the chance to (incorrectly) publish before
	-- asserting the record identity survived the overlapping request.
	task.wait(0.1)
	expect(getRecord(target)).toBe(cachedRecord)
end)

test("does not reload sibling stories when one story source changes", function()
	local root = Instance.new("Folder")
	local firstLoadCount = Instance.new("IntValue")
	firstLoadCount.Name = "FirstLoadCount"
	firstLoadCount.Parent = root
	local secondLoadCount = Instance.new("IntValue")
	secondLoadCount.Name = "SecondLoadCount"
	secondLoadCount.Parent = root

	local first = createTarget("First")
	first.storyModule.Source = [[
		script.Parent.FirstLoadCount.Value += 1
		return { name = "First", story = function() end }
	]]
	first.storyModule.Parent = root

	local second = createTarget("Second")
	second.storyModule.Source = [[
		script.Parent.SecondLoadCount.Value += 1
		return { name = "Second", story = function() end }
	]]
	second.storyModule.Parent = root
	second.storybook = first.storybook

	recordStore = StoryModuleRecordStore.new()
	recordStore.request(StoryModuleRequestPriority.Background, first)
	recordStore.request(StoryModuleRequestPriority.Background, second)

	waitFor(function()
		expect(firstLoadCount.Value).toBe(1)
		expect(secondLoadCount.Value).toBe(1)
	end)

	first.storyModule.Source = [[
		script.Parent.FirstLoadCount.Value += 1
		return { name = "First updated", story = function() end }
	]]

	waitFor(function()
		local record = getRecord(first)
		assert(record and record.story, "expected the changed story to reload")
		expect(record.story.name).toBe("First updated")
	end)
	-- ModuleLoader reports source changes asynchronously after the store's
	-- direct Source connection has already published the replacement.
	task.wait(0.2)
	expect(firstLoadCount.Value).toBe(2)
	expect(secondLoadCount.Value).toBe(1)
end)

test("drops the record once every request is released", function()
	recordStore = StoryModuleRecordStore.new()
	local target = createTarget("Disposable")

	local releaseFirst = recordStore.request(StoryModuleRequestPriority.Background, target)
	local releaseSecond = recordStore.request(StoryModuleRequestPriority.Background, target)

	waitFor(function()
		expect(getRecord(target)).toBeDefined()
	end)

	releaseFirst()
	expect(getRecord(target)).toBeDefined()

	releaseSecond()
	expect(getRecord(target)).toBeUndefined()
end)

test("releasing the same request twice does not steal another consumer's hold", function()
	recordStore = StoryModuleRecordStore.new()
	local target = createTarget("HeldTwice")

	local releaseFirst = recordStore.request(StoryModuleRequestPriority.Background, target)
	recordStore.request(StoryModuleRequestPriority.Background, target)

	waitFor(function()
		expect(getRecord(target)).toBeDefined()
	end)

	releaseFirst()
	releaseFirst()

	expect(getRecord(target)).toBeDefined()
end)

test("loads the same story module through a replacement Storybook", function()
	recordStore = StoryModuleRecordStore.new()
	local first = createTarget("Shared")
	local second: StoryModuleTarget = {
		storyModule = first.storyModule,
		storybook = {
			name = "Second Storybook",
			source = Instance.new("ModuleScript"),
			storyRoots = {},
		},
	}

	local release = recordStore.request(StoryModuleRequestPriority.Background, first)

	waitFor(function()
		local record = getRecord(first)
		assert(record and record.story, "expected the first Storybook to load the shared story module")
		expect(record.story.storybook).toBe(first.storybook)
	end)

	release()
	recordStore.request(StoryModuleRequestPriority.Background, second)

	waitFor(function()
		local record = getRecord(second)
		assert(record and record.story, "expected the replacement Storybook to load the shared story module")
		expect(record.story.storybook).toBe(second.storybook)
	end)
end)

test("services an interactive request before queued background targets", function()
	recordStore = StoryModuleRecordStore.new()
	local storybook: types.LoadedStorybook = {
		name = "Storybook",
		source = Instance.new("ModuleScript"),
		storyRoots = {},
	}
	local targets = createOrderedTargets(5, storybook)
	local selected = targets[5]

	for _, target in targets do
		recordStore.request(StoryModuleRequestPriority.Background, target)
	end
	recordStore.request(StoryModuleRequestPriority.Interactive, selected)

	waitFor(function()
		for _, target in targets do
			expect(getRecord(target)).toBeDefined()
		end
	end)

	expect(selected.storyModule:GetAttribute("Order")).toBe(1)
	expect(selected.storyModule:GetAttribute("LoadCount")).toBe(1)
end)

test("upgrades a queued background target when re-requested interactively", function()
	recordStore = StoryModuleRecordStore.new()
	local storybook: types.LoadedStorybook = {
		name = "Storybook",
		source = Instance.new("ModuleScript"),
		storyRoots = {},
	}
	local targets = createOrderedTargets(5, storybook)
	local upgraded = targets[4]

	for _, target in targets do
		recordStore.request(StoryModuleRequestPriority.Background, target)
	end
	recordStore.request(StoryModuleRequestPriority.Interactive, upgraded)

	waitFor(function()
		for _, target in targets do
			expect(getRecord(target)).toBeDefined()
		end
	end)

	-- The upgrade moves the entry to the interactive queue without a second load.
	expect(upgraded.storyModule:GetAttribute("Order")).toBe(1)
	expect(upgraded.storyModule:GetAttribute("LoadCount")).toBe(1)
end)

test("reloads with the replacement storybook when the target's storybook changes", function()
	recordStore = StoryModuleRecordStore.new()
	local target = createTarget("Refreshed")

	recordStore.request(StoryModuleRequestPriority.Background, target)

	waitFor(function()
		expect(getRecord(target)).toBeDefined()
	end)

	local replacementStorybook: types.LoadedStorybook = {
		name = "Replacement",
		source = target.storybook.source,
		storyRoots = {},
	}

	recordStore.request(StoryModuleRequestPriority.Background, {
		storyModule = target.storyModule,
		storybook = replacementStorybook,
	})

	waitFor(function()
		local record = getRecord(target)
		assert(record and record.story, "expected the record to reload with the replacement storybook")
		expect(record.story.storybook).toBe(replacementStorybook)
	end)
end)

test("removes the record when the story module is destroyed", function()
	recordStore = StoryModuleRecordStore.new()
	local target = createTarget("Doomed")

	recordStore.request(StoryModuleRequestPriority.Background, target)

	waitFor(function()
		expect(getRecord(target)).toBeDefined()
	end)

	target.storyModule:Destroy()

	waitFor(function()
		expect(getRecord(target)).toBeUndefined()
	end)
end)

test("removes records when the storybook module is destroyed", function()
	recordStore = StoryModuleRecordStore.new()
	local first = createTarget("First")
	local second = createTarget("Second")
	second.storybook = first.storybook

	recordStore.request(StoryModuleRequestPriority.Background, first)
	recordStore.request(StoryModuleRequestPriority.Background, second)

	waitFor(function()
		expect(getRecord(first)).toBeDefined()
		expect(getRecord(second)).toBeDefined()
	end)

	first.storybook.source:Destroy()

	waitFor(function()
		expect(getRecord(first)).toBeUndefined()
		expect(getRecord(second)).toBeUndefined()
	end)
end)

test("clear drops every record and outstanding request", function()
	recordStore = StoryModuleRecordStore.new()
	local target = createTarget("Cleared")

	recordStore.request(StoryModuleRequestPriority.Background, target)

	waitFor(function()
		expect(getRecord(target)).toBeDefined()
	end)

	recordStore.clear()

	expect(getRecord(target)).toBeUndefined()

	-- The store must accept fresh requests after a clear.
	recordStore.request(StoryModuleRequestPriority.Background, target)
	waitFor(function()
		expect(getRecord(target)).toBeDefined()
	end)
end)

test("requests after destroy are no-ops", function()
	recordStore = StoryModuleRecordStore.new()
	recordStore.destroy()

	local target = createTarget("TooLate")
	local release = recordStore.request(StoryModuleRequestPriority.Background, target)
	release()

	task.wait()
	expect(getRecord(target)).toBeUndefined()
end)
