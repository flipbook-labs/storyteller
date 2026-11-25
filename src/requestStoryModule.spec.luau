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
