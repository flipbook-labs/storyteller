local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type RadioControl = ControlTypes.RadioControl
type RadioOptions = ControlTypes.RadioOptions
type StoryControlValue = ControlTypes.StoryControlValue

local function createRadioControl(items: { StoryControlValue }, options: RadioOptions?): RadioControl
	local control: RadioControl = {
		type = ControlType.Radio,
		items = items,
	}

	if options then
		for k, v in options do
			control[k] = v
		end
	end

	ControlTypes.RadioControl:assert(control)

	return control
end

return createRadioControl
