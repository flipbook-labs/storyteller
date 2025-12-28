local ControlType = require("@root/controls/enums/ControlType")
local types = require("@root/controls/types")

type MultiSelectControl<T> = types.MultiSelectControl<T>
type Mapping<T> = types.Mapping<T>

local function createMultiSelectControl<T>(options: { string }, mapping: Mapping<T>?): MultiSelectControl<T>
	return {
		control = ControlType.MultiSelect,
		options = options,
		mapping = mapping,
	}
end

return createMultiSelectControl
