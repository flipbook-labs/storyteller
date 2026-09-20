local StorytellerStore = require("@root/stores/StorytellerStore")

--[=[
	Returns Story modules outside the roots of every loaded Storybook.

	This is a Charm getter, so consumers can subscribe to it without accessing the internal store. Mount a `StorytellerProvider` or Storyteller hook to start discovery.

	@tag Story
	@within Storyteller
]=]
local function getOrphanedStoryModules(): { ModuleScript }
	return StorytellerStore.get().getOrphanedStoryModules()
end

return getOrphanedStoryModules
