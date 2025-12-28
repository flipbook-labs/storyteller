local ControlType = require("@root/controls/enums/ControlType")
local types = require("@root/controls/types")

type SelectControl = types.SelectControl
type Mapping = types.Mapping

local function createSelectControl<T>(options: { T }, mapping: Mapping?): SelectControl
	return {
		control = ControlType.Select,
		options = options,
		mapping = mapping,
	}
end

return createSelectControl
