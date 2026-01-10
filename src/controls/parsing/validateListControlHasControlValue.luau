local ControlTypes = require("@root/controls/ControlTypes")

type ListBasedControlSchema = ControlTypes.ListBasedStoryControl
type StoryControlValueCompat = ControlTypes.StoryControlValueCompat

local function validateListControlHasControlValue(
	controlSchema: ListBasedControlSchema,
	controlValue: StoryControlValueCompat?
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
		local key = tostring(controlValueOrDefault)

		if not table.find(controlSchema.items, key) then
			error(`no item found for {key} in control schema {controlSchema}`)
		end
	end
end

return validateListControlHasControlValue
