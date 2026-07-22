local Charm = require("@pkg/Charm")
local ModuleLoader = require("@pkg/ModuleLoader")

local StoryModuleRequestPriority = require("@root/stores/enums/StoryModuleRequestPriority")
local excludeFromCharmFreeze = require("@root/stores/excludeFromCharmFreeze")
local loadStoryModule = require("@root/loadStoryModule")
local types = require("@root/types")

type LoadedStorybook = types.LoadedStorybook
type LoadedStory<T> = types.LoadedStory<T>
type StoryModuleRequestPriority = StoryModuleRequestPriority.StoryModuleRequestPriority

export type StoryRequest = {
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
	getRecord: (storyModule: ModuleScript) -> StoryModuleRecord?,
	request: (priority: StoryModuleRequestPriority, storyRequest: StoryRequest) -> () -> (),
	clear: () -> (),
	destroy: () -> (),
}

type RequestEntry = {
	request: StoryRequest,
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

-- Fixed for now; flipbook-labs/storyteller#151 tracks deriving this from the
-- frame's remaining budget.
local WORK_BUDGET_MS = 4

local StoryModuleRecordStore = {}

function StoryModuleRecordStore.new(): StoryModuleRecordStore
	local isDestroyed = false

	local getRecordMap, setRecords = Charm.signal({} :: StoryModuleRecords)

	local requestEntries: { [ModuleScript]: RequestEntry } = {}
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
	local queueRequest: (entry: RequestEntry, priority: StoryModuleRequestPriority, invalidate: boolean) -> ()
	local invalidateRequest: (entry: RequestEntry, priority: StoryModuleRequestPriority) -> ()
	local cleanupRequestEntry: (entry: RequestEntry) -> ()

	local function getRecord(storyModule: ModuleScript): StoryModuleRecord?
		return getRecordMap()[storyModule]
	end

	local function getRequestEntry(storyModule: ModuleScript): RequestEntry?
		return requestEntries[storyModule]
	end

	local function setRequestEntry(entry: RequestEntry)
		local storyModule = entry.request.storyModule
		requestEntries[storyModule] = entry
	end

	local function removeRequestEntry(entry: RequestEntry)
		local storyModule = entry.request.storyModule
		if requestEntries[storyModule] == entry then
			requestEntries[storyModule] = nil
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

	local function publishRecords(publications: { [RequestEntry]: PendingPublication })
		if next(publications) == nil then
			return
		end

		setRecords(function(previous)
			local nextRecords = table.clone(previous)

			for entry, publication in publications do
				local request = entry.request
				if
					entry.refCount > 0
					and entry.generation == publication.generation
					and getRequestEntry(request.storyModule) == entry
				then
					nextRecords[request.storyModule] = publication.record
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

	local function popQueue(requestQueue: RequestQueue, priority: StoryModuleRequestPriority): RequestEntry?
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

	function cleanupRequestEntry(entry: RequestEntry)
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
		if loaderEntry and loaderEntry.requests[entry.request.storyModule] == entry then
			loaderEntry.requests[entry.request.storyModule] = nil
		end

		removeRequestEntry(entry)
		removeRecord(entry.request.storyModule)
		cleanupLoaderEntry(entry.loaderSource)
	end

	local function createRecord(entry: RequestEntry): StoryModuleRecord
		local loaderEntry = loaderEntries[entry.loaderSource]
		assert(loaderEntry, "Story module loader was cleaned up while a story module was loading")
		local loader = entry.reloadLoader or loaderEntry.loader

		local story: LoadedStory<unknown>?
		local success, result = pcall(function()
			story = loadStoryModule(entry.request.storyModule, entry.request.storybook, loader)
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

	function processPendingRequests()
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
		end)
	end

	function queueRequest(entry: RequestEntry, priority: StoryModuleRequestPriority, invalidate: boolean)
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

	function invalidateRequest(entry: RequestEntry, priority: StoryModuleRequestPriority)
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

	local function request(priority: StoryModuleRequestPriority, storyRequest: StoryRequest): () -> ()
		if isDestroyed then
			return function() end
		end

		local storyModule = storyRequest.storyModule
		local storybookSource = storyRequest.storybook.source
		local existingEntry = getRequestEntry(storyModule)
		if existingEntry and existingEntry.loaderSource ~= storybookSource then
			cleanupRequestEntry(existingEntry)
			existingEntry = nil
		end

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
			setRequestEntry(entry)

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

		local record = getRecord(storyModule)
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

			if entry.refCount == 0 then
				return
			end
			if priority == StoryModuleRequestPriority.Interactive then
				entry.interactiveRefCount -= 1
			end
			entry.refCount -= 1
			if entry.refCount == 0 then
				cleanupRequestEntry(entry)
			end
		end
	end

	local function clear()
		for _, entry in requestEntries do
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
		table.clear(requestEntries)

		for _, loaderEntry in loaderEntries do
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
		getRecord = getRecord,
		request = request,
		clear = clear,
		destroy = destroy,
	}
end

return StoryModuleRecordStore
