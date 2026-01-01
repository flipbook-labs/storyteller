local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")
local validateNumberBasedStoryControl = require("@root/controls/parsing/validateNumberBasedStoryControl")

type SliderControl = ControlTypes.SliderControl

local function createSliderControl(default: number?, range: NumberRange?, step: number?): SliderControl
	local control = {
		type = ControlType.Slider,
		default = default,
		range = range,
		step = step,
	}

	validateNumberBasedStoryControl(control)

	return control
end

return createSliderControl
