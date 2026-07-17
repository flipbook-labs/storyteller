local Charm = require("@pkg/Charm")
local ModuleLoader = require("@pkg/ModuleLoader")
local Sift = require("@pkg/Sift")

local constants = require("@root/constants")
local debounce = require("@root/debounce")
local isOrphanedStoryModule = require("@root/isOrphanedStoryModule")
local isStoryModule = require("@root/isStoryModule")
local isStorybookModule = require("@root/isStorybookModule")
local loadStoryModuleData = require("@root/loadStoryModuleData")
local loadStorybookModule = require("@root/loadStorybookModule")
local query = require("@root/stores/query")
local types = require("@root/types")

type LoadedStorybook = types.LoadedStorybook
type UnavailableStorybook = types.UnavailableStorybook
type LoadedStory<T> = types.LoadedStory<T>
type StoryModuleSnapshot = types.StoryModuleSnapshot
type StoryModuleTarget = types.StoryModuleTarget

export type StoryModuleRecord = {
	snapshot: StoryModuleSnapshot,
	stories: { LoadedStory<unknown> }?,
	problem: string?,
}

export type StoryModuleRecords = {
	[ModuleScript]: {
		[ModuleScript]: StoryModuleRecord,
	},
}

export type StoryModuleRequestPriority = "background" | "interactive"

export type StorytellerStore = {
	start: () -> (),
	stop: () -> (),
	destroy: () -> (),

	getLoadedStorybooks: () -> { LoadedStorybook },
	getUnavailableStorybooks: () -> { UnavailableStorybook },

	getStorybookModules: () -> { ModuleScript },
	getStoryModules: () -> { ModuleScript },
	getOrphanedStoryModules: () -> { ModuleScript },

	getStoryModuleRecords: () -> StoryModuleRecords,
	requestStoryModules: (targets: { StoryModuleTarget }, priority: StoryModuleRequestPriority?) -> () -> (),
}

type TargetEntry = {
	target: StoryModuleTarget,
	loaderSource: ModuleScript,
	refCount: number,
	interactiveRefCount: number,
	generation: number,
	isLoading: boolean,
	queuedPriority: StoryModuleRequestPriority?,
	reloadLoader: ModuleLoader.ModuleLoader?,
	reloadConnection: RBXScriptConnection?,
	sourceConnection: RBXScriptConnection?,
	destroyingConnection: RBXScriptConnection?,
}

type LoaderEntry = {
	loader: ModuleLoader.ModuleLoader,
	connection: RBXScriptConnection,
	destroyingConnection: RBXScriptConnection,
	targets: { [ModuleScript]: TargetEntry },
}

type TargetQueue = {
	items: { [number]: TargetEntry },
	head: number,
	tail: number,
}

type PendingPublication = {
	generation: number,
	record: StoryModuleRecord,
}

local WORK_BUDGET_MS = 4

local StorytellerStore = {}

