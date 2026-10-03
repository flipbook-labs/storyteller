local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")

local StoryModuleRequestPriority = require("@root/stores/enums/StoryModuleRequestPriority")
local types = require("@root/types")
local useStorytellerStore = require("@root/react/useStorytellerStore")

local useEffect = React.useEffect
local useSignalState = ReactCharm.useSignalState

local function useStories(
	module: ModuleScript,
	storybook: types.LoadedStorybook
): ({ types.LoadedStory<unknown> }?, string?)
	local storytellerStore = useStorytellerStore()
	local record = useSignalState(function()
		return storytellerStore.getStoryModuleRecord({
			storyModule = module,
			storybook = storybook,
		})
	end, { storytellerStore, module, storybook.source } :: { unknown })

	useEffect(function()
		return storytellerStore.requestStoryModule(StoryModuleRequestPriority.Interactive, {
			storyModule = module,
			storybook = storybook,
		})
	end, { module, storytellerStore, storybook } :: { unknown })

	return if record then record.stories else nil, if record then record.problem else nil
end

return useStories
