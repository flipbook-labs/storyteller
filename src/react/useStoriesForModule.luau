local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")

local types = require("@root/types")
local useStorytellerStore = require("@root/react/useStorytellerStore")

local useEffect = React.useEffect
local useSignalState = ReactCharm.useSignalState

local function useStoriesForModule(
	module: ModuleScript,
	storybook: types.LoadedStorybook
): (types.LoadedStory<unknown>?, string?)
	local storytellerStore = useStorytellerStore()
	local records = useSignalState(storytellerStore.getStoryModuleRecords)

	useEffect(function()
		return storytellerStore.requestStoryModules({
			{
				storyModule = module,
				storybook = storybook,
			},
		}, "interactive")
	end, { module, storytellerStore, storybook } :: { unknown })

	local recordsForModule = records[module]
	local record = if recordsForModule then recordsForModule[storybook.source] else nil
	return if record then record.story else nil, if record then record.problem else nil
end

return useStoriesForModule
