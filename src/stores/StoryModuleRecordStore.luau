local Charm = require("@pkg/Charm")
local ModuleLoader = require("@pkg/ModuleLoader")

local StoryModuleRequestPriority = require("@root/stores/enums/StoryModuleRequestPriority")
local excludeFromCharmFreeze = require("@root/stores/excludeFromCharmFreeze")
local loadStoryModuleData = require("@root/loadStoryModuleData")
local types = require("@root/types")

type RequestPriority = StoryModuleRequestPriority.StoryModuleRequestPriority

export type StoryRequest = types.StoryRequest
export type StoryModuleRecord = types.StoryModuleRecord
export type StoryModuleRecords = types.StoryModuleRecords

export type CleanupFn = () -> ()

export type StoryModuleRecordStore = {
	getRecords: () -> StoryModuleRecords,
	request: (priority: RequestPriority, storyRequest: StoryRequest) -> CleanupFn,
	clear: () -> (),
	destroy: () -> (),
}

-- One entry exists per requested (Storybook source, Story module) pair.
type RequestEntry = {
	request: StoryRequest,
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
	requests: { [ModuleScript]: RequestEntry },
}

type RequestQueue = {
	items: { [number]: RequestEntry },
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

	local initialRecords: StoryModuleRecords = {}
	local getRecords, setRecords = Charm.signal(initialRecords)

	local loaderEntries: { [ModuleScript]: LoaderEntry } = {}
	local backgroundQueue: RequestQueue = {
		items = {},
		head = 1,
		tail = 0,
	}
	local interactiveQueue: RequestQueue = {
		items = {},
		head = 1,
		tail = 0,
	}
	local isProcessingRequests = false

	local processPendingRequests: () -> ()
	local queueRequest: (RequestEntry, RequestPriority, boolean) -> ()
	local invalidateRequest: (RequestEntry, RequestPriority) -> ()
	local cleanupRequestEntry: (RequestEntry) -> ()

	local function getRequestEntry(storyModule: ModuleScript, storybookSource: ModuleScript): RequestEntry?
		local loaderEntry = loaderEntries[storybookSource]
		return if loaderEntry then loaderEntry.requests[storyModule] else nil
	end

	local function removeRecord(storyModule: ModuleScript, storybookSource: ModuleScript)
		setRecords(function(previous)
			local previousForStorybook = previous[storybookSource]
			if not previousForStorybook or not previousForStorybook[storyModule] then
				return previous
			end

			local nextRecords = table.clone(previous)
			local nextForStorybook = table.clone(previousForStorybook)
			nextForStorybook[storyModule] = nil
			if next(nextForStorybook) == nil then
				nextRecords[storybookSource] = nil
			else
				nextRecords[storybookSource] = nextForStorybook
			end
			return nextRecords
		end)
	end

	local function publishRecords(publications: { [RequestEntry]: PendingPublication })
		if next(publications) == nil then
			return
		end

		setRecords(function(previous)
			local nextRecords = table.clone(previous)
			local clonedStorybooks: { [ModuleScript]: boolean } = {}

			for entry, publication in publications do
				local storyRequest = entry.request
				local storybookSource = storyRequest.storybook.source
				if
					entry.refCount > 0
					and entry.generation == publication.generation
					and getRequestEntry(storyRequest.storyModule, storybookSource) == entry
				then
					local recordsForStorybook = nextRecords[storybookSource]
					if not clonedStorybooks[storybookSource] then
						recordsForStorybook = if recordsForStorybook then table.clone(recordsForStorybook) else {}
						nextRecords[storybookSource] = recordsForStorybook
						clonedStorybooks[storybookSource] = true
					end
					recordsForStorybook[storyRequest.storyModule] = publication.record
				end
			end

			return nextRecords
		end)
	end

	local function resetQueue(requestQueue: RequestQueue)
		table.clear(requestQueue.items)
		requestQueue.head = 1
		requestQueue.tail = 0
	end

	local function pushQueue(requestQueue: RequestQueue, entry: RequestEntry)
		requestQueue.tail += 1
		requestQueue.items[requestQueue.tail] = entry
	end

	local function popQueue(requestQueue: RequestQueue, priority: RequestPriority): RequestEntry?
		while requestQueue.head <= requestQueue.tail do
			local index = requestQueue.head
			local entry = requestQueue.items[index]
			requestQueue.items[index] = nil
			requestQueue.head += 1

			if entry and entry.refCount > 0 and entry.queuedPriority == priority then
				if requestQueue.head > requestQueue.tail then
					resetQueue(requestQueue)
				end
				return entry
			end
		end

		resetQueue(requestQueue)
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
				local changedEntry = loaderEntry.requests[changedModule]
				if changedEntry then
					if not changedEntry.reloadLoader then
						invalidateRequest(
							changedEntry,
							if changedEntry.interactiveRefCount > 0
								then StoryModuleRequestPriority.Interactive
								else StoryModuleRequestPriority.Background
						)
					end
					-- Story source changes have a dedicated connection. Only shared
					-- dependency changes should invalidate sibling stories.
					return
				end

				for _, entry in loaderEntry.requests do
					if not entry.reloadLoader then
						invalidateRequest(
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
				for _, entry in loaderEntry.requests do
					table.insert(entries, entry)
				end
				for _, entry in entries do
					cleanupRequestEntry(entry)
				end
			end),
			requests = {},
		}
		loaderEntries[storybookSource] = loaderEntry
		return loaderEntry
	end

	local function cleanupLoaderEntry(storybookSource: ModuleScript)
		local loaderEntry = loaderEntries[storybookSource]
		if loaderEntry and next(loaderEntry.requests) == nil then
			loaderEntry.connection:Disconnect()
			loaderEntry.destroyingConnection:Disconnect()
			loaderEntry.loader:clear()
			table.clear(loaderEntry.requests)
			loaderEntries[storybookSource] = nil
		end
	end

	cleanupRequestEntry = function(entry: RequestEntry)
		local storyRequest = entry.request
		local storybookSource = storyRequest.storybook.source
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

		local loaderEntry = loaderEntries[storybookSource]
		if loaderEntry and loaderEntry.requests[storyRequest.storyModule] == entry then
			loaderEntry.requests[storyRequest.storyModule] = nil
		end

		removeRecord(storyRequest.storyModule, storybookSource)
		cleanupLoaderEntry(storybookSource)
	end

	local function createRecord(entry: RequestEntry): StoryModuleRecord
		local storyRequest = entry.request
		local loaderEntry = loaderEntries[storyRequest.storybook.source]
		assert(loaderEntry, "Story module loader was cleaned up while a story module was loading")
		local loader = entry.reloadLoader or loaderEntry.loader

		local success, result = pcall(function()
			return loadStoryModuleData(storyRequest.storyModule, storyRequest.storybook, loader)
		end)

		if not success then
			return {
				problem = tostring(result),
			}
		end

		local stories = result.stories
		excludeFromCharmFreeze(stories)
		return {
			name = result.name,
			stories = stories,
		}
	end

	processPendingRequests = function()
		if isProcessingRequests or isDestroyed then
			return
		end
		isProcessingRequests = true

		task.defer(function()
			local publications: { [RequestEntry]: PendingPublication } = {}
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
			isProcessingRequests = false
			if
				not isDestroyed
				and (interactiveQueue.head <= interactiveQueue.tail or backgroundQueue.head <= backgroundQueue.tail)
			then
				processPendingRequests()
			end
		end)
	end

	queueRequest = function(entry: RequestEntry, priority: RequestPriority, invalidate: boolean)
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
		processPendingRequests()
	end

	invalidateRequest = function(entry: RequestEntry, priority: RequestPriority)
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
			invalidateRequest(
				entry,
				if entry.interactiveRefCount > 0
					then StoryModuleRequestPriority.Interactive
					else StoryModuleRequestPriority.Background
			)
		end)
		queueRequest(entry, priority, true)
	end

	local function request(priority: RequestPriority, storyRequest: StoryRequest): CleanupFn
		if isDestroyed then
			return function() end
		end

		local storyModule = storyRequest.storyModule
		local storybookSource = storyRequest.storybook.source

		local existingEntry = getRequestEntry(storyModule, storybookSource)
		local entry: RequestEntry
		local hasStorybookChanged = false
		if existingEntry then
			entry = existingEntry
			if entry.request.storybook ~= storyRequest.storybook then
				entry.request = storyRequest
				hasStorybookChanged = true
			end
		else
			entry = {
				request = storyRequest,
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
			local loaderEntry = ensureLoaderEntry(storybookSource)
			loaderEntry.requests[storyModule] = entry
			entry.sourceConnection = storyModule:GetPropertyChangedSignal("Source"):Connect(function()
				invalidateRequest(
					entry,
					if entry.interactiveRefCount > 0
						then StoryModuleRequestPriority.Interactive
						else StoryModuleRequestPriority.Background
				)
			end)
			entry.destroyingConnection = storyModule.Destroying:Connect(function()
				cleanupRequestEntry(entry)
			end)
		end

		entry.refCount += 1
		if priority == StoryModuleRequestPriority.Interactive then
			entry.interactiveRefCount += 1
		end

		local recordsForStorybook = getRecords()[storybookSource]
		local record = if recordsForStorybook then recordsForStorybook[storyModule] else nil
		if hasStorybookChanged then
			invalidateRequest(entry, priority)
		elseif not record and not entry.isLoading then
			queueRequest(entry, priority, false)
		elseif
			entry.queuedPriority == StoryModuleRequestPriority.Background
			and priority == StoryModuleRequestPriority.Interactive
		then
			queueRequest(entry, StoryModuleRequestPriority.Interactive, false)
		end

		local isReleased = false
		return function()
			if isReleased then
				return
			end
			isReleased = true

			if priority == StoryModuleRequestPriority.Interactive then
				entry.interactiveRefCount = math.max(0, entry.interactiveRefCount - 1)
			end
			entry.refCount = math.max(0, entry.refCount - 1)
			if entry.refCount == 0 then
				cleanupRequestEntry(entry)
			end
		end
	end

	local function clear()
		for _, loaderEntry in loaderEntries do
			for _, entry in loaderEntry.requests do
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
			loaderEntry.connection:Disconnect()
			loaderEntry.destroyingConnection:Disconnect()
			loaderEntry.loader:clear()
			table.clear(loaderEntry.requests)
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
