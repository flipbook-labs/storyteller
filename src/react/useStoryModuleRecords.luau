local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")

local StoryModuleRecordStore = require("@root/stores/StoryModuleRecordStore")
local StoryModuleRequestPriority = require("@root/stores/enums/StoryModuleRequestPriority")
local types = require("@root/types")
local useStorytellerStore = require("@root/react/useStorytellerStore")

local useEffect = React.useEffect
local useMemo = React.useMemo
local useRef = React.useRef
local useSignalState = ReactCharm.useSignalState

type StoryModuleRecords = StoryModuleRecordStore.StoryModuleRecords
type StoryModuleTarget = types.StoryModuleTarget

type ActiveRequest = {
	target: StoryModuleTarget,
	release: () -> (),
}

type ActiveRequests = {
	[ModuleScript]: {
		[ModuleScript]: ActiveRequest,
	},
}

local function areSameTargets(previous: { StoryModuleTarget }, current: { StoryModuleTarget }): boolean
	if #previous ~= #current then
		return false
	end

	for index, target in previous do
		local nextTarget = current[index]
		if target.storyModule ~= nextTarget.storyModule or target.storybook ~= nextTarget.storybook then
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
local function useStoryModuleRecords(targets: { StoryModuleTarget }): StoryModuleRecords
	local storytellerStore = useStorytellerStore()
	local records = useSignalState(storytellerStore.getStoryModuleRecords)
	local stableTargetsRef = useRef(targets)
	if not areSameTargets(stableTargetsRef.current, targets) then
		stableTargetsRef.current = targets
	end
	local stableTargets = stableTargetsRef.current

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

		local currentTargets = {} :: { [ModuleScript]: { [ModuleScript]: boolean } }
		for _, target in stableTargets do
			local storyModule = target.storyModule
			local storybookSource = target.storybook.source
			local currentForModule = currentTargets[storyModule]
			if not currentForModule then
				currentForModule = {}
				currentTargets[storyModule] = currentForModule
			end
			currentForModule[storybookSource] = true

			local requestsForModule = activeRequests[storyModule]
			if not requestsForModule then
				requestsForModule = {}
				activeRequests[storyModule] = requestsForModule
			end

			local activeRequest = requestsForModule[storybookSource]
			if activeRequest and activeRequest.target.storybook == target.storybook then
				continue
			end
			if activeRequest then
				activeRequest.release()
			end

			requestsForModule[storybookSource] = {
				target = target,
				release = storytellerStore.requestStoryModules({ target }, StoryModuleRequestPriority.Background),
			}
		end

		for storyModule, requestsForModule in activeRequests do
			local currentForModule = currentTargets[storyModule]
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
	end, { storytellerStore, stableTargets } :: { unknown })

	return useMemo(function()
		local result = {} :: StoryModuleRecords
		for _, target in stableTargets do
			local recordsForModule = records[target.storyModule]
			local record = if recordsForModule then recordsForModule[target.storybook.source] else nil
			if record then
				local resultForModule = result[target.storyModule]
				if not resultForModule then
					resultForModule = {}
					result[target.storyModule] = resultForModule
				end
				resultForModule[target.storybook.source] = record
			end
		end
		return result
	end, { records, stableTargets } :: { unknown })
end

return useStoryModuleRecords
