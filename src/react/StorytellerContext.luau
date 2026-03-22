local React = require("@pkg/React")
local StorytellerStore = require("@root/stores/StorytellerStore")

export type StorytellerContext = {
	store: StorytellerStore.StorytellerStore,
}

local defaultValue: StorytellerContext = {
	store = StorytellerStore.instance,
}

local StorytellerContext = React.createContext(defaultValue)
StorytellerContext.displayName = "StorytellerContext"

return StorytellerContext
