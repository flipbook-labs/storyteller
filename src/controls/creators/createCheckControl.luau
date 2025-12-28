local ControlType = require("@root/controls/enums/ControlType")
local types = require("@root/controls/types")

type CheckControl<T> = types.CheckControl<T>
type Mapping<T> = types.Mapping<T>

local function createCheckControl<T>(options: { string }, default: { string }?, mapping: Mapping<T>?): CheckControl<T>
	return {
		control = ControlType.Check,
		options = options,
		default = default,
		mapping = mapping,
	}
end

return createCheckControl
