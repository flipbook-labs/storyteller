local Charm = require("@pkg/Charm")
local JestGlobals = require("@pkg/JestGlobals")

local StoryModuleRecordStore = require("./StoryModuleRecordStore")
local StoryModuleRequestPriority = require("@root/stores/enums/StoryModuleRequestPriority")
local types = require("@root/types")
local waitFor = require("@root/test-utils/waitFor")

local expect = JestGlobals.expect
local test = JestGlobals.test
local afterEach = JestGlobals.afterEach

type StoryRequest = StoryModuleRecordStore.StoryRequest

local recordStore: StoryModuleRecordStore.StoryModuleRecordStore
local wasCharmFrozen = Charm.flags.frozen

afterEach(function()
	recordStore.destroy()
	Charm.flags.frozen = wasCharmFrozen
end)

local function createRequest(name: string): StoryRequest
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

local function getRecord(storyRequest: StoryRequest)
	local recordsForModule = recordStore.getRecords()[storyRequest.storyModule]
	return if recordsForModule then recordsForModule[storyRequest.storybook.source] else nil
end

-- Builds a batch of story modules that stamp the order they were evaluated in,
-- so queue-ordering behavior is observable without timing assumptions.
local function createOrderedRequests(count: number, storybook: types.LoadedStorybook): { StoryRequest }
	local root = Instance.new("Folder")
	local counter = Instance.new("IntValue")
	counter.Name = "Counter"
	counter.Parent = root

	local requests = {}
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
		table.insert(requests, {
			storyModule = storyModule,
			storybook = storybook,
		})
	end
	return requests
end

test("loads a requested story module", function()
	recordStore = StoryModuleRecordStore.new()
	local storyRequest = createRequest("Button")

	recordStore.request(StoryModuleRequestPriority.Background, storyRequest)

	waitFor(function()
		local record = getRecord(storyRequest)
		assert(record and record.stories, "expected a loaded record for the requested story module")
		expect(record.problem).toBeUndefined()
		expect(record.stories[1]).toMatchObject({
			id = "Button",
			name = "Button",
			summary = "Button summary",
			source = storyRequest.storyModule,
			storybook = storyRequest.storybook,
		})
	end)
end)

test("processes requests made while publishing records", function()
	recordStore = StoryModuleRecordStore.new()
	local first = createRequest("First")
	local second = createRequest("Second")
	local requestedSecond = false

	local dispose = Charm.listen(recordStore.getRecords, function()
		if not requestedSecond and getRecord(first) then
			requestedSecond = true
			recordStore.request(StoryModuleRequestPriority.Background, second)
		end
	end)

	recordStore.request(StoryModuleRequestPriority.Background, first)

	waitFor(function()
		local record = getRecord(second)
		assert(record and record.stories, "expected the reentrant request to load")
		expect(record.stories[1].id).toBe("Second")
	end)
	dispose()
end)

test("loads every story from a requested module", function()
	recordStore = StoryModuleRecordStore.new()
	local storyRequest = createRequest("Buttons")
	storyRequest.storyModule.Source = [[
		return {
			name = "Buttons",
			stories = {
				Primary = function() end,
				Secondary = function() end,
			},
		}
	]]

	recordStore.request(StoryModuleRequestPriority.Background, storyRequest)

	waitFor(function()
		local record = getRecord(storyRequest)
		assert(record and record.stories, "expected every story in the requested module")
		expect(record.stories).toEqual({
			expect.objectContaining({ id = "Primary", name = "Primary" }),
			expect.objectContaining({ id = "Secondary", name = "Secondary" }),
		})
	end)
end)

test("publishes the module's group name", function()
	recordStore = StoryModuleRecordStore.new()
	local storyRequest = createRequest("Widgets")
	storyRequest.storyModule.Source = [[
		return {
			name = "Widget Gallery",
			stories = {
				Primary = function() end,
				Secondary = function() end,
			},
		}
	]]

	recordStore.request(StoryModuleRequestPriority.Background, storyRequest)

	waitFor(function()
		local record = getRecord(storyRequest)
		assert(record, "expected a record for the requested story module")
		expect(record.name).toBe("Widget Gallery")
	end)
end)

