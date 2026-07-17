local JestGlobals = require("@pkg/JestGlobals")

local StorytellerStore = require("./StorytellerStore")
local types = require("@root/types")

local afterEach = JestGlobals.afterEach
local expect = JestGlobals.expect
local test = JestGlobals.test

type LoadedStorybook = types.LoadedStorybook
type StoryModuleTarget = types.StoryModuleTarget
type StorytellerStore = StorytellerStore.StorytellerStore

local store: StorytellerStore?

afterEach(function()
	if store then
		store.destroy()
		store = nil
	end
end)

local function createTarget(name: string): StoryModuleTarget
	local storyModule = Instance.new("ModuleScript")
	storyModule.Name = `{name}.story`
	storyModule.Source = `return \{ name = "{name}", story = function() end \}`

	local storybook: LoadedStorybook = {
		name = "Storybook",
		source = Instance.new("ModuleScript"),
		storyRoots = {},
	}

	return {
		storyModule = storyModule,
		storybook = storybook,
	}
end

local function createStore(): (StorytellerStore, () -> boolean, () -> number)
	local deferredCallback: (() -> ())?
	local workerThread: thread?
	local deferCount = 0

	local newStore = StorytellerStore.new(Instance.new("Folder"), {
		schedulerDriver = {
			defer = function(callback)
				deferCount += 1
				deferredCallback = callback
			end,
			now = function()
				return 0
			end,
			wait = function()
				coroutine.yield()
			end,
		},
		workBudgetSeconds = 0,
	})

	local function step(): boolean
		if not workerThread then
			if not deferredCallback then
				return false
			end
			workerThread = coroutine.create(deferredCallback)
			deferredCallback = nil
		end

		local currentThread = workerThread
		assert(currentThread, "Worker thread was not created")
		local success, problem = coroutine.resume(currentThread)
		if not success then
			error(problem)
		end
		if coroutine.status(currentThread) == "dead" then
			workerThread = nil
		end
		return true
	end

	return newStore, step, function()
		return deferCount
	end
end

test("prioritizes interactive requests and publishes within the work budget", function()
	local currentStore, step = createStore()
	store = currentStore
	local backgroundTarget = createTarget("Background")
	local interactiveTarget = createTarget("Interactive")

	local releaseBackground = currentStore.requestStoryModules({ backgroundTarget }, "background")
	local releaseInteractive = currentStore.requestStoryModules({ interactiveTarget }, "interactive")

	expect(step()).toBe(true)
	local records = currentStore.getStoryModuleRecords()
	expect(records[interactiveTarget.storyModule]).toBeDefined()
	expect(records[backgroundTarget.storyModule]).toBeUndefined()

	expect(step()).toBe(true)
	records = currentStore.getStoryModuleRecords()
	expect(records[backgroundTarget.storyModule]).toBeDefined()

	releaseInteractive()
	releaseBackground()
	local firstRecord = next(currentStore.getStoryModuleRecords())
	expect(firstRecord).toBeUndefined()
end)

test("coalesces requests and reuses the eager result", function()
	local currentStore, step, getDeferCount = createStore()
	store = currentStore
	local target = createTarget("Shared")

	local releaseBackground = currentStore.requestStoryModules({ target }, "background")
	local releaseInteractive = currentStore.requestStoryModules({ target }, "interactive")
	expect(getDeferCount()).toBe(1)

	expect(step()).toBe(true)
	expect(step()).toBe(true)
	local initialRecord = currentStore.getStoryModuleRecords()[target.storyModule][target.storybook.source]

	local releaseSecondInteractive = currentStore.requestStoryModules({ target }, "interactive")
	expect(getDeferCount()).toBe(1)
	expect(currentStore.getStoryModuleRecords()[target.storyModule][target.storybook.source]).toBe(initialRecord)

	releaseSecondInteractive()
	releaseInteractive()
	releaseBackground()
	local firstRecord = next(currentStore.getStoryModuleRecords())
	expect(firstRecord).toBeUndefined()
end)

test("removes Instance-keyed records when a Story module is destroyed", function()
	local currentStore, step = createStore()
	store = currentStore
	local target = createTarget("Disposable")
	local release = currentStore.requestStoryModules({ target }, "background")

	expect(step()).toBe(true)
	expect(step()).toBe(true)
	expect(currentStore.getStoryModuleRecords()[target.storyModule]).toBeDefined()

	target.storyModule:Destroy()
	task.wait()
	local firstRecord = next(currentStore.getStoryModuleRecords())
	expect(firstRecord).toBeUndefined()

	release()
end)

test("removes Instance-keyed records when a Storybook is destroyed", function()
	local currentStore, step = createStore()
	store = currentStore
	local firstTarget = createTarget("First")
	local secondTarget = createTarget("Second")
	secondTarget.storybook = firstTarget.storybook
	local release = currentStore.requestStoryModules({ firstTarget, secondTarget }, "background")

	expect(step()).toBe(true)
	expect(step()).toBe(true)
	expect(step()).toBe(true)
	local firstRecord = next(currentStore.getStoryModuleRecords())
	expect(firstRecord).toBeDefined()

	firstTarget.storybook.source:Destroy()
	task.wait()
	firstRecord = next(currentStore.getStoryModuleRecords())
	expect(firstRecord).toBeUndefined()

	release()
end)

test("clears records and pending work when destroyed", function()
	local currentStore, step = createStore()
	store = currentStore
	local firstTarget = createTarget("First")
	local secondTarget = createTarget("Second")

	currentStore.requestStoryModules({ firstTarget, secondTarget }, "background")
	expect(step()).toBe(true)
	local firstRecord = next(currentStore.getStoryModuleRecords())
	expect(firstRecord).toBeDefined()

	currentStore.destroy()
	firstRecord = next(currentStore.getStoryModuleRecords())
	expect(firstRecord).toBeUndefined()
	expect(step()).toBe(true)
	firstRecord = next(currentStore.getStoryModuleRecords())
	expect(firstRecord).toBeUndefined()
	store = nil
end)
