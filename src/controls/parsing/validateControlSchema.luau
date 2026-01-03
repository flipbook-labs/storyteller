local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type StoryControl = ControlTypes.StoryControl
type NumberBasedStoryControl = ControlTypes.NumberBasedStoryControl
type ListBasedStoryControl = ControlTypes.ListBasedStoryControl

local function validateControlSchema(controlName: string, controlSchema: StoryControl)
	local defaultValue = controlSchema.default

	if defaultValue then
		if controlSchema.type == ControlType.Number or controlSchema.type == ControlType.Slider then
			local numberBasedControl = controlSchema :: NumberBasedStoryControl

			assert(
				typeof(defaultValue) == "number",
				`failed to hydrate "{controlName}" (number expected for default value, got "{typeof(defaultValue)})`
			)

			local range = numberBasedControl.range
			if range then
				assert(
					typeof(defaultValue) == "number" and defaultValue >= range.Min and defaultValue <= range.Max,
					`failed to hydrate "{controlName}" (default value "{defaultValue}" must be a number within the range [{range.Min}, {range.Max}])`
				)
			end
		end

		if controlSchema.type == ControlType.Check or controlSchema.type == ControlType.MultiSelect then
			local listBasedControl = controlSchema :: ListBasedStoryControl

			assert(
				typeof(defaultValue) == "table",
				`failed to hydrate "{controlName}" (array expected for default value, got "{typeof(defaultValue)}")`
			)

			for _, option in defaultValue :: { [any]: any } do
				assert(
					table.find(listBasedControl.options, option),
					`failed to hydrate "{controlName}" (value "{option}" not found in 'options')`
				)
			end
		end

		if controlSchema.type == ControlType.Radio or controlSchema.type == ControlType.Select then
			local listBasedControl = controlSchema :: ListBasedStoryControl

			assert(
				table.find(listBasedControl.options, tostring(defaultValue)),
				`failed to hydrate "{controlName}" (value "{defaultValue}" not found in 'options')`
			)
		end
	end
end

return validateControlSchema