test("keeps loaded story packages mutable under Charm's Studio freeze", function()
	Charm.flags.frozen = true
	recordStore = StoryModuleRecordStore.new()
	local storyRequest = createRequest("Mutable")
	local packageState = {}
	storyRequest.storybook.packages = {
		Package = {
			state = packageState,
		},
	} :: types.StoryPackages

	recordStore.request(StoryModuleRequestPriority.Background, storyRequest)

	waitFor(function()
		local record = getRecord(storyRequest)
		assert(record and record.stories, "expected a loaded record for the requested story module")
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
	local storyRequest: StoryRequest = {
		storyModule = storyModule,
		storybook = {
			name = "Stale",
			source = storybookModule,
			storyRoots = {},
			packages = {
				Marker = {},
			} :: types.StoryPackages,
		},
	}

	recordStore.request(StoryModuleRequestPriority.Background, storyRequest)

	waitFor(function()
		local record = getRecord(storyRequest)
		assert(record and record.stories, "expected a loaded record for the requested story module")
		-- A package instance the story requires must be identity-equal to the
		-- one in its storybook's packages: libraries like React break when a
		-- story renders against a different instance than it required.
		local storyMarker = (record.stories[1].story :: () -> unknown)()
		local packages = record.stories[1].packages
		assert(packages, "expected the loaded story to carry its storybook's packages")
		expect(packages.Marker).toBe(storyMarker)
	end)
end)

test("reports a story module load problem", function()
	recordStore = StoryModuleRecordStore.new()
	local storyRequest = createRequest("Broken")
	storyRequest.storyModule.Source = "syntax error"

	recordStore.request(StoryModuleRequestPriority.Background, storyRequest)

	waitFor(function()
		local record = getRecord(storyRequest)
		assert(record, "expected a record for the requested story module")
		expect(record.stories).toBeUndefined()
		expect(record.problem).toBeDefined()
	end)
end)

test("reuses the cached record across overlapping requests", function()
	recordStore = StoryModuleRecordStore.new()
	local storyRequest = createRequest("Shared")

	recordStore.request(StoryModuleRequestPriority.Background, storyRequest)

	local cachedRecord
	waitFor(function()
		cachedRecord = getRecord(storyRequest)
		expect(cachedRecord).toBeDefined()
	end)

	recordStore.request(StoryModuleRequestPriority.Interactive, storyRequest)

	-- Give a queued reload the chance to (incorrectly) publish before
	-- asserting the record identity survived the overlapping request.
	task.wait(0.1)
	expect(getRecord(storyRequest)).toBe(cachedRecord)
end)

test("does not reload sibling stories when one story source changes", function()
	local root = Instance.new("Folder")
	local firstLoadCount = Instance.new("IntValue")
	firstLoadCount.Name = "FirstLoadCount"
	firstLoadCount.Parent = root
	local secondLoadCount = Instance.new("IntValue")
	secondLoadCount.Name = "SecondLoadCount"
	secondLoadCount.Parent = root

	local first = createRequest("First")
	first.storyModule.Source = [[
		script.Parent.FirstLoadCount.Value += 1
		return { name = "First", story = function() end }
	]]
	first.storyModule.Parent = root

	local second = createRequest("Second")
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
		assert(record and record.stories, "expected the changed story to reload")
		expect(record.stories[1].name).toBe("First updated")
	end)
	-- ModuleLoader reports source changes asynchronously after the store's
	-- direct Source connection has already published the replacement.
	task.wait(0.2)
	expect(firstLoadCount.Value).toBe(2)
	expect(secondLoadCount.Value).toBe(1)
end)

test("drops the record once every request is released", function()
	recordStore = StoryModuleRecordStore.new()
	local storyRequest = createRequest("Disposable")

	local releaseFirst = recordStore.request(StoryModuleRequestPriority.Background, storyRequest)
	local releaseSecond = recordStore.request(StoryModuleRequestPriority.Background, storyRequest)

	waitFor(function()
		expect(getRecord(storyRequest)).toBeDefined()
	end)

	releaseFirst()
	expect(getRecord(storyRequest)).toBeDefined()

	releaseSecond()
	expect(getRecord(storyRequest)).toBeUndefined()
end)

test("releasing the same request twice does not steal another consumer's hold", function()
	recordStore = StoryModuleRecordStore.new()
	local storyRequest = createRequest("HeldTwice")

	local releaseFirst = recordStore.request(StoryModuleRequestPriority.Background, storyRequest)
	recordStore.request(StoryModuleRequestPriority.Background, storyRequest)

	waitFor(function()
		expect(getRecord(storyRequest)).toBeDefined()
	end)

	releaseFirst()
	releaseFirst()

	expect(getRecord(storyRequest)).toBeDefined()
end)

test("keeps one record per Storybook covering the same module", function()
	recordStore = StoryModuleRecordStore.new()
	local first = createRequest("Shared")
	local second: StoryRequest = {
		storyModule = first.storyModule,
		storybook = {
			name = "Second Storybook",
			source = Instance.new("ModuleScript"),
			storyRoots = {},
		},
	}

	recordStore.request(StoryModuleRequestPriority.Background, first)
	recordStore.request(StoryModuleRequestPriority.Background, second)

	waitFor(function()
		local recordsForModule = recordStore.getRecords()[first.storyModule]
		assert(recordsForModule, "expected records for the shared story module")
		expect(recordsForModule[first.storybook.source]).toBeDefined()
		expect(recordsForModule[second.storybook.source]).toBeDefined()
	end)
end)

