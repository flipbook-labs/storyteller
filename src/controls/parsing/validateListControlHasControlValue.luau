local ControlTypes = require("@root/controls/ControlTypes")

type ListBasedControlSchema = ControlTypes.ListBasedStoryControl
type StoryControlValue = ControlTypes.StoryControlValue

local function validateListControlHasControlValue(
	controlSchema: ListBasedControlSchema,
	controlValue: StoryControlValue?
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

		if controlSchema.mapping then
			if controlSchema.mapping[key] == nil then
				error(`no mapping found for {key} in control schema {controlSchema}`)
			end
		end

		if not table.find(controlSchema.options, key) then
			error(`no option found for {key} in control schema {controlSchema}`)
		end
	end
end

return validateListControlHasControlValue
