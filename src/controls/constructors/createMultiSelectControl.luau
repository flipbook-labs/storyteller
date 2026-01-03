local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")
local validateControlSchema = require("@root/controls/parsing/validateControlSchema")

type MultiSelectControl = ControlTypes.MultiSelectControl
type Mapping = ControlTypes.Mapping

local function createMultiSelectControl(options: { string }, mapping: Mapping?): MultiSelectControl
	local control: MultiSelectControl = {
		type = ControlType.MultiSelect,
		options = options,
		mapping = mapping,
	}

	validateControlSchema(ControlType.MultiSelect, control)

	return control
end

return createMultiSelectControl
