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

-- The same pair of module and Storybook can be requested more than once, and
-- the hook holds one request for it at the highest priority asked for.
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
	Requests and subscribes to the loaded Story module records needed to build
	Story browser nodes. Consumers project the metadata they need (names,
	summaries, load problems) from each record's stories. Story module loading,
	caching, scheduling, and watching are owned by the active StorytellerStore.

	Set `priority = "Interactive"` on the requests someone is waiting to see. They
	load before every Background request, and a request's priority can change
	without loading its module again.

	The returned table only changes when one of the requested records does.

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
			-- Acquire the replacement before releasing the lease it replaces. Releasing
			-- first can drop the entry's last reference, and the new request would then
			-- create a fresh entry that skips the store's storybook-change invalidation.
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
