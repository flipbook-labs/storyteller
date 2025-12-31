local ControlTypes = require("@root/controls/ControlTypes")
local StorytellerV140Migration = require("@root/controls/migrations/storyteller-v1.4.0")
local UILabsV242Migration = require("@root/controls/migrations/ui-labs-v2.4.2")

type StorytellerV140StoryControls = {
	[string]: any,
}

type StoryControls = ControlTypes.StoryControls
type StoryControlsSchema = ControlTypes.StoryControlsSchema

local function migrateControlsSchema(schema: { [any]: any }): StoryControlsSchema?
	if UILabsV242Migration.isUILabsControlsSchema(schema) then
		return UILabsV242Migration.migrateUILabsControlsSchema(schema)
	elseif StorytellerV140Migration.isStorytellerControlsSchema(schema) then
		return StorytellerV140Migration.migrateStorytellerControlsSchema(schema)
	end

	return nil
end

return migrateControlsSchema
