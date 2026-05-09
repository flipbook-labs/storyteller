local UILabsTypes = require("@root/controls/migrations/ui-labs-v2.4.2/UILabsTypes")

export type StoryControlsSchema = UILabsTypes.StoryControlsSchema

return {
	isUILabsControlsSchema = require("@self/isUILabsControlsSchema"),
	migrateUILabsControlsSchema = require("@self/migrateUILabsControlsSchema"),
}
