local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type StoryControl = ControlTypes.StoryControl
type StoryControlValue = ControlTypes.StoryControlValue
type InputStoryControlValue = ControlTypes.InputStoryControlValue
type NumberBasedStoryControl = ControlTypes.NumberBasedStoryControl
type ListBasedStoryControl = ControlTypes.ListBasedStoryControl

local function transformControlValue(
	controlSchema: StoryControl,
	controlValue: InputStoryControlValue?
): InputStoryControlValue?
	local controlValueOrDefault: InputStoryControlValue? = if controlValue then controlValue else controlSchema.default

	if controlSchema.type == ControlType.Number or controlSchema.type == ControlType.Slider then
		local numberBasedControl = controlSchema :: NumberBasedStoryControl

		if typeof(controlValueOrDefault) == "number" then
			local range = numberBasedControl.range

			if range then
				return math.clamp(controlValueOrDefault, range.Min, range.Max)
			end
		end
	end

	if not controlValueOrDefault then
		if controlSchema.type == ControlType.Check or controlSchema.type == ControlType.MultiSelect then
			return {}
		end

		if controlSchema.type == ControlType.Select then
			local items = rawget(controlSchema, "items")
			if items then
				return items[1]
			end
		end
	end

	return controlValueOrDefault
end

return transformControlValue
