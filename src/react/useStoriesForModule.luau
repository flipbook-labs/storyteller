local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")

local types = require("@root/types")
local StoryModuleRequestPriority = require("@root/stores/enums/StoryModuleRequestPriority")
local useStorytellerStore = require("@root/react/useStorytellerStore")

local useEffect = React.useEffect
local useSignalState = ReactCharm.useSignalState

local function useStoriesForModule(
	module: ModuleScript,
	storybook: types.LoadedStorybook
): ({ types.LoadedStory<unknown> }?, string?)
	local storytellerStore = useStorytellerStore()
	local records = useSignalState(storytellerStore.getStoryModuleRecords)

	useEffect(function()
		return storytellerStore.requestStoryModules({
			{
				storyModule = module,
				storybook = storybook,
			},
		}, StoryModuleRequestPriority.Interactive)
	end, { module, storytellerStore, storybook } :: { unknown })

	local recordsForModule = records[module]
	local record = if recordsForModule then recordsForModule[storybook.source] else nil
	return if record then record.stories else nil, if record then record.problem else nil
end

return useStoriesForModule
