local StorytellerStore = require("@root/stores/StorytellerStore")
local types = require("@root/types")

type UnavailableStorybook = types.UnavailableStorybook

--[=[
	Returns the Storybooks Storyteller's shared runtime could not load.

	This is a Charm getter for the shared runtime only; it does not read React context or start discovery. Mount a `StorytellerProvider` without a custom `store`, or use a Storyteller hook outside a provider, to start shared discovery.

	A provider with a custom `store` and its descendant hooks use that store instead. They do not start the shared runtime or supply results to this getter.

	@tag Storybook
	@within Storyteller
]=]
local function getUnavailableStorybooks(): { UnavailableStorybook }
	return StorytellerStore.get().getUnavailableStorybooks()
end

return getUnavailableStorybooks
