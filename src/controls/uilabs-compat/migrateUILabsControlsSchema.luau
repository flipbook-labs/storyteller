local ControlTypes = require("@root/controls/ControlTypes")
local UILabsTypes = require("@root/controls/uilabs-compat/UILabsTypes")
local migrateUILabsControl = require("@root/controls/uilabs-compat/migrateUILabsControl")
local migrateUILabsControlGroup = require("@root/controls/uilabs-compat/migrateUILabsControlGroup")

type UILabsControlsSchema = UILabsTypes.ControlsSchema
type StoryControlsSchema = ControlTypes.StoryControlsSchema

local function migrateUILabsControlsSchema(schema: UILabsControlsSchema): StoryControlsSchema
	local newSchema: StoryControlsSchema = {}

	for key, value in schema do
		if value.EntryType == "Control" then
			local migrated = migrateUILabsControl(value)

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
