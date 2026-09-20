local StorytellerStore = require("@root/stores/StorytellerStore")
local types = require("@root/types")

type LoadedStorybook = types.LoadedStorybook

--[=[
	Returns the Storybooks loaded by Storyteller's shared runtime.

	This is a Charm getter, so consumers can subscribe to it without accessing the internal store. Mount a `StorytellerProvider` or Storyteller hook to start discovery.

	@tag Storybook
	@within Storyteller
]=]
local function getLoadedStorybooks(): { LoadedStorybook }
	return StorytellerStore.get().getLoadedStorybooks()
end

return getLoadedStorybooks
