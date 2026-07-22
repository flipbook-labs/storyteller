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

type ActiveRequest = {
	request: StoryRequest,
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
		if request.storyModule ~= nextRequest.storyModule or request.storybook ~= nextRequest.storybook then
			return false
		end
	end

	return true
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

	@tag React
	@tag Story
	@within Storyteller
]=]
local function useStoryModuleRecords(requests: { StoryRequest }): StoryModuleRecords
	local storytellerStore = useStorytellerStore()
	local records = useSignalState(storytellerStore.getStoryModuleRecords)
	local stableRequestsRef = useRef(requests)
	if not areSameRequests(stableRequestsRef.current, requests) then
		stableRequestsRef.current = requests
	end
	local stableRequests = stableRequestsRef.current

	local activeRequestsRef = useRef({} :: ActiveRequests)
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

		local currentRequests = {} :: { [ModuleScript]: { [ModuleScript]: boolean } }
		for _, request in stableRequests do
			local storyModule = request.storyModule
			local storybookSource = request.storybook.source
			local currentForModule = currentRequests[storyModule]
			if not currentForModule then
				currentForModule = {}
				currentRequests[storyModule] = currentForModule
			end
			currentForModule[storybookSource] = true

			local requestsForModule = activeRequests[storyModule]
			if not requestsForModule then
				requestsForModule = {}
				activeRequests[storyModule] = requestsForModule
			end

			local activeRequest = requestsForModule[storybookSource]
			if activeRequest and activeRequest.request.storybook == request.storybook then
				continue
			end
			if activeRequest then
				activeRequest.release()
			end

			requestsForModule[storybookSource] = {
				request = request,
				release = storytellerStore.requestStoryModule(StoryModuleRequestPriority.Background, request),
			}
		end

		for storyModule, requestsForModule in activeRequests do
			local currentForModule = currentRequests[storyModule]
			for storybookSource, activeRequest in requestsForModule do
				if not currentForModule or not currentForModule[storybookSource] then
					activeRequest.release()
					requestsForModule[storybookSource] = nil
				end
			end
			if next(requestsForModule) == nil then
				activeRequests[storyModule] = nil
			end
		end
	end, { storytellerStore, stableRequests } :: { unknown })

	return useMemo(function()
		local result = {} :: StoryModuleRecords
		for _, request in stableRequests do
			local recordsForModule = records[request.storyModule]
			local record = if recordsForModule then recordsForModule[request.storybook.source] else nil
			if record then
				local resultForModule = result[request.storyModule]
				if not resultForModule then
					resultForModule = {}
					result[request.storyModule] = resultForModule
				end
				resultForModule[request.storybook.source] = record
			end
		end
		return result
	end, { records, stableRequests } :: { unknown })
end

return useStoryModuleRecords
