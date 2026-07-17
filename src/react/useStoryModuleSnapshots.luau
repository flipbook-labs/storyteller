local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")

local types = require("@root/types")
local useStorytellerStore = require("@root/react/useStorytellerStore")

local useEffect = React.useEffect
local useMemo = React.useMemo
local useSignalState = ReactCharm.useSignalState

type StoryModuleSnapshot = types.StoryModuleSnapshot
type StoryModuleTarget = types.StoryModuleTarget

--[=[
	Requests and subscribes to the metadata needed to build Story browser nodes.
	Story module loading, caching, scheduling, and watching are owned by the
	active StorytellerStore.

	@tag React
	@tag Story
	@within Storyteller
]=]
local function useStoryModuleSnapshots(targets: { StoryModuleTarget }): { [ModuleScript]: StoryModuleSnapshot }
	local storytellerStore = useStorytellerStore()
	local records = useSignalState(storytellerStore.getStoryModuleRecords)

	useEffect(function()
		return storytellerStore.requestStoryModules(targets, "background")
	end, { storytellerStore, targets } :: { unknown })

	return useMemo(function()
		local snapshots = {} :: { [ModuleScript]: StoryModuleSnapshot }
		for _, target in targets do
			local recordsForModule = records[target.storyModule]
			local record = if recordsForModule then recordsForModule[target.storybook.source] else nil
			if record then
				snapshots[target.storyModule] = record.snapshot
			end
		end
		return snapshots
	end, { records, targets } :: { unknown })
end

return useStoryModuleSnapshots
