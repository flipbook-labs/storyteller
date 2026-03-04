local Charm = require("@pkg/Charm")

local StorytellerStore = require("@root/stores/StorytellerStore")

local getStorytellerStore = Charm.createComputed(function()
	return StorytellerStore.new(game)
end)

return getStorytellerStore
