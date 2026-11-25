local StoryModuleRequestPriority = require("@root/stores/enums/StoryModuleRequestPriority")
local StorytellerStore = require("@root/stores/StorytellerStore")
local types = require("@root/types")

type StoryRequest = types.StoryRequest

--[=[
	Asks the shared runtime to load a Story module, and returns a function that releases the request.

	Loading happens in the background. Read the result with `getStoryModuleRecord`, which keeps following edits to the module until the request is released. Requests for the same Storybook and module share one record, so this does not load a module again when a hook already has.

	```lua
	local request = {
		storyModule = storyModule,
		storybook = storybook,
		priority = "Interactive",
	}

	local release = Storyteller.requestStoryModule(request)
	-- Wait for `Storyteller.getStoryModuleRecord(request)` to return a record
	release()
	```

	This starts the shared runtime and keeps it running until the request is released. It does not read React context, so a provider with a custom `store` never sees the request.

	@tag Story
	@tag Module Loading
	@within Storyteller
]=]
local function requestStoryModule(request: StoryRequest): () -> ()
	local store = StorytellerStore.get()
	-- When the last consumer releases the runtime, it stops and clears every
	-- record. Holding it here keeps this request's record through a host's
	-- unmount.
	local releaseStore = store.acquire()
	local releaseRequest = store.requestStoryModule(request.priority or StoryModuleRequestPriority.Background, request)

	return function()
		releaseRequest()
		releaseStore()
	end
end

return requestStoryModule
