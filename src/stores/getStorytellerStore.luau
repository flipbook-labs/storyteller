local Charm = require("@pkg/Charm")

local StorytellerStore = require("@root/stores/StorytellerStore")

local getStorytellerStore = Charm.computed(function()
	return StorytellerStore.new(game)
end)

return getStorytellerStore
