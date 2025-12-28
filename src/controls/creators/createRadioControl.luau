local ControlType = require("@root/controls/enums/ControlType")
local types = require("@root/controls/types")

type RadioControl<T> = types.RadioControl<T>
type Mapping<T> = types.Mapping<T>

local function createRadioControl<T>(options: { string }, default: string?, mapping: Mapping<T>?): RadioControl<T>
	return {
		control = ControlType.Radio,
		options = options,
		default = default,
		mapping = mapping,
	}
end

return createRadioControl
