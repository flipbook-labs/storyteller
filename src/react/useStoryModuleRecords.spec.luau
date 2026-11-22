local Charm = require("@pkg/Charm")
local JestGlobals = require("@pkg/JestGlobals")
local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRoblox = require("@pkg/ReactRoblox")

local StoryModuleRecordStore = require("@root/stores/StoryModuleRecordStore")
local StorytellerContext = require("./StorytellerContext")
local StorytellerStore = require("@root/stores/StorytellerStore")
local renderHook = require("@root/test-utils/renderHook")
local types = require("@root/types")
local useStoryModuleRecords = require("./useStoryModuleRecords")
local waitFor = require("@root/test-utils/waitFor")

local act = ReactRoblox.act
local expect = JestGlobals.expect
local test = JestGlobals.test
local useSignalState = ReactCharm.useSignalState

test("loads records and isolates malformed modules", function()
	local validStoryModule = Instance.new("ModuleScript")
	validStoryModule.Name = "Valid.story"
	validStoryModule.Source = [[
		return {
			stories = {
				Alpha = function() end,
				Beta = function() end,
			},
		}
	]]

	local invalidStoryModule = Instance.new("ModuleScript")
	invalidStoryModule.Name = "Invalid.story"
	invalidStoryModule.Source = "syntax error"

	local storybook: types.LoadedStorybook = {
		name = "Storybook",
		source = Instance.new("ModuleScript"),
		storyRoots = {},
	}
	local requests: { StoryModuleRecordStore.StoryRequest } = {
		{
			storyModule = validStoryModule,
			storybook = storybook,
		},
		{
			storyModule = invalidStoryModule,
			storybook = storybook,
		},
	}

	local get = renderHook(function()
		return useStoryModuleRecords(requests)
	end)

	act(function()
		task.wait(0.1)
	end)

	waitFor(function()
		local records = get()
		local recordsForStorybook = records[storybook.source]
		local validRecord = recordsForStorybook[validStoryModule]
		local invalidRecord = recordsForStorybook[invalidStoryModule]
		expect(validRecord.stories).toEqual({
			expect.objectContaining({ id = "Alpha", name = "Alpha" }),
			expect.objectContaining({ id = "Beta", name = "Beta" }),
		})
		expect(invalidRecord.problem).toBeDefined()
	end)

	act(function()
		invalidStoryModule.Source = [[
			return {
				story = function() end,
			}
		]]
		task.wait(0.1)
	end)

	waitFor(function()
		local record = get()[storybook.source][invalidStoryModule]
		expect(record.problem).toBeUndefined()
		expect(record.stories).toEqual({
			expect.objectContaining({
				id = "default",
				name = "Invalid",
			}),
		})
	end)

	storybook.source:Destroy()
	validStoryModule:Destroy()
	invalidStoryModule:Destroy()
end)

test("releases requested records when the consumer unmounts", function()
	local storyModule = Instance.new("ModuleScript")
	storyModule.Name = "Unmounted.story"
	storyModule.Source = "return { story = function() end }"

	local storybook: types.LoadedStorybook = {
		name = "Storybook",
		source = Instance.new("ModuleScript"),
		storyRoots = {},
	}
	local store = StorytellerStore.get()
	store.stop()
	-- Holding a store lease keeps the store running through unmount. Otherwise
	-- the store's stop() clears every record, and the assertion below would
	-- pass even if the hook never released its request.
	local releaseStore = store.acquire()

	local function Wrapper(): React.ReactNode
		useStoryModuleRecords({
			{
				storyModule = storyModule,
				storybook = storybook,
			},
		})
		return nil
	end

	local container = Instance.new("Folder")
	local root = ReactRoblox.createRoot(container)
	act(function()
		root:render(React.createElement(Wrapper))
	end)

	waitFor(function()
		local recordsForStorybook = store.getStoryModuleRecords()[storybook.source]
		local record = if recordsForStorybook then recordsForStorybook[storyModule] else nil
		assert(record and record.stories, "expected the requested record to load")
		expect(record.stories[1].id).toBe("default")
	end)

	act(function()
		root:unmount()
	end)
	expect(store.getStoryModuleRecords()[storybook.source]).toBeUndefined()

	releaseStore()
	store.stop()
	storybook.source:Destroy()
	storyModule:Destroy()
	container:Destroy()
end)

