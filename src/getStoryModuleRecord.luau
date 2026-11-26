local StorytellerStore = require("@root/stores/StorytellerStore")
local types = require("@root/types")

type StoryModuleRecord = types.StoryModuleRecord
type StoryRequest = types.StoryRequest

--[=[
	Returns the record of a Story module in the shared runtime, or `nil` when there isn't one yet.

	The runtime makes a record after it loads a module that something requested, and drops it when the last request is
	released. Call `requestStoryModule` first, or use a hook that requests the module, such as `useStory`. While a
	module reloads after an edit, this returns the previous record.

	The record's `status` says whether the module loaded. A `Loaded` record has `name` and `stories`, and an `Unavailable`
	record has `problem`. When an edit to a module that already loaded makes it fail to load, the record stays `Loaded` with
	the last working stories and also sets `problem` to the error.

	```lua
	local record = Storyteller.getStoryModuleRecord(request)

	if record and record.status == "Loaded" then
		print(record.name, #record.stories)
		if record.problem then
			warn("showing the last working version:", record.problem)
		end
	elseif record and record.status == "Unavailable" then
		warn(record.problem)
	end
	```

	This is a Charm getter for the shared runtime only; it does not read React context. A provider with a custom `store`
	and its descendant hooks use that store instead, and do not supply records to this getter.

	@tag Story
	@tag Module Loading
	@within Storyteller
]=]
local function getStoryModuleRecord(request: StoryRequest): StoryModuleRecord?
	return StorytellerStore.get().getStoryModuleRecord(request)
end

return getStoryModuleRecord
