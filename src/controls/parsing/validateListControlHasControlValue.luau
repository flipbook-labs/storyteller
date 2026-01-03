local ControlTypes = require("@root/controls/ControlTypes")
local getPossibleControlOptions = require("@root/controls/parsing/getPossibleControlOptions")

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
		local options = getPossibleControlOptions(controlSchema.options)

		if not table.find(options, key) then
			error(`no option found for "{key}" in "{table.concat(options, ", ")}"`)
		end
	end
end

return validateListControlHasControlValue