test("reads records from the new store when the provider's store changes", function()
	local storyModule = Instance.new("ModuleScript")
	storyModule.Name = "Swapped.story"
	storyModule.Source = "return { story = function() end }"

	local storybook: types.LoadedStorybook = {
		name = "Storybook",
		source = Instance.new("ModuleScript"),
		storyRoots = {},
	}
	local request: StoryModuleRecordStore.StoryRequest = {
		storyModule = storyModule,
		storybook = storybook,
	}
	local firstStore = StorytellerStore.new(Instance.new("Folder"))
	local secondStore = StorytellerStore.new(Instance.new("Folder"))
	local currentStore = firstStore
	local getRenderVersion, setRenderVersion = Charm.signal(0)

	local function Wrapper(props): React.ReactNode
		useSignalState(getRenderVersion)
		return React.createElement(StorytellerContext.StorytellerProvider, {
			store = currentStore,
		}, props.children)
	end

	local get = renderHook(function()
		return useStoryModuleRecords({ request })
	end, {
		wrapper = Wrapper,
	})

	act(function()
		task.wait(0.1)
	end)

	waitFor(function()
		local record = firstStore.getStoryModuleRecord(request)
		assert(record and record.stories, "expected the first store to load the record")
	end)

	act(function()
		currentStore = secondStore
		setRenderVersion(1)
		task.wait(0.1)
	end)

	waitFor(function()
		local expected = secondStore.getStoryModuleRecord(request)
		assert(expected and expected.stories, "expected the second store to load the record")
		local recordsForStorybook = get()[storybook.source]
		local record = if recordsForStorybook then recordsForStorybook[storyModule] else nil
		expect(record).toBe(expected)
	end)

	firstStore.destroy()
	secondStore.destroy()
	storybook.source:Destroy()
	storyModule:Destroy()
end)

test("reloads every module when its Storybook is replaced alongside another module", function()
	local firstStoryModule = Instance.new("ModuleScript")
	firstStoryModule.Name = "First.story"
	firstStoryModule.Source = [[
		script:SetAttribute("LoadCount", (script:GetAttribute("LoadCount") or 0) + 1)
		return { story = function() end }
	]]

	local secondStoryModule = Instance.new("ModuleScript")
	secondStoryModule.Name = "Second.story"
	secondStoryModule.Source = [[
		script:SetAttribute("LoadCount", (script:GetAttribute("LoadCount") or 0) + 1)
		return { story = function() end }
	]]

	local source = Instance.new("ModuleScript")
	local storybook: types.LoadedStorybook = {
		name = "Storybook",
		source = source,
		storyRoots = {},
		packages = { Dependency = "first" },
	}
	local replacedStorybook: types.LoadedStorybook = {
		name = "Storybook",
		source = source,
		storyRoots = {},
		packages = { Dependency = "second" },
	}
	local requests: { StoryModuleRecordStore.StoryRequest } = {
		{
			storyModule = firstStoryModule,
			storybook = storybook,
		},
		{
			storyModule = secondStoryModule,
			storybook = storybook,
		},
	}
	local getRenderVersion, setRenderVersion = Charm.signal(0)
	local store = StorytellerStore.new(Instance.new("Folder"))

	local function Wrapper(props): React.ReactNode
		return React.createElement(StorytellerContext.StorytellerProvider, {
			store = store,
		}, props.children)
	end

	local get = renderHook(function()
		useSignalState(getRenderVersion)
		return useStoryModuleRecords(requests)
	end, {
		wrapper = Wrapper,
	})

	act(function()
		task.wait(0.1)
	end)

	waitFor(function()
		local recordsForStorybook = get()[source]
		local record = if recordsForStorybook then recordsForStorybook[firstStoryModule] else nil
		assert(record and record.stories, "expected the first record to load")
	end)

	act(function()
		requests = {
			{
				storyModule = firstStoryModule,
				storybook = replacedStorybook,
			},
			{
				storyModule = secondStoryModule,
				storybook = replacedStorybook,
			},
		}
		setRenderVersion(1)
		task.wait(0.1)
	end)

	waitFor(function()
		local recordsForStorybook = get()[source]
		assert(recordsForStorybook, "expected records for the replaced Storybook")
		for _, storyModule in { firstStoryModule, secondStoryModule } do
			local record = recordsForStorybook[storyModule]
			assert(record and record.stories, "expected the record to reload")
			expect(record.stories[1].packages).toEqual({ Dependency = "second" })
		end
	end)
	expect(firstStoryModule:GetAttribute("LoadCount")).toBe(2)
	expect(secondStoryModule:GetAttribute("LoadCount")).toBe(2)

	store.destroy()
	source:Destroy()
	firstStoryModule:Destroy()
	secondStoryModule:Destroy()
end)

test("keeps records for every Storybook that covers a module", function()
	local storyModule = Instance.new("ModuleScript")
	storyModule.Name = "Shared.story"
	storyModule.Source = "return { story = function() end }"

	local firstStorybook: types.LoadedStorybook = {
		name = "First",
		source = Instance.new("ModuleScript"),
		storyRoots = {},
	}
	local secondStorybook: types.LoadedStorybook = {
		name = "Second",
		source = Instance.new("ModuleScript"),
		storyRoots = {},
	}

	local get = renderHook(function()
		return useStoryModuleRecords({
			{
				storyModule = storyModule,
				storybook = firstStorybook,
			},
			{
				storyModule = storyModule,
				storybook = secondStorybook,
			},
		})
	end)

	act(function()
		task.wait(0.1)
	end)

	waitFor(function()
		local records = get()
		expect(records[firstStorybook.source][storyModule]).toBeDefined()
		expect(records[secondStorybook.source][storyModule]).toBeDefined()
	end)

	firstStorybook.source:Destroy()
	secondStorybook.source:Destroy()
	storyModule:Destroy()
end)

