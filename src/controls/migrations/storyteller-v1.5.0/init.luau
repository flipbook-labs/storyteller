local types = require("@self/types")

export type StoryControlsSchema = types.StoryControlsSchema

return {
	isStorytellerControlsSchema = require("@self/isStorytellerControlsSchema"),
	migrateStorytellerControlsSchema = require("@self/migrateStorytellerControlsSchema"),
}
