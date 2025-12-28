local ControlType = require("@root/controls/enums/ControlType")
local types = require("@root/controls/types")

type SelectControl<T> = types.SelectControl<T>
type Mapping<T> = types.Mapping<T>

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
