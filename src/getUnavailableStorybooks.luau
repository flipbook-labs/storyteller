local StorytellerStore = require("@root/stores/StorytellerStore")
local types = require("@root/types")

type UnavailableStorybook = types.UnavailableStorybook

--[=[
	Returns the Storybooks Storyteller's shared runtime could not load.

	This is a Charm getter, so consumers can subscribe to it without accessing the internal store. Mount a `StorytellerProvider` or Storyteller hook to start discovery.

	@tag Storybook
	@within Storyteller
]=]
local function getUnavailableStorybooks(): { UnavailableStorybook }
	return StorytellerStore.get().getUnavailableStorybooks()
end

return getUnavailableStorybooks
