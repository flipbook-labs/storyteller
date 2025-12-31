local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type MultiSelectControl = ControlTypes.MultiSelectControl
type Mapping = ControlTypes.Mapping

local function createMultiSelectControl(options: { string }, mapping: Mapping?): MultiSelectControl
	return {
		control = ControlType.MultiSelect,
		options = options,
		mapping = mapping,
	}
end

return createMultiSelectControl
