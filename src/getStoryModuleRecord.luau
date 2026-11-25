local StorytellerStore = require("@root/stores/StorytellerStore")
local types = require("@root/types")

type StoryModuleRecord = types.StoryModuleRecord
type StoryRequest = types.StoryRequest

--[=[
	Returns the record of a Story module in the shared runtime, or `nil` while the module has not finished loading.

	A record only exists while something is requesting the module. Call `requestStoryModule` first, or use a hook that requests it, such as `useStory`. The record's `status` says whether the module loaded, and it decides which fields the record has.

	```lua
	local record = Storyteller.getStoryModuleRecord(request)

	if record and record.status == "Loaded" then
		print(record.name, #record.stories)
	elseif record and record.status == "Unavailable" then
		warn(record.problem)
	end
	```

	This is a Charm getter for the shared runtime only; it does not read React context. A provider with a custom `store` and its descendant hooks use that store instead, and do not supply records to this getter.

	@tag Story
	@tag Module Loading
	@within Storyteller
]=]
local function getStoryModuleRecord(request: StoryRequest): StoryModuleRecord?
	return StorytellerStore.get().getStoryModuleRecord(request)
end

return getStoryModuleRecord
