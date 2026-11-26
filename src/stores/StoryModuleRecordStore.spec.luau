--[[
	Lute's unused_variable lint doesn't count writing a property as a use, and
	these tests set up instances that way.
	#187 tracks removing this ignore.
	lute-lint-global-ignore(unused_variable)
]]

local Charm = require("@pkg/Charm")
local JestGlobals = require("@pkg/JestGlobals")

local StoryModuleRecordStore = require("./StoryModuleRecordStore")
local StoryModuleRequestPriority = require("@root/stores/enums/StoryModuleRequestPriority")
local createPlaytestModuleScript = require("@root/test-utils/createPlaytestModuleScript")
local types = require("@root/types")
local waitFor = require("@root/test-utils/waitFor")

local expect = JestGlobals.expect
local test = JestGlobals.test
local describe = JestGlobals.describe
local afterEach = JestGlobals.afterEach

type StoryRequest = StoryModuleRecordStore.StoryRequest

local recordStore: StoryModuleRecordStore.StoryModuleRecordStore
local wasCharmFrozen = Charm.flags.frozen

--[[
	Story modules in these specs find their siblings through `script.Parent`.
	Their root folders aren't in the DataModel, so once nothing references a
	root, it can be collected, and its children's Parent becomes nil. A reload
	after that fails to find the siblings. Roots made by `createRoot` stay
	referenced until the test ends.
]]
local roots: { Instance } = {}

local function createRoot(): Folder
	local root = Instance.new("Folder")
	table.insert(roots, root)
	return root
end