test("does not reload when an equivalent request array is recreated", function()
	local storyModule = Instance.new("ModuleScript")
	storyModule.Name = "Stable.story"
	storyModule.Source = [[
		script:SetAttribute("LoadCount", (script:GetAttribute("LoadCount") or 0) + 1)
		return { story = function() end }
	]]

	local storybook: types.LoadedStorybook = {
		name = "Storybook",
		source = Instance.new("ModuleScript"),
		storyRoots = {},
	}
	local getRenderVersion, setRenderVersion = Charm.signal(0)

	renderHook(function()
		useSignalState(getRenderVersion)
		return useStoryModuleRecords({
			{
				storyModule = storyModule,
				storybook = storybook,
			},
		})
	end)

	act(function()
		task.wait(0.2)
		setRenderVersion(1)
		task.wait(0.2)
	end)

	expect(storyModule:GetAttribute("LoadCount")).toBe(1)

	storybook.source:Destroy()
	storyModule:Destroy()
end)

test("does not reload existing requests when requests are added or removed", function()
	local firstStoryModule = Instance.new("ModuleScript")
	firstStoryModule.Name = "First.story"
	firstStoryModule.Source = [[
		script:SetAttribute("LoadCount", (script:GetAttribute("LoadCount") or 0) + 1)
		return { story = function() end }
	]]

	local secondStoryModule = Instance.new("ModuleScript")
	secondStoryModule.Name = "Second.story"
	secondStoryModule.Source = [[
		script:SetAttribute("LoadCount", (script:GetAttribute("LoadCount") or 0) + 1)
		return { story = function() end }
	]]

	local firstStorybook: types.LoadedStorybook = {
		name = "First",
		source = Instance.new("ModuleScript"),
		storyRoots = {},
	}
	local secondStorybook: types.LoadedStorybook = {
		name = "Second",
		source = Instance.new("ModuleScript"),
		storyRoots = {},
	}
	local firstRequest: StoryModuleRecordStore.StoryRequest = {
		storyModule = firstStoryModule,
		storybook = firstStorybook,
	}
	local secondRequest: StoryModuleRecordStore.StoryRequest = {
		storyModule = secondStoryModule,
		storybook = secondStorybook,
	}
	local requests = { firstRequest }
	local getRenderVersion, setRenderVersion = Charm.signal(0)
	local root = Instance.new("Folder")
	local store = StorytellerStore.new(root)

	local function Wrapper(props): React.ReactNode
		return React.createElement(StorytellerContext.StorytellerProvider, {
			store = store,
		}, props.children)
	end

	local get = renderHook(function()
		useSignalState(getRenderVersion)
		return useStoryModuleRecords(requests)
	end, {
		wrapper = Wrapper,
	})

	act(function()
		task.wait(0.1)
	end)

	waitFor(function()
		local recordsForStorybook = get()[firstStorybook.source]
		local record = if recordsForStorybook then recordsForStorybook[firstStoryModule] else nil
		assert(record and record.stories, "expected the first record to load")
		expect(record.stories[1].id).toBe("default")
	end)

	act(function()
		requests = { firstRequest, secondRequest }
		setRenderVersion(1)
		task.wait(0.1)
	end)
	act(function()
		task.wait(0.1)
	end)

	waitFor(function()
		local recordsForStorybook = get()[secondStorybook.source]
		local record = if recordsForStorybook then recordsForStorybook[secondStoryModule] else nil
		assert(record and record.stories, "expected the second record to load")
		expect(record.stories[1].id).toBe("default")
	end)
	expect(firstStoryModule:GetAttribute("LoadCount")).toBe(1)
	expect(secondStoryModule:GetAttribute("LoadCount")).toBe(1)

	act(function()
		requests = { secondRequest }
		setRenderVersion(2)
		task.wait(0.1)
	end)
	act(function()
		task.wait(0.1)
	end)
	expect(secondStoryModule:GetAttribute("LoadCount")).toBe(1)
	expect(store.getStoryModuleRecord(firstRequest)).toBeUndefined()
	expect(store.getStoryModuleRecord(secondRequest)).toBeDefined()

	store.destroy()
	root:Destroy()
	firstStorybook.source:Destroy()
	secondStorybook.source:Destroy()
	firstStoryModule:Destroy()
	secondStoryModule:Destroy()
end)
