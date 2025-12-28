local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type MultiSelectControl<T> = ControlTypes.MultiSelectControl<T>
type Mapping<T> = ControlTypes.Mapping<T>

local function createMultiSelectControl<T>(options: { string }, mapping: Mapping<T>?): MultiSelectControl<T>
	return {
		control = ControlType.MultiSelect,
		options = options,
		mapping = mapping,
	}
end

return createMultiSelectControl
