local Charm = require("@pkg/Charm")
local ModuleLoader = require("@pkg/ModuleLoader")

local StoryModuleRequestPriority = require("@root/stores/enums/StoryModuleRequestPriority")
local constants = require("@root/constants")
local loadStoryModuleData = require("@root/loadStoryModuleData")
local types = require("@root/types")

type LoadedStorybook = types.LoadedStorybook
type LoadedStory<T> = types.LoadedStory<T>
type RequestPriority = StoryModuleRequestPriority.StoryModuleRequestPriority

export type StoryModuleTarget = types.StoryModuleTarget

export type StoryModuleRecord = {
	snapshot: types.StoryModuleSnapshot,
	stories: { LoadedStory<unknown> }?,
	problem: string?,
}

-- Records are keyed by (Story module, Storybook source) pair: the outer key is
-- the Story ModuleScript, the inner key is the ModuleScript of the Storybook it
-- was loaded through. The same Story module can be covered by multiple
-- Storybooks, and each pairing loads independently because the Storybook
-- supplies the loader environment (packages, mapStory, and friends).
export type StoryModuleRecords = {
	[ModuleScript]: {
		[ModuleScript]: StoryModuleRecord,
	},
}

export type StoryModuleRecordStore = {
	getRecords: () -> StoryModuleRecords,
	request: (targets: { StoryModuleTarget }, priority: RequestPriority?) -> () -> (),
	clear: () -> (),
	destroy: () -> (),
}

-- One entry exists per requested (Story module, Storybook source) pair.
-- Every field backs a distinct behavior; drop the behavior to drop the field.
type TargetEntry = {
	target: StoryModuleTarget,
	-- The Storybook source this entry loads through; also the key into
	-- loaderEntries for the shared ModuleLoader.
	loaderSource: ModuleScript,
	-- Overlapping requests share one entry. The record lives until the last
	-- request releases.
	refCount: number,
	-- How many of those requests are Interactive, so invalidation can requeue
	-- at the priority the strictest consumer asked for.
	interactiveRefCount: number,
	-- Bumped on every invalidation. A finished load only publishes when its
	-- generation still matches, which drops stale results from superseded loads.
	generation: number,
	-- True while a load for this entry is executing, so a second request
	-- arriving mid-load does not queue a duplicate.
	isLoading: boolean,
	-- Which queue the entry currently sits in, if any. Dedupes queueing and
	-- lets an Interactive request upgrade a queued Background entry.
	queuedPriority: RequestPriority?,
	-- Replaces the shared loader after this entry's module changes, so a
	-- reload evaluates fresh without clearing sibling entries' caches.
	reloadLoader: ModuleLoader.ModuleLoader?,
	-- Watches the reload loader for dependency changes after a reload.
	reloadConnection: RBXScriptConnection?,
	-- Watches the Story module's own Source for direct edits.
	sourceConnection: RBXScriptConnection?,
	-- Cleans the entry up when the Story module is destroyed.
	destroyingConnection: RBXScriptConnection?,
}

-- One shared ModuleLoader per Storybook source. Story modules loaded through
-- the same Storybook share dependency caches, and a change to a shared
-- dependency invalidates every dependent entry.
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

-- Charm deep-freezes signal values in Studio but skips tables that carry a
-- metatable. Loaded stories reference package modules (React and friends)
-- that mutate internal state while rendering, so their object graphs must
-- stay outside that recursive freeze. #132 moves this to the module-loading
-- boundary; this exclusion is the record store's interim guard.
local LOADED_STORY_METATABLE = {}

local function excludeFromCharmFreeze(value: { [unknown]: unknown })
	setmetatable(value, LOADED_STORY_METATABLE)
end

local StoryModuleRecordStore = {}

function StoryModuleRecordStore.new(): StoryModuleRecordStore
	local isDestroyed = false

	local initialRecords: StoryModuleRecords = {}
	local getRecords, setRecords = Charm.signal(initialRecords)

	local targetEntries: { [ModuleScript]: { [ModuleScript]: TargetEntry } } = {}
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
	local queueTarget: (TargetEntry, RequestPriority, boolean) -> ()
	local invalidateTarget: (TargetEntry, RequestPriority) -> ()
	local cleanupTargetEntry: (TargetEntry) -> ()

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

	local function removeRecord(storyModule: ModuleScript, storybookSource: ModuleScript)
		setRecords(function(previous)
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

	local function publishRecords(publications: { [TargetEntry]: PendingPublication })
		if next(publications) == nil then
			return
		end

		setRecords(function(previous)
			local nextRecords = table.clone(previous)
			local clonedModules: { [ModuleScript]: boolean } = {}

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

	local function popQueue(targetQueue: TargetQueue, priority: RequestPriority): TargetEntry?
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
		removeRecord(entry.target.storyModule, entry.loaderSource)
		cleanupLoaderEntry(entry.loaderSource)
	end

	local function createRecord(entry: TargetEntry): StoryModuleRecord
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

		local stories = result.stories
		excludeFromCharmFreeze(stories)
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

	queueTarget = function(entry: TargetEntry, priority: RequestPriority, invalidate: boolean)
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

	invalidateTarget = function(entry: TargetEntry, priority: RequestPriority)
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

	local function request(targets: { StoryModuleTarget }, priority: RequestPriority?): () -> ()
		if isDestroyed then
			return function() end
		end

		local requestPriority: RequestPriority = priority or StoryModuleRequestPriority.Background
		local acquiredEntries: { TargetEntry } = {}
		local acquiredByModule: { [ModuleScript]: { [ModuleScript]: boolean } } = {}

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
			if requestPriority == StoryModuleRequestPriority.Interactive then
				entry.interactiveRefCount += 1
			end
			table.insert(acquiredEntries, entry)

			local recordsForModule = getRecords()[storyModule]
			local record = if recordsForModule then recordsForModule[storybookSource] else nil
			if hasTargetChanged then
				invalidateTarget(entry, requestPriority)
			elseif not record and not entry.isLoading then
				queueTarget(entry, requestPriority, false)
			elseif
				entry.queuedPriority == StoryModuleRequestPriority.Background
				and requestPriority == StoryModuleRequestPriority.Interactive
			then
				queueTarget(entry, StoryModuleRequestPriority.Interactive, false)
			end
		end

		local isReleased = false
		return function()
			if isReleased then
				return
			end
			isReleased = true

			for _, entry in acquiredEntries do
				if requestPriority == StoryModuleRequestPriority.Interactive then
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

	local function clear()
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
				if entry.reloadLoader then
					entry.reloadLoader:clear()
				end
				entry.reloadLoader = nil
			end
			table.clear(entriesForModule)
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