test("services an interactive request before queued background requests", function()
	recordStore = StoryModuleRecordStore.new()
	local storybook: types.LoadedStorybook = {
		name = "Storybook",
		source = Instance.new("ModuleScript"),
		storyRoots = {},
	}
	local requests = createOrderedRequests(5, storybook)
	local selected = requests[5]

	for _, storyRequest in requests do
		recordStore.request(StoryModuleRequestPriority.Background, storyRequest)
	end
	recordStore.request(StoryModuleRequestPriority.Interactive, selected)

	waitFor(function()
		for _, storyRequest in requests do
			expect(getRecord(storyRequest)).toBeDefined()
		end
	end)

	expect(selected.storyModule:GetAttribute("Order")).toBe(1)
	expect(selected.storyModule:GetAttribute("LoadCount")).toBe(1)
end)

test("upgrades a queued background request when re-requested interactively", function()
	recordStore = StoryModuleRecordStore.new()
	local storybook: types.LoadedStorybook = {
		name = "Storybook",
		source = Instance.new("ModuleScript"),
		storyRoots = {},
	}
	local requests = createOrderedRequests(5, storybook)
	local upgraded = requests[4]

	for _, storyRequest in requests do
		recordStore.request(StoryModuleRequestPriority.Background, storyRequest)
	end
	recordStore.request(StoryModuleRequestPriority.Interactive, upgraded)

	waitFor(function()
		for _, storyRequest in requests do
			expect(getRecord(storyRequest)).toBeDefined()
		end
	end)

	-- The upgrade moves the entry to the interactive queue without a second load.
	expect(upgraded.storyModule:GetAttribute("Order")).toBe(1)
	expect(upgraded.storyModule:GetAttribute("LoadCount")).toBe(1)
end)

test("reloads with the replacement storybook when the request's storybook changes", function()
	recordStore = StoryModuleRecordStore.new()
	local storyRequest = createRequest("Refreshed")

	recordStore.request(StoryModuleRequestPriority.Background, storyRequest)

	waitFor(function()
		expect(getRecord(storyRequest)).toBeDefined()
	end)

	local replacementStorybook: types.LoadedStorybook = {
		name = "Replacement",
		source = storyRequest.storybook.source,
		storyRoots = {},
	}

	recordStore.request(StoryModuleRequestPriority.Background, {
		storyModule = storyRequest.storyModule,
		storybook = replacementStorybook,
	})

	waitFor(function()
		local record = getRecord(storyRequest)
		assert(record and record.stories, "expected the record to reload with the replacement storybook")
		expect(record.stories[1].storybook).toBe(replacementStorybook)
	end)
end)

test("removes the record when the story module is destroyed", function()
	recordStore = StoryModuleRecordStore.new()
	local storyRequest = createRequest("Doomed")

	recordStore.request(StoryModuleRequestPriority.Background, storyRequest)

	waitFor(function()
		expect(getRecord(storyRequest)).toBeDefined()
	end)

	storyRequest.storyModule:Destroy()

	waitFor(function()
		expect(getRecord(storyRequest)).toBeUndefined()
	end)
end)

test("removes records when the storybook module is destroyed", function()
	recordStore = StoryModuleRecordStore.new()
	local first = createRequest("First")
	local second = createRequest("Second")
	second.storybook = first.storybook

	recordStore.request(StoryModuleRequestPriority.Background, first)
	recordStore.request(StoryModuleRequestPriority.Background, second)

	waitFor(function()
		expect(getRecord(first)).toBeDefined()
		expect(getRecord(second)).toBeDefined()
	end)

	first.storybook.source:Destroy()

	waitFor(function()
		local firstKey = next(recordStore.getRecords())
		expect(firstKey).toBeUndefined()
	end)
end)

test("clear drops every record and outstanding request", function()
	recordStore = StoryModuleRecordStore.new()
	local storyRequest = createRequest("Cleared")

	recordStore.request(StoryModuleRequestPriority.Background, storyRequest)

	waitFor(function()
		expect(getRecord(storyRequest)).toBeDefined()
	end)

	recordStore.clear()

	expect((next(recordStore.getRecords()))).toBeUndefined()

	-- The store must accept fresh requests after a clear.
	recordStore.request(StoryModuleRequestPriority.Background, storyRequest)
	waitFor(function()
		expect(getRecord(storyRequest)).toBeDefined()
	end)
end)

test("requests after destroy are no-ops", function()
	recordStore = StoryModuleRecordStore.new()
	recordStore.destroy()

	local storyRequest = createRequest("TooLate")
	local release = recordStore.request(StoryModuleRequestPriority.Background, storyRequest)
	release()

	task.wait()
	expect((next(recordStore.getRecords()))).toBeUndefined()
end)
