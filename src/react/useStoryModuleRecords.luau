local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")

local StoryModuleRecordStore = require("@root/stores/StoryModuleRecordStore")
local StoryModuleRequestPriority = require("@root/stores/enums/StoryModuleRequestPriority")
local useStorytellerStore = require("@root/react/useStorytellerStore")

local useEffect = React.useEffect
local useMemo = React.useMemo
local useRef = React.useRef
local useSignalState = ReactCharm.useSignalState

type StoryModuleRecords = StoryModuleRecordStore.StoryModuleRecords
type StoryRequest = StoryModuleRecordStore.StoryRequest
type StoryModuleRequestPriority = StoryModuleRequestPriority.StoryModuleRequestPriority

type ActiveRequest = {
	request: StoryRequest,
	priority: StoryModuleRequestPriority,
	release: () -> (),
}

type ActiveRequests = {
	[ModuleScript]: {
		[ModuleScript]: ActiveRequest,
	},
}

local function areSameRequests(previous: { StoryRequest }, current: { StoryRequest }): boolean
	if #previous ~= #current then
		return false
	end

	for index, request in previous do
		local nextRequest = current[index]
		if
			request.storyModule ~= nextRequest.storyModule
			or request.storybook ~= nextRequest.storybook
			or request.priority ~= nextRequest.priority
		then
			return false
		end
	end

	return true
end

local function copyRequests(requests: { StoryRequest }): { StoryRequest }
	local copies: { StoryRequest } = {}
	for _, request in requests do
		table.insert(copies, table.clone(request))
	end
	return copies
end

local function pickRecords(records: StoryModuleRecords, requests: { StoryRequest }): StoryModuleRecords
	local result: StoryModuleRecords = {}
	for _, request in requests do
		local storybookSource = request.storybook.source
		local recordsForStorybook = records[storybookSource]
		local record = if recordsForStorybook then recordsForStorybook[request.storyModule] else nil
		if record then
			local resultForStorybook = result[storybookSource]
			if not resultForStorybook then
				resultForStorybook = {}
				result[storybookSource] = resultForStorybook
			end
			resultForStorybook[request.storyModule] = record
		end
	end
	return result
end

local function hasEveryRecord(records: StoryModuleRecords, other: StoryModuleRecords): boolean
	for storybookSource, otherForStorybook in other do
		local recordsForStorybook = records[storybookSource]
		if not recordsForStorybook then
			return false
		end
		for storyModule, record in otherForStorybook do
			if recordsForStorybook[storyModule] ~= record then
				return false
			end
		end
	end
	return true
end

local function areSameRecords(previous: StoryModuleRecords, current: StoryModuleRecords): boolean
	return hasEveryRecord(previous, current) and hasEveryRecord(current, previous)
end

-- A list can request the same module and Storybook source more than once. The
-- hook holds one request for them, at the highest priority asked for.
local function getPriorities(
	requests: { StoryRequest }
): { [ModuleScript]: { [ModuleScript]: StoryModuleRequestPriority } }
	local priorities: { [ModuleScript]: { [ModuleScript]: StoryModuleRequestPriority } } = {}
	for _, request in requests do
		local prioritiesForModule = priorities[request.storyModule]
		if not prioritiesForModule then
			prioritiesForModule = {}
			priorities[request.storyModule] = prioritiesForModule
		end
		if prioritiesForModule[request.storybook.source] ~= StoryModuleRequestPriority.Interactive then
			prioritiesForModule[request.storybook.source] = request.priority or StoryModuleRequestPriority.Background
		end
	end
	return priorities
end

local function releaseActiveRequests(activeRequests: ActiveRequests)
	for _, requestsByStorybookSource in activeRequests do
		for _, activeRequest in requestsByStorybookSource do
			activeRequest.release()
		end
	end
	table.clear(activeRequests)
end

--[=[
	Requests many Story modules at once and returns their records, such as for a
	sidebar that lists every Story. Records are grouped by Storybook source, then
	keyed by Story module. A module that hasn't loaded yet has no record, and one
	that failed to load has a record with its problem.

	Set `priority = "Interactive"` on the requests someone is waiting to see, and
	they go ahead of queued Background requests. Changing the priority of a loaded
	module's request doesn't reload it.

	The returned table stays the same until one of its records is added, replaced,
	or removed, so it's safe to use as a hook dependency.

	@tag React
	@tag Story
	@within Storyteller
]=]
local function useStoryModuleRecords(requests: { StoryRequest }): StoryModuleRecords
	local storytellerStore = useStorytellerStore()
	-- Comparing against a copy means a caller can edit its request list in place
	-- and still have the change picked up.
	local stableRequestsRef = useRef<<{ StoryRequest }?>>(nil)
	local previousRequests = stableRequestsRef.current
	local stableRequests: { StoryRequest } = if previousRequests and areSameRequests(previousRequests, requests)
		then previousRequests
		else copyRequests(requests)
	stableRequestsRef.current = stableRequests

	local recordsRef = useRef<<StoryModuleRecords>>({})
	local getRequestedRecords = useMemo(function()
		return Charm.computed(function(): StoryModuleRecords
			-- The store replaces its whole record map whenever any record
			-- publishes. Reusing the previous result keeps unrelated records from
			-- rerendering the consumer.
			local records = pickRecords(storytellerStore.getStoryModuleRecords(), stableRequests)
			if not areSameRecords(recordsRef.current, records) then
				recordsRef.current = records
			end
			return recordsRef.current
		end)
	end, { storytellerStore, stableRequests } :: { unknown })
	useSignalState(getRequestedRecords, { getRequestedRecords })

	local activeRequestsRef = useRef<<ActiveRequests>>({})
	local requestStoreRef = useRef(storytellerStore)
	useEffect(function()
		return function()
			releaseActiveRequests(activeRequestsRef.current)
		end
	end, {})

	useEffect(function()
		local activeRequests = activeRequestsRef.current
		if requestStoreRef.current ~= storytellerStore then
			releaseActiveRequests(activeRequests)
			requestStoreRef.current = storytellerStore
		end

		local priorities = getPriorities(stableRequests)
		for _, request in stableRequests do
			local storyModule = request.storyModule
			local storybookSource = request.storybook.source
			local priority: StoryModuleRequestPriority = priorities[storyModule][storybookSource]

			local requestsForModule = activeRequests[storyModule]
			if not requestsForModule then
				requestsForModule = {}
				activeRequests[storyModule] = requestsForModule
			end

			local activeRequest = requestsForModule[storybookSource]
			if
				activeRequest
				and activeRequest.request.storybook == request.storybook
				and activeRequest.priority == priority
			then
				continue
			end
			-- Acquire the replacement before releasing the request it replaces. When
			-- this is the only request for the module, releasing first would drop its
			-- record, and the module would load again even for a priority change.
			requestsForModule[storybookSource] = {
				request = request,
				priority = priority,
				release = storytellerStore.requestStoryModule(priority, request),
			}
			if activeRequest then
				activeRequest.release()
			end
		end

		for storyModule, requestsForModule in activeRequests do
			local prioritiesForModule = priorities[storyModule]
			for storybookSource, activeRequest in requestsForModule do
				if not prioritiesForModule or not prioritiesForModule[storybookSource] then
					activeRequest.release()
					requestsForModule[storybookSource] = nil
				end
			end
			if next(requestsForModule) == nil then
				activeRequests[storyModule] = nil
			end
		end
	end, { storytellerStore, stableRequests } :: { unknown })

	return getRequestedRecords()
end

return useStoryModuleRecords
