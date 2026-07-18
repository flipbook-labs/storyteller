local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")

local types = require("@root/types")
local useStorytellerStore = require("@root/react/useStorytellerStore")

local useEffect = React.useEffect
local useMemo = React.useMemo
local useRef = React.useRef
local useSignalState = ReactCharm.useSignalState

type StoryModuleSnapshots = types.StoryModuleSnapshots
type StoryModuleTarget = types.StoryModuleTarget

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

--[=[
	Requests and subscribes to the metadata needed to build Story browser nodes.
	Story module loading, caching, scheduling, and watching are owned by the
	active StorytellerStore.

	@tag React
	@tag Story
	@within Storyteller
]=]
local function useStoryModuleSnapshots(targets: { StoryModuleTarget }): StoryModuleSnapshots
	local storytellerStore = useStorytellerStore()
	local records = useSignalState(storytellerStore.getStoryModuleRecords)
	local stableTargetsRef = useRef(targets)
	if not areSameTargets(stableTargetsRef.current, targets) then
		stableTargetsRef.current = targets
	end
	local stableTargets = stableTargetsRef.current

	useEffect(function()
		return storytellerStore.requestStoryModules(stableTargets, "background")
	end, { storytellerStore, stableTargets } :: { unknown })

	return useMemo(function()
		local snapshots = {} :: StoryModuleSnapshots
		for _, target in stableTargets do
			local recordsForModule = records[target.storyModule]
			local record = if recordsForModule then recordsForModule[target.storybook.source] else nil
			if record then
				local snapshotsForModule = snapshots[target.storyModule]
				if not snapshotsForModule then
					snapshotsForModule = {}
					snapshots[target.storyModule] = snapshotsForModule
				end
				snapshotsForModule[target.storybook.source] = record.snapshot
			end
		end
		return snapshots
	end, { records, stableTargets } :: { unknown })
end

return useStoryModuleSnapshots
