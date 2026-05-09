local ControlTypes = require("@root/controls/ControlTypes")
local UILabsTypes = require("@root/controls/migrations/ui-labs-v2.4.2/UILabsTypes")
local migrateUILabsControl = require("@root/controls/migrations/ui-labs-v2.4.2/migrateUILabsControl")

type ControlGroup = UILabsTypes.ControlGroup
type StoryControlsSchema = ControlTypes.StoryControlsSchema

local function migrateUILabsControlGroup(controlGroup: ControlGroup): StoryControlsSchema?
	local controls: StoryControlsSchema = {}

	local hasControls = false

	for key, control in controlGroup.Controls do
		hasControls = true

		local migrated = migrateUILabsControl(control)

		if migrated then
			controls[key] = migrated
		end
	end

	if not hasControls then
		return nil
	end

	return controls
end

return migrateUILabsControlGroup