function StorytellerStore.new(root: Instance): StorytellerStore
	local self = {}

	local connections: { RBXScriptConnection } = {}
	local disposeStorybookModuleObserver
	local disposeStorybookModulesSubscription
	local disposeStoryModuleObserver
	local disposeStoryModulesSubscription

	local isDestroyed = false
	local isRunning = false

	local getStoryModules, setStoryModules = Charm.signal({} :: { ModuleScript })
	self.getStoryModules = getStoryModules

	local getStorybookModules, setStorybookModules = Charm.signal({} :: { ModuleScript })
	self.getStorybookModules = getStorybookModules

	local getLoadedStorybooks, setLoadedStorybooks = Charm.signal({} :: { LoadedStorybook })
	self.getLoadedStorybooks = getLoadedStorybooks

	local getUnavailableStorybooks, setUnavailableStorybooks = Charm.signal({} :: { UnavailableStorybook })
	self.getUnavailableStorybooks = getUnavailableStorybooks

	local getStoryModuleRecords, setStoryModuleRecords = Charm.signal({} :: StoryModuleRecords)
	self.getStoryModuleRecords = getStoryModuleRecords

	local targetEntries = {} :: { [ModuleScript]: { [ModuleScript]: TargetEntry } }
	local loaderEntries = {} :: { [ModuleScript]: LoaderEntry }
	local backgroundQueue: TargetQueue = {
		items = {},
		head = 1,
		tail = 0,
	}
	local interactiveQueue: TargetQueue = {
		items = {},
		head = 1,
		tail = 0,
	}
	local isProcessingTargets = false

	local processPendingTargets: () -> ()
	local queueTarget: (entry: TargetEntry, priority: StoryModuleRequestPriority, invalidate: boolean) -> ()
	local invalidateTarget: (entry: TargetEntry, priority: StoryModuleRequestPriority) -> ()
	local cleanupTargetEntry: (entry: TargetEntry) -> ()

	local function getTargetEntry(storyModule: ModuleScript, storybookSource: ModuleScript): TargetEntry?
		local entriesForModule = targetEntries[storyModule]
		return if entriesForModule then entriesForModule[storybookSource] else nil
	end

	local function setTargetEntry(entry: TargetEntry)
		local storyModule = entry.target.storyModule
		local entriesForModule = targetEntries[storyModule]
		if not entriesForModule then
			entriesForModule = {}
			targetEntries[storyModule] = entriesForModule
		end
		entriesForModule[entry.loaderSource] = entry
	end

	local function removeTargetEntry(entry: TargetEntry)
		local storyModule = entry.target.storyModule
		local entriesForModule = targetEntries[storyModule]
		if not entriesForModule or entriesForModule[entry.loaderSource] ~= entry then
			return
		end

		entriesForModule[entry.loaderSource] = nil
		if next(entriesForModule) == nil then
			targetEntries[storyModule] = nil
		end
	end

	local function removeStoryModuleRecord(storyModule: ModuleScript, storybookSource: ModuleScript)
		setStoryModuleRecords(function(previous)
			local previousForModule = previous[storyModule]
			if not previousForModule or not previousForModule[storybookSource] then
				return previous
			end

			local nextRecords = table.clone(previous)
			local nextForModule = table.clone(previousForModule)
			nextForModule[storybookSource] = nil
			if next(nextForModule) == nil then
				nextRecords[storyModule] = nil
			else
				nextRecords[storyModule] = nextForModule
			end
			return nextRecords
		end)
	end

	local function publishStoryModuleRecords(publications: { [TargetEntry]: PendingPublication })
		if next(publications) == nil then
			return
		end

		setStoryModuleRecords(function(previous)
			local nextRecords = table.clone(previous)
			local clonedModules = {} :: { [ModuleScript]: boolean }

			for entry, publication in publications do
				local target = entry.target
				if
					entry.refCount > 0
					and entry.generation == publication.generation
					and getTargetEntry(target.storyModule, entry.loaderSource) == entry
				then
					local recordsForModule = nextRecords[target.storyModule]
					if not clonedModules[target.storyModule] then
						recordsForModule = if recordsForModule then table.clone(recordsForModule) else {}
						nextRecords[target.storyModule] = recordsForModule
						clonedModules[target.storyModule] = true
					end
					recordsForModule[entry.loaderSource] = publication.record
				end
			end

			return nextRecords
		end)
	end

	local function resetQueue(targetQueue: TargetQueue)
		table.clear(targetQueue.items)
		targetQueue.head = 1
		targetQueue.tail = 0
	end

	local function pushQueue(targetQueue: TargetQueue, entry: TargetEntry)
		targetQueue.tail += 1
		targetQueue.items[targetQueue.tail] = entry
	end

	local function popQueue(targetQueue: TargetQueue, priority: StoryModuleRequestPriority): TargetEntry?
		while targetQueue.head <= targetQueue.tail do
			local index = targetQueue.head
			local entry = targetQueue.items[index]
			targetQueue.items[index] = nil
			targetQueue.head += 1

			if entry and entry.refCount > 0 and entry.queuedPriority == priority then
				if targetQueue.head > targetQueue.tail then
					resetQueue(targetQueue)
				end
				return entry
			end
		end

		resetQueue(targetQueue)
		return nil
	end

	local function ensureLoaderEntry(storybookSource: ModuleScript): LoaderEntry
		local existing = loaderEntries[storybookSource]
		if existing then
			return existing
		end

		local loader = ModuleLoader.new()
		local loaderEntry: LoaderEntry
		loaderEntry = {
			loader = loader,
			connection = loader.loadedModuleChanged:Connect(function(changedModule)
				local changedTarget = loaderEntry.targets[changedModule]
				if changedTarget and not changedTarget.reloadLoader then
					invalidateTarget(
						changedTarget,
						if changedTarget.interactiveRefCount > 0 then "interactive" else "background"
					)
					return
				end

				for _, entry in loaderEntry.targets do
					if not entry.reloadLoader then
						invalidateTarget(entry, if entry.interactiveRefCount > 0 then "interactive" else "background")
					end
				end
			end),
			destroyingConnection = storybookSource.Destroying:Connect(function()
				local entries = {}
				for _, entry in loaderEntry.targets do
					table.insert(entries, entry)
				end
				for _, entry in entries do
					cleanupTargetEntry(entry)
				end
			end),
			targets = {},
		}
		loaderEntries[storybookSource] = loaderEntry
		return loaderEntry
	end

	local function cleanupLoaderEntry(storybookSource: ModuleScript)
		local loaderEntry = loaderEntries[storybookSource]
		if loaderEntry and next(loaderEntry.targets) == nil then
			loaderEntry.connection:Disconnect()
			loaderEntry.destroyingConnection:Disconnect()
			table.clear(loaderEntry.targets)
			loaderEntries[storybookSource] = nil
		end
	end

	cleanupTargetEntry = function(entry: TargetEntry)
		entry.refCount = 0
		entry.interactiveRefCount = 0
		entry.generation += 1
		entry.queuedPriority = nil

		if entry.sourceConnection then
			entry.sourceConnection:Disconnect()
			entry.sourceConnection = nil
		end
		if entry.destroyingConnection then
			entry.destroyingConnection:Disconnect()
			entry.destroyingConnection = nil
		end
		if entry.reloadConnection then
			entry.reloadConnection:Disconnect()
			entry.reloadConnection = nil
		end
		entry.reloadLoader = nil

		local loaderEntry = loaderEntries[entry.loaderSource]
		if loaderEntry and loaderEntry.targets[entry.target.storyModule] == entry then
			loaderEntry.targets[entry.target.storyModule] = nil
		end

		removeTargetEntry(entry)
		removeStoryModuleRecord(entry.target.storyModule, entry.loaderSource)
		cleanupLoaderEntry(entry.loaderSource)
	end

	local function createStoryModuleRecord(entry: TargetEntry): StoryModuleRecord
		local target = entry.target
		local loaderEntry = loaderEntries[entry.loaderSource]
		assert(loaderEntry, "Story module loader was cleaned up while a target was loading")
		local loader = entry.reloadLoader or loaderEntry.loader

		local success, result = pcall(function()
			return loadStoryModuleData(target.storyModule, target.storybook, loader)
		end)

		if not success then
			local problem = tostring(result)
			return {
				snapshot = {
					name = target.storyModule.Name:gsub(constants.STORY_NAME_PATTERN, ""),
					source = target.storyModule,
					stories = {},
					problem = problem,
				},
				problem = problem,
			}
		end

		local stories = result.stories :: { LoadedStory<unknown> }
		local storySnapshots = {}
		for _, story in stories do
			table.insert(storySnapshots, {
				id = story.id,
				name = story.name,
				summary = story.summary,
			})
		end

		return {
			snapshot = {
				name = result.name,
				source = target.storyModule,
				stories = storySnapshots,
			},
			stories = stories,
		}
	end

	processPendingTargets = function()
		if isProcessingTargets or isDestroyed then
			return
		end
		isProcessingTargets = true

		task.defer(function()
			local publications = {} :: { [TargetEntry]: PendingPublication }
			local workStarted = os.clock()

			while not isDestroyed do
				local entry = popQueue(interactiveQueue, "interactive") or popQueue(backgroundQueue, "background")
				if not entry then
					break
				end

				entry.queuedPriority = nil
				entry.isLoading = true
				local generation = entry.generation
				local record = createStoryModuleRecord(entry)
				entry.isLoading = false
				publications[entry] = {
					generation = generation,
					record = record,
				}

				if (os.clock() - workStarted) * 1000 >= WORK_BUDGET_MS then
					publishStoryModuleRecords(publications)
					publications = {}
					task.wait()
					workStarted = os.clock()
				end
			end

			publishStoryModuleRecords(publications)
			isProcessingTargets = false
		end)
	end

	queueTarget = function(entry: TargetEntry, priority: StoryModuleRequestPriority, invalidate: boolean)
		if isDestroyed or entry.refCount == 0 then
			return
		end

		if invalidate then
			entry.generation += 1
		end

		if entry.queuedPriority == "interactive" then
			return
		end
		if entry.queuedPriority == priority then
			return
		end

		entry.queuedPriority = priority
		if priority == "interactive" then
			pushQueue(interactiveQueue, entry)
		else
			pushQueue(backgroundQueue, entry)
		end
		processPendingTargets()
	end

	invalidateTarget = function(entry: TargetEntry, priority: StoryModuleRequestPriority)
		if isDestroyed or entry.refCount == 0 then
			return
		end

		if entry.reloadConnection then
			entry.reloadConnection:Disconnect()
			entry.reloadConnection = nil
		end

		local loader = ModuleLoader.new()
		entry.reloadLoader = loader
		entry.reloadConnection = loader.loadedModuleChanged:Connect(function()
			invalidateTarget(entry, if entry.interactiveRefCount > 0 then "interactive" else "background")
		end)
		queueTarget(entry, priority, true)
	end

	local function requestStoryModules(targets: { StoryModuleTarget }, priority: StoryModuleRequestPriority?): () -> ()
		if isDestroyed then
			return function() end
		end

		local requestPriority: StoryModuleRequestPriority = priority or "background"
		local acquiredEntries = {} :: { TargetEntry }
		local acquiredByModule = {} :: { [ModuleScript]: { [ModuleScript]: boolean } }

		for _, target in targets do
			local storyModule = target.storyModule
			local storybookSource = target.storybook.source
			local acquiredForModule = acquiredByModule[storyModule]
			if not acquiredForModule then
				acquiredForModule = {}
				acquiredByModule[storyModule] = acquiredForModule
			end
			if acquiredForModule[storybookSource] then
				continue
			end
			acquiredForModule[storybookSource] = true

			local existingEntry = getTargetEntry(storyModule, storybookSource)
			local entry: TargetEntry
			local targetChanged = false
			if existingEntry then
				entry = existingEntry
				if entry.target.storybook ~= target.storybook then
					entry.target = target
					targetChanged = true
				end
			else
				local newEntry: TargetEntry = {
					target = target,
					loaderSource = storybookSource,
					refCount = 0,
					interactiveRefCount = 0,
					generation = 1,
					isLoading = false,
					queuedPriority = nil,
					reloadLoader = nil,
					reloadConnection = nil,
					sourceConnection = nil,
					destroyingConnection = nil,
				}
				entry = newEntry
				setTargetEntry(entry)

				local loaderEntry = ensureLoaderEntry(storybookSource)
				loaderEntry.targets[storyModule] = entry
				entry.sourceConnection = storyModule:GetPropertyChangedSignal("Source"):Connect(function()
					invalidateTarget(entry, if entry.interactiveRefCount > 0 then "interactive" else "background")
				end)
				entry.destroyingConnection = storyModule.Destroying:Connect(function()
					cleanupTargetEntry(entry)
				end)
			end

			entry.refCount += 1
			if requestPriority == "interactive" then
				entry.interactiveRefCount += 1
			end
			table.insert(acquiredEntries, entry)

			local recordsForModule = getStoryModuleRecords()[storyModule]
			local record = if recordsForModule then recordsForModule[storybookSource] else nil
			if targetChanged then
				invalidateTarget(entry, requestPriority)
			elseif not record and not entry.isLoading then
				queueTarget(entry, requestPriority, false)
			elseif entry.queuedPriority == "background" and requestPriority == "interactive" then
				queueTarget(entry, "interactive", false)
			end
		end

		local isReleased = false
		return function()
			if isReleased then
				return
			end
			isReleased = true

			for _, entry in acquiredEntries do
				if requestPriority == "interactive" then
					entry.interactiveRefCount = math.max(0, entry.interactiveRefCount - 1)
				end
				entry.refCount = math.max(0, entry.refCount - 1)
				if entry.refCount == 0 then
					cleanupTargetEntry(entry)
				end
			end
			table.clear(acquiredEntries)
			table.clear(acquiredByModule)
		end
	end
	self.requestStoryModules = requestStoryModules

	local function clearStoryModuleRequests()
		for _, entriesForModule in targetEntries do
			for _, entry in entriesForModule do
				entry.refCount = 0
				entry.interactiveRefCount = 0
				entry.generation += 1
				entry.queuedPriority = nil
				if entry.sourceConnection then
					entry.sourceConnection:Disconnect()
					entry.sourceConnection = nil
				end
				if entry.destroyingConnection then
					entry.destroyingConnection:Disconnect()
					entry.destroyingConnection = nil
				end
				if entry.reloadConnection then
					entry.reloadConnection:Disconnect()
					entry.reloadConnection = nil
				end
				entry.reloadLoader = nil
			end
			table.clear(entriesForModule)
		end
		table.clear(targetEntries)

		for _, loaderEntry in loaderEntries do
			loaderEntry.connection:Disconnect()
			loaderEntry.destroyingConnection:Disconnect()
			table.clear(loaderEntry.targets)
		end
		table.clear(loaderEntries)

		resetQueue(backgroundQueue)
		resetQueue(interactiveQueue)
		setStoryModuleRecords({})
	end

	local getOrphanedStoryModules = Charm.computed(function(): { ModuleScript }
		local orphans = {}
		for _, storyModule in getStoryModules() do
			assert(storyModule:IsA("ModuleScript"), "Luau")

			if isOrphanedStoryModule(storyModule, getLoadedStorybooks()) then
				table.insert(orphans, storyModule)
			end
		end
		return orphans
	end)
	self.getOrphanedStoryModules = getOrphanedStoryModules

	local storyModulesQuery = query({
		root = root,
		selector = "ModuleScript",
		matcher = isStoryModule,
	})

	local storybookModulesQuery = query({
		root = root,
		selector = "ModuleScript",
		matcher = isStorybookModule,
	})

	local function loadStorybook(storybookModule: ModuleScript)
		local loader = ModuleLoader.new()

		local storybook: LoadedStorybook?
		local success, result = pcall(function()
			storybook = loadStorybookModule(storybookModule, loader)
		end)

		if success and storybook then
			setLoadedStorybooks(function(prev)
				local new = table.clone(prev)
				local index = Sift.List.findWhere(new, function(other)
					return other.source == storybookModule
				end)
				if index then
					table.remove(new, index)
				end

				table.insert(new, storybook)

				return new
			end)
		else
			setUnavailableStorybooks(function(prev)
				local new = table.clone(prev)
				local index = Sift.List.findWhere(new, function(other)
					return other.storybook.source == storybookModule
				end)

				if index then
					table.remove(new, index)
				end

				local unavailableStorybook: UnavailableStorybook = {
					problem = result,
					storybook = {
						name = storybookModule.Name,
						source = storybookModule,
						storyRoots = {},
					},
				}
				table.insert(new, unavailableStorybook)

				return new
			end)
		end
	end

	local function unloadStorybook(storybookModule: ModuleScript)
		Charm.batch(function()
			setLoadedStorybooks(function(prev)
				return Sift.List.filter(prev, function(storybook)
					return storybook.source ~= storybookModule
				end)
			end)

			setUnavailableStorybooks(function(prev)
				return Sift.List.filter(prev, function(unavailableStorybook)
					return unavailableStorybook.storybook.source ~= storybookModule
				end)
			end)
		end)
	end

	local function reloadStorybook(storybookModule: ModuleScript)
		Charm.batch(function()
			unloadStorybook(storybookModule)
			loadStorybook(storybookModule)
		end)
	end

	local function stop()
		if isDestroyed then
			return
		end
		if not isRunning then
			clearStoryModuleRequests()
			return
		end
		isRunning = false

		storyModulesQuery.stop()
		storybookModulesQuery.stop()

		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)

		disposeStorybookModuleObserver()
		disposeStorybookModulesSubscription()
		disposeStoryModuleObserver()
		disposeStoryModulesSubscription()
		clearStoryModuleRequests()
	end
	self.stop = stop

	local function start()
		if isDestroyed or isRunning then
			return
		end
		isRunning = true

		disposeStoryModulesSubscription = Charm.listen(storyModulesQuery.get, function(storyModules)
			setStoryModules((storyModules :: any) :: { ModuleScript })
		end)

		disposeStoryModuleObserver = Charm.observe(storyModulesQuery.get, function(storyModule)
			assert(storyModule:IsA("ModuleScript"), "Luau")

			local changedConn = storyModule.Changed:Connect(debounce(function()
				setStoryModules(function(prev)
					return table.clone(prev)
				end)
			end))

			return function()
				changedConn:Disconnect()
			end
		end)

		disposeStorybookModulesSubscription = Charm.listen(storybookModulesQuery.get, function(storybookModules)
			setStorybookModules((storybookModules :: any) :: { ModuleScript })
		end)

		disposeStorybookModuleObserver = Charm.observe(storybookModulesQuery.get, function(storybookModule)
			assert(storybookModule:IsA("ModuleScript"), "Luau")

			loadStorybook(storybookModule)

			local changedConn = storybookModule.Changed:Connect(debounce(function()
				reloadStorybook(storybookModule)
			end))

			return function()
				unloadStorybook(storybookModule)
				changedConn:Disconnect()
			end
		end)

		storyModulesQuery.start()
		storybookModulesQuery.start()

		table.insert(connections, root.Destroying:Connect(stop))
		table.insert(connections, script.Destroying:Connect(stop))

		Charm.batch(function()
			for _, storybookModule in storybookModulesQuery.get() do
				assert(storybookModule:IsA("ModuleScript"), "Luau")

				loadStorybook(storybookModule)
			end
		end)
	end
	self.start = start

	local function destroy()
		if isDestroyed then
			return
		end

		stop()
		clearStoryModuleRequests()
		isDestroyed = true
		storyModulesQuery.destroy()
		storybookModulesQuery.destroy()
	end
	self.destroy = destroy

	return self
end

return {
	new = StorytellerStore.new,
	instance = StorytellerStore.new(game),
}
