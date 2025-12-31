local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type CheckControl<T> = ControlTypes.CheckControl<T>
type Mapping<T> = ControlTypes.Mapping<T>

local function createCheckControl<T>(options: { string }, default: { string }?, mapping: Mapping<T>?): CheckControl<T>
	return {
		control = ControlType.Check,
		options = options,
		default = default,
		mapping = mapping,
	}
end

return createCheckControl
