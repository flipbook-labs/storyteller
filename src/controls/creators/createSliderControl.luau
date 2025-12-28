local ControlType = require("@root/controls/enums/ControlType")
local types = require("@root/controls/types")

type SliderControl = types.SliderControl

local function createSliderControl(default: number?, range: NumberRange?, step: number?): SliderControl
	return {
		control = ControlType.Slider,
		default = default,
		range = range,
		step = step,
	}
end

return createSliderControl
