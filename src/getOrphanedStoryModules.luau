local StorytellerStore = require("@root/stores/StorytellerStore")

--[=[
	Returns Story modules in the shared runtime outside the roots of every loaded Storybook.

	This is a Charm getter for the shared runtime only; it does not read React context or start discovery. Mount a `StorytellerProvider` without a custom `store`, or use a Storyteller hook outside a provider, to start shared discovery.

	A provider with a custom `store` and its descendant hooks use that store instead. They do not start the shared runtime or supply results to this getter.

	@tag Story
	@within Storyteller
]=]
local function getOrphanedStoryModules(): { ModuleScript }
	return StorytellerStore.get().getOrphanedStoryModules()
end

return getOrphanedStoryModules
