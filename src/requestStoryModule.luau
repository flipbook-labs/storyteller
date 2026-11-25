local StoryModuleRequestPriority = require("@root/stores/enums/StoryModuleRequestPriority")
local StorytellerStore = require("@root/stores/StorytellerStore")
local types = require("@root/types")

type StoryRequest = types.StoryRequest

--[=[
	Asks the shared runtime to load a Story module, and returns a function that releases the request.

	The module loads after this function returns. Call `getStoryModuleRecord` with the same request to read the result, or pass that call to `Charm.listen` to be told when it changes. While the request is held, the module reloads when it or its dependencies are edited.

	Requests for the same module and Storybook share one record, including requests from hooks that use the shared runtime. Passing a different `storybook` table for the same source counts as a new version of that Storybook, so the module reloads.

	The record is dropped when its last request is released. So to change a request's priority, make the new request before releasing the old one. If the old one was the last, releasing it first would leave no record until the module loads again.

	```lua
	local request = {
		storyModule = storyModule,
		storybook = storybook,
		priority = "Interactive",
	}

	local release = Storyteller.requestStoryModule(request)
	local stopListening = Charm.listen(function()
		return Storyteller.getStoryModuleRecord(request)
	end, function(record)
		print(if record then record.status else "Loading")
	end)

	-- When the record is no longer needed
	stopListening()
	release()
	```

	This starts the shared runtime and keeps it running until the request is released. It does not read React context, so a provider with a custom `store` never sees the request.

	@tag Story
	@tag Module Loading
	@within Storyteller
]=]
local function requestStoryModule(request: StoryRequest): () -> ()
	local store = StorytellerStore.get()
	-- The store stops and clears every record once nothing holds it. Holding it
	-- here keeps this request's record when a StorytellerProvider unmounts.
	local releaseStore = store.acquire()
	local releaseRequest = store.requestStoryModule(request.priority or StoryModuleRequestPriority.Background, request)

	return function()
		releaseRequest()
		releaseStore()
	end
end

return requestStoryModule
