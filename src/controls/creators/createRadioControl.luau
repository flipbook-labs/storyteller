local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type RadioControl<T> = ControlTypes.RadioControl<T>
type Mapping<T> = ControlTypes.Mapping<T>

local function createRadioControl<T>(options: { string }, default: string?, mapping: Mapping<T>?): RadioControl<T>
	return {
		control = ControlType.Radio,
		options = options,
		default = default,
		mapping = mapping,
	}
end

return createRadioControl
