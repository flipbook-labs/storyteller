local ControlTypes = require("@root/controls/ControlTypes")
local UILabsTypes = require("@root/controls/migrations/ui-labs-v2.4.2/UILabsTypes")
local migrateUILabsControl = require("@root/controls/migrations/ui-labs-v2.4.2/migrateUILabsControl")
local migrateUILabsControlGroup = require("@root/controls/migrations/ui-labs-v2.4.2/migrateUILabsControlGroup")

type UILabsControl = UILabsTypes.Control
type UILabsControlsSchema = UILabsTypes.ControlsSchema
type StoryControlsSchema = ControlTypes.StoryControlsSchema

local function migrateUILabsControlsSchema(schema: UILabsControlsSchema): StoryControlsSchema
	local newSchema: StoryControlsSchema = {}

	for key, value in schema do
		if value.EntryType == "Control" then
			local migrated = migrateUILabsControl(value :: UILabsControl)

			if migrated then
				newSchema[key] = migrated
			end
		elseif value.EntryType == "ControlGroup" then
			local migrated = migrateUILabsControlGroup(value)

			if migrated then
				for groupKey, groupValue in migrated do
					newSchema[groupKey] = groupValue
				end
			end
		end
	end

	return newSchema
end

return migrateUILabsControlsSchema
