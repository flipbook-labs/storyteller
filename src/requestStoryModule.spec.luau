local Charm = require("@pkg/Charm")
local JestGlobals = require("@pkg/JestGlobals")

local StorytellerStore = require("@root/stores/StorytellerStore")
local getStoryModuleRecord = require("./getStoryModuleRecord")
local requestStoryModule = require("./requestStoryModule")
local types = require("@root/types")
local waitFor = require("@root/test-utils/waitFor")

local afterEach = JestGlobals.afterEach
local beforeEach = JestGlobals.beforeEach
local expect = JestGlobals.expect
local test = JestGlobals.test

type StoryRequest = types.StoryRequest

beforeEach(function()
	StorytellerStore.get().stop()
end)

afterEach(function()
	StorytellerStore.get().stop()
end)

local function createRequest(name: string, source: string): StoryRequest
	local storyModule = Instance.new("ModuleScript")
	storyModule.Name = `{name}.story`
	storyModule.Source = source

	return {
		storyModule = storyModule,
		storybook = {
			name = "Storybook",
			source = Instance.new("ModuleScript"),
			storyRoots = {},
		},
	}
end

local function destroyRequest(request: StoryRequest)
	request.storyModule:Destroy()
	request.storybook.source:Destroy()
end

test("loads every Story in the requested module", function()
	local request = createRequest("Group", "return { stories = { First = function() end, Second = function() end } }")
	expect(getStoryModuleRecord(request)).toBeUndefined()

	local release = requestStoryModule(request)

	waitFor(function()
		local record = getStoryModuleRecord(request)
		assert(record and record.status == "Loaded", "expected the module to load")
		expect(record.name).toBe("Group")
		expect(record.stories).toEqual({
			expect.objectContaining({ id = "First" }),
			expect.objectContaining({ id = "Second" }),
		})
	end)

	release()
	destroyRequest(request)
end)

test("reports a module that fails to load without affecting other requests", function()
	local broken = createRequest("Broken", "syntax error")
	local working = createRequest("Working", "return { story = function() end }")

	local releaseBroken = requestStoryModule(broken)
	local releaseWorking = requestStoryModule(working)

	waitFor(function()
		local brokenRecord = getStoryModuleRecord(broken)
		assert(brokenRecord and brokenRecord.status == "Unavailable", "expected the module to fail")
		expect(brokenRecord.problem).toMatch("Broken.story")

		local workingRecord = getStoryModuleRecord(working)
		assert(workingRecord and workingRecord.status == "Loaded", "expected the module to load")
	end)

	releaseBroken()
	releaseWorking()
	destroyRequest(broken)
	destroyRequest(working)
end)

test("loads an Interactive request before Background requests made earlier", function()
	local root = Instance.new("Folder")
	local counter = Instance.new("IntValue")
	counter.Name = "Counter"
	counter.Parent = root

	local source = [[
		local counter = script.Parent.Counter
		counter.Value += 1
		script:SetAttribute("Order", counter.Value)
		return { story = function() end }
	]]
	local background = createRequest("Background", source)
	background.storyModule.Parent = root
	local interactive = createRequest("Interactive", source)
	interactive.storyModule.Parent = root
	interactive.priority = "Interactive"

	local releaseBackground = requestStoryModule(background)
	local releaseInteractive = requestStoryModule(interactive)

	waitFor(function()
		expect(interactive.storyModule:GetAttribute("Order")).toBe(1)
		expect(background.storyModule:GetAttribute("Order")).toBe(2)
	end)

	releaseBackground()
	releaseInteractive()
	destroyRequest(background)
	destroyRequest(interactive)
	root:Destroy()
end)

test("keeps the record when the runtime's other consumers release it", function()
	local request = createRequest("Held", "return { story = function() end }")
	local releaseOther = StorytellerStore.get().acquire()
	local release = requestStoryModule(request)

	waitFor(function()
		expect(getStoryModuleRecord(request)).toBeDefined()
	end)

	releaseOther()
	expect(getStoryModuleRecord(request)).toBeDefined()

	release()
	expect(getStoryModuleRecord(request)).toBeUndefined()
	destroyRequest(request)
end)

test("releasing a request twice keeps another request's record", function()
	local request = createRequest("Shared", "return { story = function() end }")
	local release = requestStoryModule(request)
	local releaseOther = requestStoryModule(request)

	waitFor(function()
		expect(getStoryModuleRecord(request)).toBeDefined()
	end)

	release()
	release()
	expect(getStoryModuleRecord(request)).toBeDefined()

	releaseOther()
	expect(getStoryModuleRecord(request)).toBeUndefined()
	destroyRequest(request)
end)

-- Each module stamps the order it was evaluated in, and how many times. Hold the
-- returned folder until the test ends. Without a reference, it can be collected,
-- and then the modules can't find the counter beside them.
local function createOrderedRequests(names: { string }): ({ StoryRequest }, Folder)
	local root = Instance.new("Folder")
	local counter = Instance.new("IntValue")
	counter.Name = "Counter"
	counter.Parent = root

	local requests: { StoryRequest } = {}
	for _, name in names do
		local request = createRequest(
			name,
			[[
				local counter = script.Parent.Counter
				counter.Value += 1
				script:SetAttribute("Order", counter.Value)
				script:SetAttribute("LoadCount", (script:GetAttribute("LoadCount") or 0) + 1)
				return { story = function() end }
			]]
		)
		request.storyModule.Parent = root
		table.insert(requests, request)
	end
	return requests, root
end

local function waitForRecords(requests: { StoryRequest })
	waitFor(function()
		for _, request in requests do
			local record = getStoryModuleRecord(request)
			assert(record and record.status == "Loaded", "expected the module to load")
		end
	end)
