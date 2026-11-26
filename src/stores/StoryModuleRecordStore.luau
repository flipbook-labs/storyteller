local Charm = require("@pkg/Charm")
local ModuleLoader = require("@pkg/ModuleLoader")

local StoryModuleRequestPriority = require("@root/stores/enums/StoryModuleRequestPriority")
local excludeFromCharmFreeze = require("@root/stores/excludeFromCharmFreeze")
local loadStoryModuleData = require("@root/loadStoryModuleData")
local types = require("@root/types")

type StoryModuleRequestPriority = StoryModuleRequestPriority.StoryModuleRequestPriority

export type StoryRequest = types.StoryRequest
export type StoryModuleRecord = types.StoryModuleRecord
export type StoryModuleRecords = types.StoryModuleRecords

export type CleanupFn = () -> ()

export type StoryModuleRecordStore = {
	getRecord: (request: StoryRequest) -> StoryModuleRecord?,
	getRecords: () -> StoryModuleRecords,
	request: (priority: StoryModuleRequestPriority, storyRequest: StoryRequest) -> CleanupFn,
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
	queuedPriority: StoryModuleRequestPriority?,
	-- Replaces the shared loader after this entry's module changes, so a
	-- reload evaluates fresh without clearing sibling entries' caches.
	reloadLoader: ModuleLoader.ModuleLoader?,
	-- Watches the reload loader for dependency changes after a reload.
	reloadConnection: RBXScriptConnection?,
	--[[
		Started by a change to a module open in Studio's script editor, either
		the Story module or one of its dependencies. When it runs out after
		RELOAD_QUIET_PERIOD_SECONDS, it invalidates the entry, which queues a
		reload. Each new change restarts it.
	]]
	reloadTimer: thread?,
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

-- Fixed for now; flipbook-labs/storyteller#151 tracks deriving this from the
-- frame's remaining budget.
local WORK_BUDGET_MS = 4

--[[
	Studio's script editor changes a module's Source on every keystroke, and
	each reload evaluates the Story and everything it requires. So when the
	changed module is open in the editor, the reload waits until changes stop
	for this long, which turns a burst of typing into one reload. It's longer
	than the gap between keystrokes at an ordinary typing pace of about 4 a
	second, and short enough that the Story still updates soon after typing
	stops.

	Changes to a module that isn't open, such as a file Rojo syncs on save,
	reload right away.
]]
local RELOAD_QUIET_PERIOD_SECONDS = 0.3

local ScriptEditorService: ScriptEditorService? = nil
pcall(function()
	ScriptEditorService = game:GetService("ScriptEditorService")
end)

-- Embedded Flipbook runs as a game script, which can't call
-- `FindScriptDocument`. Nobody types in the script editor during a playtest,
-- so a failed call counts as not open.
local function isOpenInScriptEditor(module: Instance): boolean
	if not ScriptEditorService then
		return false
	end
	local service = ScriptEditorService
	local ok, document = pcall(function()
		return service:FindScriptDocument(module :: LuaSourceContainer)
	end)
	return ok and typeof(document) == "Instance"
end

export type Options = {
	-- Replaces the check for whether a module is open in Studio's script
	-- editor. Specs run outside Studio, where nothing is ever open.
	isOpenInScriptEditor: ((module: Instance) -> boolean)?,
}

local StoryModuleRecordStore = {}

function StoryModuleRecordStore.new(options: Options?): StoryModuleRecordStore
	local isOpen: (module: Instance) -> boolean = if options and options.isOpenInScriptEditor
		then options.isOpenInScriptEditor
		else isOpenInScriptEditor
	local isDestroyed = false

	local getRecords, setRecords = Charm.signal<<StoryModuleRecords>>({})

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
	local scheduleReload: (entry: RequestEntry, changedModule: Instance) -> ()
	local cleanupRequestEntry: (entry: RequestEntry) -> ()

	local function getRecord(request: StoryRequest): StoryModuleRecord?
		local recordsForStorybook = getRecords()[request.storybook.source]
		return if recordsForStorybook then recordsForStorybook[request.storyModule] else nil
	end

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
						scheduleReload(changedEntry, changedModule)
					end
					-- Story source changes have a dedicated connection. Only shared
					-- dependency changes should invalidate sibling stories.
					return
				end

				for _, entry in loaderEntry.requests do
					if not entry.reloadLoader then
						scheduleReload(entry, changedModule)
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
		local storybookSource = entry.request.storybook.source
		entry.refCount = 0
		entry.interactiveRefCount = 0
		entry.generation += 1
		entry.queuedPriority = nil

		if entry.reloadTimer then
			task.cancel(entry.reloadTimer)
			entry.reloadTimer = nil
		end
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
		if loaderEntry and loaderEntry.requests[entry.request.storyModule] == entry then
			loaderEntry.requests[entry.request.storyModule] = nil
		end

		removeRecord(entry.request.storyModule, storybookSource)
		cleanupLoaderEntry(storybookSource)
	end

	local function createRecord(entry: RequestEntry): StoryModuleRecord
		local loaderEntry = loaderEntries[entry.request.storybook.source]
		assert(loaderEntry, "Story module loader was cleaned up while a story module was loading")
		local loader = entry.reloadLoader or loaderEntry.loader

		local success, result = pcall(function()
			return loadStoryModuleData(entry.request.storyModule, entry.request.storybook, loader)
		end)

		if not success then
			return {
				status = "Unavailable",
				problem = tostring(result),
			}
		end

		for _, story in result.stories do
			excludeFromCharmFreeze(story)
		end
		return {
			status = "Loaded",
			name = result.name,
			stories = result.stories,
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

	queueRequest = function(entry: RequestEntry, priority: StoryModuleRequestPriority, invalidate: boolean)
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

	invalidateRequest = function(entry: RequestEntry, priority: StoryModuleRequestPriority)
		if isDestroyed or entry.refCount == 0 then
			return
		end

		-- This reload picks up any edit a pending timer is waiting on, so the
		-- timer would only load the module a second time.
		if entry.reloadTimer then
			task.cancel(entry.reloadTimer)
			entry.reloadTimer = nil
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
		entry.reloadConnection = loader.loadedModuleChanged:Connect(function(changedModule)
			scheduleReload(entry, changedModule)
		end)
		queueRequest(entry, priority, true)
	end

	local function reloadPriority(entry: RequestEntry): StoryModuleRequestPriority
		return if entry.interactiveRefCount > 0
			then StoryModuleRequestPriority.Interactive
			else StoryModuleRequestPriority.Background
	end

	scheduleReload = function(entry: RequestEntry, changedModule: Instance)
		if not isOpen(changedModule) then
			invalidateRequest(entry, reloadPriority(entry))
			return
		end

		if entry.reloadTimer then
			task.cancel(entry.reloadTimer)
		end

		entry.reloadTimer = task.delay(RELOAD_QUIET_PERIOD_SECONDS, function()
			entry.reloadTimer = nil
			invalidateRequest(entry, reloadPriority(entry))
		end)
	end

	local function request(priority: StoryModuleRequestPriority, storyRequest: StoryRequest): CleanupFn
		if isDestroyed then
			return function() end
		end

		local existingEntry = getRequestEntry(storyRequest.storyModule, storyRequest.storybook.source)
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
				reloadTimer = nil,
				sourceConnection = nil,
				destroyingConnection = nil,
			}
			-- Lute's unused_variable lint doesn't count writing a property as a use.
			-- #180 tracks removing this ignore.
			-- lute-lint-ignore(unused_variable)
			local loaderEntry = ensureLoaderEntry(storyRequest.storybook.source)
			loaderEntry.requests[storyRequest.storyModule] = entry
			-- Source-specific signals require PluginOrOpenCloud in embedded clients.
			entry.sourceConnection = storyRequest.storyModule.Changed:Connect(function(property)
				if property == "Source" then
					scheduleReload(entry, storyRequest.storyModule)
				end
			end)
			entry.destroyingConnection = storyRequest.storyModule.Destroying:Connect(function()
				cleanupRequestEntry(entry)
			end)
		end

		entry.refCount += 1
		if priority == StoryModuleRequestPriority.Interactive then
			entry.interactiveRefCount += 1
		end

		local record = getRecord(storyRequest)
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
				if entry.reloadTimer then
					task.cancel(entry.reloadTimer)
					entry.reloadTimer = nil
				end
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
		getRecord = getRecord,
		getRecords = getRecords,
		request = request,
		clear = clear,
		destroy = destroy,
	}
end

return StoryModuleRecordStore
