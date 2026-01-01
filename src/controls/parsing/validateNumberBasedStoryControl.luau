local ControlTypes = require("@root/controls/ControlTypes")

type NumberBasedStoryControl = ControlTypes.NumberBasedStoryControl

local function validateNumberBasedStoryControl(controlSchema: NumberBasedStoryControl)
	local default = controlSchema.default
	local range = controlSchema.range
	if default and range then
		if default < range.Min or default > range.Max then
			error(
				`attempt to set default value outside of range (default of {default} is not in range of [{range.Min}, {range.Max}])`,
				2
			)
		end
	end
end

return validateNumberBasedStoryControl