end

test("loads a module that failed once its source is fixed", function()
	local request = createRequest("Repaired", "syntax error")
	local release = requestStoryModule(request)

	waitFor(function()
		local record = getStoryModuleRecord(request)
		assert(record and record.status == "Unavailable", "expected the module to fail")
	end)

	request.storyModule.Source = "return { story = function() end }"

	waitFor(function()
		local record = getStoryModuleRecord(request)
		assert(record and record.status == "Loaded", "expected the repaired module to load")
		expect(record.stories).toEqual({ expect.objectContaining({ id = "default", name = "Repaired" }) })
	end)

	release()
	destroyRequest(request)
end)

test("requesting and releasing one module leaves another's record alone", function()
	local requests, root = createOrderedRequests({ "First", "Second" })
	requests[2].storybook = requests[1].storybook

	local releaseFirst = requestStoryModule(requests[1])
	waitForRecords({ requests[1] })
	local firstRecord = getStoryModuleRecord(requests[1])

	local releaseSecond = requestStoryModule(requests[2])
	waitForRecords({ requests[2] })
	expect(getStoryModuleRecord(requests[1])).toBe(firstRecord)
	local secondRecord = getStoryModuleRecord(requests[2])

	releaseFirst()
	task.wait(0.1)
	expect(getStoryModuleRecord(requests[1])).toBeUndefined()
	expect(getStoryModuleRecord(requests[2])).toBe(secondRecord)
	expect(requests[2].storyModule:GetAttribute("LoadCount")).toBe(1)

	releaseSecond()
	for _, request in requests do
		destroyRequest(request)
	end
	root:Destroy()
end)

test("keeps Interactive priority when a Background request for the same module follows", function()
	local requests, root = createOrderedRequests({ "First", "Duplicated" })
	local interactive = table.clone(requests[2])
	interactive.priority = "Interactive"

	local releases = {
		requestStoryModule(requests[1]),
		requestStoryModule(interactive),
		requestStoryModule(requests[2]),
	}
	waitForRecords(requests)

	expect(requests[2].storyModule:GetAttribute("Order")).toBe(1)
	expect(requests[1].storyModule:GetAttribute("Order")).toBe(2)
	expect(requests[2].storyModule:GetAttribute("LoadCount")).toBe(1)

	for _, release in releases do
		release()
	end
	for _, request in requests do
		destroyRequest(request)
	end
	root:Destroy()
end)

test("changing a loaded module's priority keeps its record and reloads it first on the next edit", function()
	local requests, root = createOrderedRequests({ "Unchanged", "Reprioritized" })
	requests[2].storybook = requests[1].storybook

	local releaseUnchanged = requestStoryModule(requests[1])
	local releaseBackground = requestStoryModule(requests[2])
	waitForRecords(requests)
	local record = getStoryModuleRecord(requests[2])

	local interactive = table.clone(requests[2])
	interactive.priority = "Interactive"
	local releaseInteractive = requestStoryModule(interactive)
	releaseBackground()
	task.wait(0.1)
	expect(getStoryModuleRecord(requests[2])).toBe(record)
	expect(requests[2].storyModule:GetAttribute("LoadCount")).toBe(1)

	for _, request in requests do
		request.storyModule.Source ..= "\n"
	end
	waitFor(function()
		expect(requests[2].storyModule:GetAttribute("Order")).toBe(3)
		expect(requests[1].storyModule:GetAttribute("Order")).toBe(4)
	end)

	releaseUnchanged()
	releaseInteractive()
	for _, request in requests do
		destroyRequest(request)
	end
	root:Destroy()
end)

test("replacing a Storybook reloads each of its modules once", function()
	local requests, root = createOrderedRequests({ "First", "Second" })
	local storybook = requests[1].storybook
	storybook.packages = { Dependency = "first" }
	requests[2].storybook = storybook
	local releases = { requestStoryModule(requests[1]), requestStoryModule(requests[2]) }
	waitForRecords(requests)

	local replacement = table.clone(storybook)
	replacement.packages = { Dependency = "second" }
	for index, request in requests do
		local replaced: StoryRequest = { storyModule = request.storyModule, storybook = replacement }
		local release = releases[index]
		releases[index] = requestStoryModule(replaced)
		release()
	end

	waitFor(function()
		for _, request in requests do
			local record = getStoryModuleRecord(request)
			assert(record and record.status == "Loaded", "expected the module to reload")
			expect(record.stories[1].packages).toEqual({ Dependency = "second" })
		end
	end)
	for _, request in requests do
		expect(request.storyModule:GetAttribute("LoadCount")).toBe(2)
	end

	for _, release in releases do
		release()
	end
	for _, request in requests do
		destroyRequest(request)
	end
	root:Destroy()
end)

test("an unrelated record does not notify a record's listener", function()
	local requests, root = createOrderedRequests({ "Listened", "Unrelated" })
	requests[2].storybook = requests[1].storybook

	local release = requestStoryModule(requests[1])
	waitForRecords({ requests[1] })

	local notifications = 0
	local stopListening = Charm.subscribe(function()
		return getStoryModuleRecord(requests[1])
	end, function()
		notifications += 1
	end)

	local releaseUnrelated = requestStoryModule(requests[2])
	waitForRecords({ requests[2] })
	releaseUnrelated()
	expect(notifications).toBe(0)

	-- The listened module's own edit still gets through.
	requests[1].storyModule.Source ..= "\n"
	waitFor(function()
		expect(notifications).toBe(1)
	end)

	stopListening()
	release()
	for _, request in requests do
		destroyRequest(request)
	end
	root:Destroy()
end)
