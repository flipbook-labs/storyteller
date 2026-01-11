local ControlTypes = require("@root/controls/ControlTypes")

type ListBasedControlSchema = ControlTypes.ListBasedStoryControl
type InputStoryControlValue = ControlTypes.InputStoryControlValue

local function validateListControlHasControlValue(
	controlSchema: ListBasedControlSchema,
	controlValue: InputStoryControlValue?
)
	local controlValueOrDefault = if controlValue then controlValue else controlSchema.default

	if not controlValueOrDefault then
		return
	end

	if typeof(controlValueOrDefault) == "table" then
		for _, nestedControlValue in pairs(controlValueOrDefault) do
			validateListControlHasControlValue(controlSchema, nestedControlValue)
		end
	else
		if not table.find(controlSchema.items, controlValueOrDefault) then
			error(`no item found for {controlValueOrDefault} in control schema {controlSchema}`)
		end
	end
end

return validateListControlHasControlValue
