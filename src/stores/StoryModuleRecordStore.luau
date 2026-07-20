local Charm = require("@pkg/Charm")
local ModuleLoader = require("@pkg/ModuleLoader")

local StoryModuleRequestPriority = require("@root/stores/enums/StoryModuleRequestPriority")
local excludeFromCharmFreeze = require("@root/stores/excludeFromCharmFreeze")
local loadStoryModule = require("@root/loadStoryModule")
local types = require("@root/types")

type LoadedStorybook = types.LoadedStorybook
type LoadedStory<T> = types.LoadedStory<T>
type StoryModuleRequestPriority = StoryModuleRequestPriority.StoryModuleRequestPriority

export type StoryModuleTarget = {
	storyModule: ModuleScript,
	storybook: LoadedStorybook,
}

export type StoryModuleRecord = {
	story: LoadedStory<unknown>?,
	problem: string?,
}

type StoryModuleRecords = {
	[ModuleScript]: StoryModuleRecord,
}

export type StoryModuleRecordStore = {
	getRecords: (ModuleScript) -> StoryModuleRecord?,
	request: (StoryModuleRequestPriority, StoryModuleTarget) -> () -> (),
	clear: () -> (),
	destroy: () -> (),
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

local StoryModuleRecordStore = {}

function StoryModuleRecordStore.new(): StoryModuleRecordStore
	local isDestroyed = false

	local getRecordMap, setRecords = Charm.signal({} :: StoryModuleRecords)

	local targetEntries: { [ModuleScript]: TargetEntry } = {}
	local loaderEntries: { [ModuleScript]: LoaderEntry } = {}
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
	local queueTarget: (TargetEntry, StoryModuleRequestPriority, boolean) -> ()
	local invalidateTarget: (TargetEntry, StoryModuleRequestPriority) -> ()
	local cleanupTargetEntry: (TargetEntry) -> ()

	local function getRecords(storyModule: ModuleScript): StoryModuleRecord?
		return getRecordMap()[storyModule]
	end

	local function getTargetEntry(storyModule: ModuleScript): TargetEntry?
		return targetEntries[storyModule]
	end

	local function setTargetEntry(entry: TargetEntry)
		local storyModule = entry.target.storyModule
		targetEntries[storyModule] = entry
	end

	local function removeTargetEntry(entry: TargetEntry)
		local storyModule = entry.target.storyModule
		if targetEntries[storyModule] == entry then
			targetEntries[storyModule] = nil
		end
	end

	local function removeRecord(storyModule: ModuleScript)
		setRecords(function(previous)
			if not previous[storyModule] then
				return previous
			end

			local nextRecords = table.clone(previous)
			nextRecords[storyModule] = nil
			return nextRecords
		end)
	end

	local function publishRecords(publications: { [TargetEntry]: PendingPublication })
		if next(publications) == nil then
			return
		end

		setRecords(function(previous)
			local nextRecords = table.clone(previous)

			for entry, publication in publications do
				local target = entry.target
				if
					entry.refCount > 0
					and entry.generation == publication.generation
					and getTargetEntry(target.storyModule) == entry
				then
					nextRecords[target.storyModule] = publication.record
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
				if changedTarget then
					if not changedTarget.reloadLoader then
						invalidateTarget(
							changedTarget,
							if changedTarget.interactiveRefCount > 0
								then StoryModuleRequestPriority.Interactive
								else StoryModuleRequestPriority.Background
						)
					end
					-- Story source changes have a dedicated connection. Only shared
					-- dependency changes should invalidate sibling stories.
					return
				end

				for _, entry in loaderEntry.targets do
					if not entry.reloadLoader then
						invalidateTarget(
							entry,
							if entry.interactiveRefCount > 0
								then StoryModuleRequestPriority.Interactive
								else StoryModuleRequestPriority.Background
						)
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
			loaderEntry.loader:clear()
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
		if entry.reloadLoader then
			entry.reloadLoader:clear()
		end
		entry.reloadLoader = nil

		local loaderEntry = loaderEntries[entry.loaderSource]
		if loaderEntry and loaderEntry.targets[entry.target.storyModule] == entry then
			loaderEntry.targets[entry.target.storyModule] = nil
		end

		removeTargetEntry(entry)
		removeRecord(entry.target.storyModule)
		cleanupLoaderEntry(entry.loaderSource)
	end

	local function createRecord(entry: TargetEntry): StoryModuleRecord
		local target = entry.target
		local loaderEntry = loaderEntries[entry.loaderSource]
		assert(loaderEntry, "Story module loader was cleaned up while a target was loading")
		local loader = entry.reloadLoader or loaderEntry.loader

		local story: LoadedStory<unknown>?
		local success, result = pcall(function()
			story = loadStoryModule(target.storyModule, target.storybook, loader)
		end)

		if success and story then
			excludeFromCharmFreeze(story)
		end

		return if success
			then {
				story = story,
			}
			else {
				problem = tostring(result),
			}
	end

	processPendingTargets = function()
		if isProcessingTargets or isDestroyed then
			return
		end
		isProcessingTargets = true

		task.defer(function()
			local publications: { [TargetEntry]: PendingPublication } = {}
			local workStarted = os.clock()

			while not isDestroyed do
				local entry = popQueue(interactiveQueue, StoryModuleRequestPriority.Interactive)
					or popQueue(backgroundQueue, StoryModuleRequestPriority.Background)
				if not entry then
					break
				end

				entry.queuedPriority = nil
				entry.isLoading = true
				local generation = entry.generation
				local record = createRecord(entry)
				entry.isLoading = false
				publications[entry] = {
					generation = generation,
					record = record,
				}

				if (os.clock() - workStarted) * 1000 >= WORK_BUDGET_MS then
					publishRecords(publications)
					publications = {}
					task.wait()
					workStarted = os.clock()
				end
			end

			publishRecords(publications)
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

		if entry.queuedPriority == StoryModuleRequestPriority.Interactive or entry.queuedPriority == priority then
			return
		end

		entry.queuedPriority = priority
		if priority == StoryModuleRequestPriority.Interactive then
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
		if entry.reloadLoader then
			entry.reloadLoader:clear()
		end

		local loader = ModuleLoader.new()
		entry.reloadLoader = loader
		entry.reloadConnection = loader.loadedModuleChanged:Connect(function()
			invalidateTarget(
				entry,
				if entry.interactiveRefCount > 0
					then StoryModuleRequestPriority.Interactive
					else StoryModuleRequestPriority.Background
			)
		end)
		queueTarget(entry, priority, true)
	end

	local function request(priority: StoryModuleRequestPriority, target: StoryModuleTarget): () -> ()
		if isDestroyed then
			return function() end
		end

		local storyModule = target.storyModule
		local storybookSource = target.storybook.source
		local existingEntry = getTargetEntry(storyModule)
		if existingEntry and existingEntry.loaderSource ~= storybookSource then
			cleanupTargetEntry(existingEntry)
			existingEntry = nil
		end

		local entry: TargetEntry
		local hasTargetChanged = false
		if existingEntry then
			entry = existingEntry
			if entry.target.storybook ~= target.storybook then
				entry.target = target
				hasTargetChanged = true
			end
		else
			entry = {
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
			setTargetEntry(entry)

			local loaderEntry = ensureLoaderEntry(storybookSource)
			loaderEntry.targets[storyModule] = entry
			entry.sourceConnection = storyModule:GetPropertyChangedSignal("Source"):Connect(function()
				invalidateTarget(
					entry,
					if entry.interactiveRefCount > 0
						then StoryModuleRequestPriority.Interactive
						else StoryModuleRequestPriority.Background
				)
			end)
			entry.destroyingConnection = storyModule.Destroying:Connect(function()
				cleanupTargetEntry(entry)
			end)
		end

		entry.refCount += 1
		if priority == StoryModuleRequestPriority.Interactive then
			entry.interactiveRefCount += 1
		end

		local record = getRecords(storyModule)
		if hasTargetChanged then
			invalidateTarget(entry, priority)
		elseif not record and not entry.isLoading then
			queueTarget(entry, priority, false)
		elseif
			entry.queuedPriority == StoryModuleRequestPriority.Background
			and priority == StoryModuleRequestPriority.Interactive
		then
			queueTarget(entry, StoryModuleRequestPriority.Interactive, false)
		end

		local isReleased = false
		return function()
			if isReleased then
				return
			end
			isReleased = true

			if entry.refCount == 0 then
				return
			end
			if priority == StoryModuleRequestPriority.Interactive then
				entry.interactiveRefCount -= 1
			end
			entry.refCount -= 1
			if entry.refCount == 0 then
				cleanupTargetEntry(entry)
			end
		end
	end

	local function clear()
		for _, entry in targetEntries do
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
			if entry.reloadLoader then
				entry.reloadLoader:clear()
			end
			entry.reloadLoader = nil
		end
		table.clear(targetEntries)

		for _, loaderEntry in loaderEntries do
			loaderEntry.connection:Disconnect()
			loaderEntry.destroyingConnection:Disconnect()
			loaderEntry.loader:clear()
			table.clear(loaderEntry.targets)
		end
		table.clear(loaderEntries)

		resetQueue(backgroundQueue)
		resetQueue(interactiveQueue)
		setRecords({})
	end

	local function destroy()
		if isDestroyed then
			return
		end
		clear()
		isDestroyed = true
	end

	return {
		getRecords = getRecords,
		request = request,
		clear = clear,
		destroy = destroy,
	}
end

return StoryModuleRecordStore
