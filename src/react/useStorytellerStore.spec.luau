local JestGlobals = require("@pkg/JestGlobals")
local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")

local StorytellerContext = require("@root/react/StorytellerContext")
local StorytellerStore = require("@root/stores/StorytellerStore")
local waitFor = require("@root/test-utils/waitFor")

local useStorytellerStore = require("./useStorytellerStore")

local afterEach = JestGlobals.afterEach
local expect = JestGlobals.expect
local test = JestGlobals.test
local act = ReactRoblox.act

local roots: { ReactRoblox.RootType } = {}
local containers: { Instance } = {}
local stores: { StorytellerStore.StorytellerStore } = {}
local originalGet = StorytellerStore.get

local function createStore(): (StorytellerStore.StorytellerStore, Folder)
	local folder = Instance.new("Folder")
	table.insert(containers, folder)
	local store = StorytellerStore.new(folder)
	table.insert(stores, store)
	return store, folder
end

local function addStorybook(folder: Folder, name: string)
	local module = Instance.new("ModuleScript")
	module.Name = `{name}.storybook`
	module.Source = "return { storyRoots = {} }"
	module.Parent = folder
end

local function createRoot(): ReactRoblox.RootType
	local folder = Instance.new("Folder")
	table.insert(containers, folder)
	local root = ReactRoblox.createRoot(folder)
	table.insert(roots, root)
	return root
end

local function Consumer()
	useStorytellerStore()
	return nil
end

afterEach(function()
	act(function()
		for _, root in roots do
			root:unmount()
		end
	end)
	StorytellerStore.get = originalGet
	for _, store in stores do
		store.destroy()
	end
	for _, container in containers do
		container:Destroy()
	end
	table.clear(roots)
	table.clear(stores)
	table.clear(containers)
end)

local function exerciseConsumers(isProviderless: boolean)
	local store, folder = createStore()
	if isProviderless then
		StorytellerStore.get = function()
			return store
		end
	end
	local first = createRoot()
	local second = createRoot()
	local function element()
		if isProviderless then
			return React.createElement(Consumer)
		end
		return React.createElement(StorytellerContext.StorytellerProvider, {
			store = store,
		})
	end
	act(function()
		first:render(element())
		second:render(element())
	end)
	addStorybook(folder, "First")
	waitFor(function()
		expect(#store.getLoadedStorybooks()).toBe(1)
	end)
	act(function()
		first:render(nil)
	end)
	addStorybook(folder, "Second")
	waitFor(function()
		expect(#store.getLoadedStorybooks()).toBe(2)
	end)
	act(function()
		second:render(nil)
	end)
	expect(store.getLoadedStorybooks()).toEqual({})
	act(function()
		second:render(element())
	end)
	waitFor(function()
		expect(#store.getLoadedStorybooks()).toBe(2)
	end)
end

test("providers keep discovery alive until final cleanup and restart on remount", function()
	exerciseConsumers(false)
end)

test("providerless hooks keep discovery alive until final cleanup and restart on remount", function()
	exerciseConsumers(true)
end)

test("switching a provider store releases the old store and acquires the new store", function()
	local oldStore, oldFolder = createStore()
	local newStore, newFolder = createStore()
	addStorybook(oldFolder, "Old")
	addStorybook(newFolder, "New")
	local root = createRoot()
	local function render(store: StorytellerStore.StorytellerStore)
		act(function()
			root:render(React.createElement(StorytellerContext.StorytellerProvider, {
				store = store,
			}, React.createElement(Consumer)))
		end)
	end
	render(oldStore)
	waitFor(function()
		expect(#oldStore.getLoadedStorybooks()).toBe(1)
	end)
	render(newStore)
	waitFor(function()
		expect(#newStore.getLoadedStorybooks()).toBe(1)
	end)
	expect(oldStore.getLoadedStorybooks()).toEqual({})
	act(function()
		root:render(nil)
	end)
	expect(newStore.getLoadedStorybooks()).toEqual({})
end)

test("releasing a lease twice cannot stop another consumer", function()
	local store, folder = createStore()
	local releaseFirst = store.acquire()
	local releaseSecond = store.acquire()
	releaseFirst()
	releaseFirst()
	addStorybook(folder, "Remaining")
	waitFor(function()
		expect(#store.getLoadedStorybooks()).toBe(1)
	end)
	releaseSecond()
	expect(store.getLoadedStorybooks()).toEqual({})
end)
