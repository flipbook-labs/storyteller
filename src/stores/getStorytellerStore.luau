local Signals = require("@rbxpkg/Signals")

local StorytellerStore = require("@root/stores/StorytellerStore")

local getStorytellerStore = Signals.createComputed(function()
	return StorytellerStore.new(game)
end)

return getStorytellerStore
