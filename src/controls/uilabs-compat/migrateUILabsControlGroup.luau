local UILabsTypes = require("@root/controls/uilabs-compat/UILabsTypes")
local migrateUILabsControl = require("@root/controls/uilabs-compat/migrateUILabsControl")
local types = require("@root/controls/types")

type ControlGroup = UILabsTypes.ControlGroup

local function migrateUILabsControlGroup(controlGroup: ControlGroup): types.StoryControlsSchema?
	local controls: types.StoryControlsSchema = {}

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
