local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")
local validateControlSchema = require("@root/controls/parsing/validateControlSchema")

type SliderControl = ControlTypes.SliderControl

local function createSliderControl(default: number?, range: NumberRange?, step: number?): SliderControl
	local control: SliderControl = {
		type = ControlType.Slider,
		default = default,
		range = range,
		step = step,
	}

	validateControlSchema(ControlType.Slider, control)

	return control
end

return createSliderControl