afterEach(function()
	recordStore.destroy()
	Charm.flags.frozen = wasCharmFrozen
	for _, root in roots do
		root:Destroy()
	end
	table.clear(roots)
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

local function getRecord(request: StoryRequest)
	return recordStore.getRecord(request)
end

-- Builds a batch of story modules that stamp the order they were evaluated in,
-- so queue-ordering behavior is observable without timing assumptions.
local function createOrderedRequests(count: number, storybook: types.LoadedStorybook): { StoryRequest }
	local root = createRoot()
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
	local request = createRequest("Button")

	recordStore.request(StoryModuleRequestPriority.Background, request)

	waitFor(function()
		local record = getRecord(request)
		assert(record and record.status == "Loaded", "expected a loaded record for the requested story module")
		expect(record.stories[1]).toMatchObject({
			id = "Button",
			name = "Button",
			summary = "Button summary",
			source = request.storyModule,
			storybook = request.storybook,
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
		assert(record and record.status == "Loaded", "expected the reentrant request to load")
		expect(record.stories[1].id).toBe("Second")
	end)
	dispose()
end)

test("loads every story from a requested module", function()
	recordStore = StoryModuleRecordStore.new()
	local request = createRequest("Buttons")
	request.storyModule.Source = [[
		return {
			name = "Buttons",
			stories = {
				Primary = function() end,
				Secondary = function() end,
			},
		}
	]]

	recordStore.request(StoryModuleRequestPriority.Background, request)

	waitFor(function()
		local record = getRecord(request)
		assert(record and record.status == "Loaded", "expected every story in the requested module")
		expect(record.stories).toEqual({
			expect.objectContaining({ id = "Primary", name = "Primary" }),
			expect.objectContaining({ id = "Secondary", name = "Secondary" }),
		})
	end)
end)

test("publishes the module's group name", function()
	recordStore = StoryModuleRecordStore.new()
	local request = createRequest("Widgets")
	request.storyModule.Source = [[
		return {
			name = "Widget Gallery",
			stories = {
				Primary = function() end,
				Secondary = function() end,
			},
		}
	]]

	recordStore.request(StoryModuleRequestPriority.Background, request)

	waitFor(function()
		local record = getRecord(request)
		assert(record and record.status == "Loaded", "expected a record for the requested story module")
		expect(record.name).toBe("Widget Gallery")
	end)
end)

test("accepts a request in a playtest, where a story module's Source is off limits", function()
	recordStore = StoryModuleRecordStore.new()
	local request = createRequest("Playtest")
	request.storyModule = createPlaytestModuleScript(request.storyModule)

	expect(function()
		recordStore.request(StoryModuleRequestPriority.Interactive, request)
	end).never.toThrow()
end)

test("keeps loaded story packages mutable under Charm's Studio freeze", function()
	Charm.flags.frozen = true
	recordStore = StoryModuleRecordStore.new()
	local request = createRequest("Mutable")
	local packageState = {}
	request.storybook.packages = {
		Package = {
			state = packageState,
		},
	} :: types.StoryPackages

	recordStore.request(StoryModuleRequestPriority.Background, request)

	waitFor(function()
		local record = getRecord(request)
		assert(record and record.status == "Loaded", "expected a loaded record for the requested story module")
		-- Records enter Charm state, which deep-freezes in Studio. Package
		-- modules like React mutate internal state while rendering, so the
		-- loaded story's object graph must stay outside that freeze.
		expect(table.isfrozen(packageState)).toBe(false)
	end)
end)

test("keeps a story's own packages and props mutable when a consumer stores it in Charm state", function()
	Charm.flags.frozen = true
	recordStore = StoryModuleRecordStore.new()
	local request = createRequest("Stored")
	request.storyModule.Source = [[
		return {
			packages = {
				Shared = { state = {} },
			},
			stories = {
				Inherited = function() end,
				Overridden = {
					story = function() end,
					packages = {
						Own = { state = {} },
					},
					props = {
						state = {},
					},
				},
			},
		}
	]]

	recordStore.request(StoryModuleRequestPriority.Background, request)

	waitFor(function()
		local record = getRecord(request)
		assert(record and record.status == "Loaded", "expected a loaded record for the requested story module")

		for _, story in record.stories do
			local getStory, setStory = Charm.signal<<types.LoadedStory<unknown>?>>(nil)
			setStory(story)

			local stored = getStory()
			assert(stored, "story was not stored in Charm state")
			assert(stored.packages, "loaded story has no packages")
			for _, package in stored.packages do
				expect(table.isfrozen((package :: { state: {} }).state)).toBe(false)
			end
			if stored.props then
				expect(table.isfrozen(stored.props.state)).toBe(false)
			end
		end

		local overridden = record.stories[2]
		assert(overridden.packages, "loaded story has no packages")
		expect(overridden.packages.Shared).toBeDefined()
		expect(overridden.packages.Own).toBeDefined()
		expect(overridden.props).toBeDefined()
	end)
end)

test("evaluates the storybook and story through the same loader", function()
	recordStore = StoryModuleRecordStore.new()

	local root = createRoot()
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
	local request: StoryRequest = {
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

	recordStore.request(StoryModuleRequestPriority.Background, request)

	waitFor(function()
		local record = getRecord(request)
		assert(record and record.status == "Loaded", "expected a loaded record for the requested story module")
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
	local request = createRequest("Broken")
	request.storyModule.Source = "syntax error"

	recordStore.request(StoryModuleRequestPriority.Background, request)

	waitFor(function()
		local record = getRecord(request)
		assert(record and record.status == "Unavailable", "expected the story module to fail to load")
		expect(record.problem).toBeDefined()
	end)
end)

test("reuses the cached record across overlapping requests", function()
	recordStore = StoryModuleRecordStore.new()
	local request = createRequest("Shared")

	recordStore.request(StoryModuleRequestPriority.Background, request)

	local cachedRecord: typeof(getRecord(request))
	waitFor(function()
		cachedRecord = getRecord(request)
		expect(cachedRecord).toBeDefined()
	end)

	recordStore.request(StoryModuleRequestPriority.Interactive, request)

	-- Give a queued reload the chance to (incorrectly) publish before
	-- asserting the record identity survived the overlapping request.
	task.wait(0.1)
	expect(getRecord(request)).toBe(cachedRecord)
end)

test("does not reload sibling stories when one story source changes", function()
	local root = createRoot()
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
		assert(record and record.status == "Loaded", "expected the changed story to reload")
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
	local request = createRequest("Disposable")

	local releaseFirst = recordStore.request(StoryModuleRequestPriority.Background, request)
	local releaseSecond = recordStore.request(StoryModuleRequestPriority.Background, request)

	waitFor(function()
		expect(getRecord(request)).toBeDefined()
	end)

	releaseFirst()
	expect(getRecord(request)).toBeDefined()

	releaseSecond()
	expect(getRecord(request)).toBeUndefined()
end)

test("releasing the same request twice does not steal another consumer's hold", function()
	recordStore = StoryModuleRecordStore.new()
	local request = createRequest("HeldTwice")

	local releaseFirst = recordStore.request(StoryModuleRequestPriority.Background, request)
	recordStore.request(StoryModuleRequestPriority.Background, request)

	waitFor(function()
		expect(getRecord(request)).toBeDefined()
	end)

	releaseFirst()
	releaseFirst()

	expect(getRecord(request)).toBeDefined()
end)

test("groups records by Storybook when multiple Storybooks cover the same module", function()
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
		local records = recordStore.getRecords()
		expect(records[first.storybook.source][first.storyModule]).toBeDefined()
		expect(records[second.storybook.source][second.storyModule]).toBeDefined()
	end)
end)

test("releasing one Storybook's request keeps the other Storybook's record", function()
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

	local releaseFirst = recordStore.request(StoryModuleRequestPriority.Background, first)
	local releaseSecond = recordStore.request(StoryModuleRequestPriority.Background, second)

	waitFor(function()
		expect(getRecord(first)).toBeDefined()
		expect(getRecord(second)).toBeDefined()
	end)
	local secondRecord = getRecord(second)

	releaseFirst()
	expect(getRecord(first)).toBeUndefined()
	expect(getRecord(second)).toBe(secondRecord)

	local record = getRecord(second)
	assert(record and record.status == "Loaded", "expected the second Storybook's record to survive")
	expect(record.stories[1]).toMatchObject({
		id = "Shared",
		storybook = second.storybook,
	})

	releaseSecond()
	expect(getRecord(second)).toBeUndefined()
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

	for _, request in requests do
		recordStore.request(StoryModuleRequestPriority.Background, request)
	end
	recordStore.request(StoryModuleRequestPriority.Interactive, selected)

	waitFor(function()
		for _, request in requests do
			expect(getRecord(request)).toBeDefined()
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

	for _, request in requests do
		recordStore.request(StoryModuleRequestPriority.Background, request)
	end
	recordStore.request(StoryModuleRequestPriority.Interactive, upgraded)

	waitFor(function()
		for _, request in requests do
			expect(getRecord(request)).toBeDefined()
		end
	end)

	-- The upgrade moves the entry to the interactive queue without a second load.
	expect(upgraded.storyModule:GetAttribute("Order")).toBe(1)
	expect(upgraded.storyModule:GetAttribute("LoadCount")).toBe(1)
end)

test("reloads with the replacement storybook when the request's storybook changes", function()
	recordStore = StoryModuleRecordStore.new()
	local request = createRequest("Refreshed")

	recordStore.request(StoryModuleRequestPriority.Background, request)

	waitFor(function()
		expect(getRecord(request)).toBeDefined()
	end)

	local replacementStorybook: types.LoadedStorybook = {
		name = "Replacement",
		source = request.storybook.source,
		storyRoots = {},
	}

	recordStore.request(StoryModuleRequestPriority.Background, {
		storyModule = request.storyModule,
		storybook = replacementStorybook,
	})

	waitFor(function()
		local record = getRecord(request)
		assert(record and record.status == "Loaded", "expected the record to reload with the replacement storybook")
		expect(record.stories[1].storybook).toBe(replacementStorybook)
	end)
end)

test("removes the record when the story module is destroyed", function()
	recordStore = StoryModuleRecordStore.new()
	local request = createRequest("Doomed")

	recordStore.request(StoryModuleRequestPriority.Background, request)

	waitFor(function()
		expect(getRecord(request)).toBeDefined()
	end)

	request.storyModule:Destroy()

	waitFor(function()
		expect(getRecord(request)).toBeUndefined()
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
	local request = createRequest("Cleared")

	recordStore.request(StoryModuleRequestPriority.Background, request)

	waitFor(function()
		expect(getRecord(request)).toBeDefined()
	end)

	recordStore.clear()

	local recordKey = next(recordStore.getRecords())
	expect(recordKey).toBeUndefined()

	-- The store must accept fresh requests after a clear.
	recordStore.request(StoryModuleRequestPriority.Background, request)
	waitFor(function()
		expect(getRecord(request)).toBeDefined()
	end)
end)

test("releasing a request from before clear preserves its replacement record", function()
	recordStore = StoryModuleRecordStore.new()
	local request = createRequest("Replaced")
	local releaseOld = recordStore.request(StoryModuleRequestPriority.Background, request)

	waitFor(function()
		expect(getRecord(request)).toBeDefined()
	end)

	recordStore.clear()
	local releaseNew = recordStore.request(StoryModuleRequestPriority.Background, request)
	local replacementRecord: StoryModuleRecordStore.StoryModuleRecord?
	waitFor(function()
		replacementRecord = getRecord(request)
		assert(replacementRecord and replacementRecord.status == "Loaded", "expected the replacement story to load")
		expect(replacementRecord.stories[1].name).toBe("Replaced")
	end)

	releaseOld()
	expect(getRecord(request)).toBe(replacementRecord)

	releaseNew()
	expect(getRecord(request)).toBeUndefined()
end)

test("requests after destroy are no-ops", function()
	recordStore = StoryModuleRecordStore.new()
	recordStore.destroy()

	local request = createRequest("TooLate")
	local release = recordStore.request(StoryModuleRequestPriority.Background, request)
	release()

	task.wait()
	local recordKey = next(recordStore.getRecords())
	expect(recordKey).toBeUndefined()
end)

--[[
	Editing a module in Studio changes its Source on every keystroke. These
	specs make a burst of edits closer together than the store's 0.3-second
	quiet period (RELOAD_QUIET_PERIOD_SECONDS), the way typing does, and count
	how often the story module is evaluated.

	The store only waits for modules open in the script editor, and nothing is
	open outside Studio, so these specs create a store that treats every module
	as open.
]]
local TYPING_INTERVAL_SECONDS = 0.1

local function createTypingRecordStore()
	return StoryModuleRecordStore.new({
		isOpenInScriptEditor = function()
			return true
		end,
	})
end

test("reloads once when a replacement storybook arrives during the quiet period", function()
	local root = createRoot()
	local loadCount = Instance.new("IntValue")
	loadCount.Name = "LoadCount"
	loadCount.Parent = root

	local request = createRequest("ReplacedWhileTyping")
	request.storyModule.Parent = root
	local function setVersion(version: number)
		request.storyModule.Source = "script.Parent.LoadCount.Value += 1\n"
			.. `return \{ name = "Version {version}", story = function() end \}`
	end
	setVersion(0)

	recordStore = createTypingRecordStore()
	recordStore.request(StoryModuleRequestPriority.Interactive, request)

	waitFor(function()
		expect(loadCount.Value).toBe(1)
	end)

	local replacementStorybook: types.LoadedStorybook = {
		name = "Replacement",
		source = request.storybook.source,
		storyRoots = {},
	}

	-- The short wait lets the edit start its quiet-period timer before the
	-- replacement arrives.
	setVersion(1)
	task.wait(0.05)
	recordStore.request(StoryModuleRequestPriority.Interactive, {
		storyModule = request.storyModule,
		storybook = replacementStorybook,
	})

	waitFor(function()
		local record = getRecord(request)
		assert(record and record.status == "Loaded", "expected the story to reload")
		expect(record.stories[1].name).toBe("Version 1")
		expect(record.stories[1].storybook).toBe(replacementStorybook)
	end)

	-- Waiting past the quiet period lets a reload from the edit's timer show
	-- up in the count.
	task.wait(0.5)
	expect(loadCount.Value).toBe(2)
end)

test("reloads a story once after a burst of edits to its source", function()
	local root = createRoot()
	local loadCount = Instance.new("IntValue")
	loadCount.Name = "LoadCount"
	loadCount.Parent = root

	local request = createRequest("Typed")
	request.storyModule.Parent = root
	local function setVersion(version: number)
		request.storyModule.Source = "script.Parent.LoadCount.Value += 1\n"
			.. `return \{ name = "Version {version}", story = function() end \}`
	end
	setVersion(0)

	recordStore = createTypingRecordStore()
	recordStore.request(StoryModuleRequestPriority.Interactive, request)

	waitFor(function()
		expect(loadCount.Value).toBe(1)
	end)

	for version = 1, 3 do
		setVersion(version)
		task.wait(TYPING_INTERVAL_SECONDS)
	end

	waitFor(function()
		local record = getRecord(request)
		assert(record and record.status == "Loaded", "expected the edited story to reload")
		expect(record.stories[1].name).toBe("Version 3")
	end, { timeout = 5 })

	-- If each edit still reloaded the Story, some of those reloads would land
	-- after the record shows the final version. Waiting past the quiet period
	-- lets them show up in the count.
	task.wait(0.5)
	expect(loadCount.Value).toBe(2)
end)

test("reloads a story once after a burst of edits to a module it requires", function()
	local root = createRoot()
	local loadCount = Instance.new("IntValue")
	loadCount.Name = "LoadCount"
	loadCount.Parent = root

	local dependency = Instance.new("ModuleScript")
	dependency.Name = "Dependency"
	dependency.Parent = root
	local function setDependencyVersion(version: number)
		dependency.Source = `return {version}`
	end
	setDependencyVersion(0)

	local request = createRequest("UsesDependency")
	request.storyModule.Parent = root
	request.storyModule.Source = [[
		script.Parent.LoadCount.Value += 1
		local version = require(script.Parent.Dependency)
		return { name = "UsesDependency", story = function() return version end }
	]]

	recordStore = createTypingRecordStore()
	recordStore.request(StoryModuleRequestPriority.Interactive, request)

	waitFor(function()
		expect(loadCount.Value).toBe(1)
	end)

	for version = 1, 3 do
		setDependencyVersion(version)
		task.wait(TYPING_INTERVAL_SECONDS)
	end

	waitFor(function()
		local record = getRecord(request)
		assert(record and record.status == "Loaded", "expected the story to reload with its dependency")
		expect((record.stories[1].story :: () -> number)()).toBe(3)
	end, { timeout = 5 })

	task.wait(0.5)
	expect(loadCount.Value).toBe(2)
end)

describe("a module that stops loading after it loaded once", function()
	local function loadWorkingStory(name: string)
		local root = createRoot()
		local request = createRequest(name)
		request.storyModule.Parent = root
		request.storyModule.Source = `return \{ name = "Working", story = function() end \}`

		recordStore = StoryModuleRecordStore.new()
		recordStore.request(StoryModuleRequestPriority.Interactive, request)

		local workingRecord: types.LoadedStoryModule
		waitFor(function()
			local record = getRecord(request)
			assert(record and record.status == "Loaded", "expected the working story to load")
			workingRecord = record
		end)

		return request, workingRecord, root
	end

	test("keeps the last working stories and reports a syntax error", function()
		local request, workingRecord = loadWorkingStory("SyntaxError")

		request.storyModule.Source = `return \{ name = "Working", story = function() end`

		waitFor(function()
			local record = getRecord(request)
			assert(record and record.status == "Loaded", "expected the last working stories to stay loaded")
			expect(record.problem).toEqual(expect.any("string"))
			expect(record.stories[1].name).toBe("Working")
			expect(record.stories).toBe(workingRecord.stories)
		end, { timeout = 5 })
	end)

	test("keeps the last working stories when the module throws while it runs", function()
		local request, workingRecord = loadWorkingStory("Throws")

		request.storyModule.Source = "local value = nil\nreturn { name = value.name, story = function() end }"

		waitFor(function()
			local record = getRecord(request)
			assert(record and record.status == "Loaded", "expected the last working stories to stay loaded")
			local problem = record.problem
			assert(problem, "expected the record to report the error")
			-- The problem is the error alone, without a traceback or a
			-- "Failed to load story" prefix.
			expect(problem).toMatch("Throws%.story[^\n]*:2: attempt to index nil with 'name'$")
			expect(problem).never.toMatch("Failed to load story")
			expect(record.stories).toBe(workingRecord.stories)
		end, { timeout = 5 })
	end)

	test("clears the problem once the module loads again", function()
		local request = loadWorkingStory("Recovers")

		request.storyModule.Source = `return \{ name = "Working", story = function() end`

		waitFor(function()
			local record = getRecord(request)
			assert(record and record.status == "Loaded", "expected the last working stories to stay loaded")
			expect(record.problem).toEqual(expect.any("string"))
		end, { timeout = 5 })

		request.storyModule.Source = `return \{ name = "Fixed", story = function() end \}`

		waitFor(function()
			local record = getRecord(request)
			assert(record and record.status == "Loaded", "expected the fixed story to load")
			expect(record.stories[1].name).toBe("Fixed")
			expect(record.problem).toBeUndefined()
		end, { timeout = 5 })
	end)

	test("reloads once a broken dependency is fixed", function()
		local root = createRoot()
		local dependency = Instance.new("ModuleScript")
		dependency.Name = "Dependency"
		dependency.Source = "return 1"
		dependency.Parent = root

		local request = createRequest("BrokenDependency")
		request.storyModule.Parent = root
		request.storyModule.Source = [[
			local version = require(script.Parent.Dependency)
			return { name = "Version " .. version, story = function() end }
		]]

		recordStore = StoryModuleRecordStore.new()
		recordStore.request(StoryModuleRequestPriority.Interactive, request)

		waitFor(function()
			local record = getRecord(request)
			assert(record and record.status == "Loaded", "expected the story to load")
			expect(record.stories[1].name).toBe("Version 1")
		end)

		dependency.Source = "return ("

		waitFor(function()
			local record = getRecord(request)
			assert(record and record.status == "Loaded", "expected the last working stories to stay loaded")
			expect(record.problem).toEqual(expect.any("string"))
			expect(record.stories[1].name).toBe("Version 1")
		end, { timeout = 5 })

		dependency.Source = "return 2"

		waitFor(function()
			local record = getRecord(request)
			assert(record and record.status == "Loaded", "expected the story to reload with the fixed dependency")
			expect(record.stories[1].name).toBe("Version 2")
			expect(record.problem).toBeUndefined()
		end, { timeout = 5 })
	end)

	test("reloads once a broken dependency is fixed after an edit has loaded", function()
		local root = createRoot()
		local dependency = Instance.new("ModuleScript")
		dependency.Name = "Dependency"
		dependency.Source = "return 1"
		dependency.Parent = root

		local request = createRequest("BrokenDependencyAfterEdit")
		request.storyModule.Parent = root
		request.storyModule.Source = [[
			local version = require(script.Parent.Dependency)
			return { name = "Version " .. version, story = function() end }
		]]

		recordStore = StoryModuleRecordStore.new()
		recordStore.request(StoryModuleRequestPriority.Interactive, request)

		waitFor(function()
			local record = getRecord(request)
			assert(record and record.status == "Loaded", "expected the story to load")
			expect(record.stories[1].name).toBe("Version 1")
		end)

		request.storyModule.Source = [[
			local version = require(script.Parent.Dependency)
			return { name = "Edited " .. version, story = function() end }
		]]

		waitFor(function()
			local record = getRecord(request)
			assert(record and record.status == "Loaded", "expected the edited story to load")
			expect(record.stories[1].name).toBe("Edited 1")
		end, { timeout = 5 })

		dependency.Source = "return ("

		waitFor(function()
			local record = getRecord(request)
			assert(record and record.status == "Loaded", "expected the last working stories to stay loaded")
			expect(record.problem).toEqual(expect.any("string"))
			expect(record.stories[1].name).toBe("Edited 1")
		end, { timeout = 5 })

		dependency.Source = "return 2"

		waitFor(function()
			local record = getRecord(request)
			assert(record and record.status == "Loaded", "expected the story to reload with the fixed dependency")
			expect(record.stories[1].name).toBe("Edited 2")
			expect(record.problem).toBeUndefined()
		end, { timeout = 5 })
	end)
end)

--[[
	A module that isn't open in the script editor changes when a tool such as
	Rojo syncs a saved file. These specs check that the reload starts right
	away, well inside the quiet period.
]]
local NOT_WAITING_TIMEOUT_SECONDS = 0.2

test("reloads right away when a story module that isn't open in the script editor changes", function()
	local request = createRequest("Synced")

	recordStore = StoryModuleRecordStore.new({
		isOpenInScriptEditor = function()
			return false
		end,
	})
	recordStore.request(StoryModuleRequestPriority.Interactive, request)

	waitFor(function()
		local record = getRecord(request)
		assert(record and record.status == "Loaded", "expected the story to load")
	end)

	request.storyModule.Source = `return \{ name = "Saved", story = function() end \}`

	waitFor(function()
		local record = getRecord(request)
		assert(record and record.status == "Loaded", "expected the saved story to load")
		expect(record.stories[1].name).toBe("Saved")
	end, { timeout = NOT_WAITING_TIMEOUT_SECONDS })
end)

test("reloads right away when a dependency that isn't open changes, even while the story is open", function()
	local root = createRoot()
	local dependency = Instance.new("ModuleScript")
	dependency.Name = "Dependency"
	dependency.Source = "return 1"
	dependency.Parent = root

	local request = createRequest("OpenStory")
	request.storyModule.Parent = root
	request.storyModule.Source = [[
		local version = require(script.Parent.Dependency)
		return { name = "Version " .. version, story = function() end }
	]]

	recordStore = StoryModuleRecordStore.new({
		isOpenInScriptEditor = function(module)
			return module == request.storyModule
		end,
	})
	recordStore.request(StoryModuleRequestPriority.Interactive, request)

	waitFor(function()
		local record = getRecord(request)
		assert(record and record.status == "Loaded", "expected the story to load")
		expect(record.stories[1].name).toBe("Version 1")
	end)

	dependency.Source = "return 2"

	waitFor(function()
		local record = getRecord(request)
		assert(record and record.status == "Loaded", "expected the story to reload with the saved dependency")
		expect(record.stories[1].name).toBe("Version 2")
	end, { timeout = NOT_WAITING_TIMEOUT_SECONDS })
end)
