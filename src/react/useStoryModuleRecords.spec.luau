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
		local validRecord = records[validStoryModule][storybook.source]
		local invalidRecord = records[invalidStoryModule][storybook.source]
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
		local record = get()[invalidStoryModule][storybook.source]
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
		local recordsForModule = get()[storyModule]
		expect(recordsForModule[firstStorybook.source]).toBeDefined()
		expect(recordsForModule[secondStorybook.source]).toBeDefined()
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
		local recordsForModule = get()[firstStoryModule]
		local record = if recordsForModule then recordsForModule[firstStorybook.source] else nil
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
		local recordsForModule = get()[secondStoryModule]
		local record = if recordsForModule then recordsForModule[secondStorybook.source] else nil
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

	store.destroy()
	root:Destroy()
	firstStorybook.source:Destroy()
	secondStorybook.source:Destroy()
	firstStoryModule:Destroy()
	secondStoryModule:Destroy()
end)
