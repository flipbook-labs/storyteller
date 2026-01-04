local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type StoryControl = ControlTypes.StoryControl
type StoryControlValue = ControlTypes.StoryControlValue
type NumberBasedStoryControl = ControlTypes.NumberBasedStoryControl
type ListBasedStoryControl = ControlTypes.ListBasedStoryControl

local function transformControlValue(controlSchema: StoryControl, controlValue: StoryControlValue?): StoryControlValue?
	local controlValueOrDefault: StoryControlValue? = if controlValue then controlValue else controlSchema.default

	if controlSchema.type == ControlType.Number or controlSchema.type == ControlType.Slider then
		local numberBasedControl = controlSchema :: NumberBasedStoryControl

		if typeof(controlValueOrDefault) == "number" then
			local range = numberBasedControl.range

			if range then
				return math.clamp(controlValueOrDefault, range.Min, range.Max)
			end
		end
	end

	if controlSchema.type == ControlType.Check or controlSchema.type == ControlType.MultiSelect then
		local listBasedControl = controlSchema :: ListBasedStoryControl

		if typeof(controlValueOrDefault) == "table" then
			local result = {}
			local mapping = listBasedControl.mapping

			for _, option in controlValueOrDefault do
				if mapping then
					table.insert(result, mapping[tostring(option)])
				else
					table.insert(result, option)
				end
			end
			return result
		end
	end

	if controlSchema.type == ControlType.Radio or controlSchema.type == ControlType.Select then
		local listBasedControl = controlSchema :: ListBasedStoryControl

		local mapping = listBasedControl.mapping
		if mapping then
			local mappedControlValue = mapping[tostring(controlValueOrDefault)]
			if mappedControlValue then
				return mappedControlValue
			end
		end
	end

	return controlValueOrDefault
end

return transformControlValue
