local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type SelectControl<T> = ControlTypes.SelectControl<T>
type Mapping<T> = ControlTypes.Mapping<T>

local function createSelectControl<ControlValue>(
	options: { string },
	default: string?,
	mapping: Mapping<ControlValue>?
): SelectControl<ControlValue>
	return {
		control = ControlType.Select,
		options = options,
		default = default,
		mapping = mapping,
	}
end

return createSelectControl
