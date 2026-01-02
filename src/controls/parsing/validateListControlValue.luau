local ControlTypes = require("@root/controls/ControlTypes")

type ListBasedStoryControl = ControlTypes.ListBasedStoryControl

local function validateListControlValue(
	controlName: string,
	controlSchema: ListBasedStoryControl,
	controlValue: unknown?
)
	local options = {}

	if typeof(controlValue) == "table" then
		for _, value in controlValue :: { [any]: any } do
			table.insert(options, value)
		end
	else
		table.insert(options, controlValue)
	end

	for _, optionValue in options do
		assert(
			table.find(controlSchema.options, optionValue),
			`failed to hydrate "{controlName}" (expected control value "{optionValue}" to be included in 'options')`
		)

		if controlSchema.mapping then
			local mappedOptionValue = if controlSchema.mapping then controlSchema.mapping[optionValue] else nil

			assert(
				mappedOptionValue,
				`failed to hydrate "{controlName}" (could not map "{optionValue}" to one of the values in 'mapping')`
			)
		end
	end
end

return validateListControlValue
