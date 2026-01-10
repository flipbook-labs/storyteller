local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type MultiSelectControl = ControlTypes.MultiSelectControl
type MultiSelectOptions = ControlTypes.MultiSelectOptions
type StoryControlValue = ControlTypes.StoryControlValue

local function createMultiSelectControl(items: { StoryControlValue }, options: MultiSelectOptions?): MultiSelectControl
	local control: MultiSelectControl = {
		type = ControlType.MultiSelect,
		items = items,
	}

	if options then
		for k, v in options do
			control[k] = v
		end
	end

	ControlTypes.MultiSelectControl:assert(control)

	return control
end

return createMultiSelectControl
