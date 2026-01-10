local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type StoryControl = ControlTypes.StoryControl
type StoryControlValueCompat = ControlTypes.StoryControlValueCompat
type NumberBasedStoryControl = ControlTypes.NumberBasedStoryControl
type ListBasedStoryControl = ControlTypes.ListBasedStoryControl

local function transformControlValue(
	controlSchema: StoryControl,
	controlValue: StoryControlValueCompat?
): StoryControlValueCompat?
	local controlValueOrDefault: StoryControlValueCompat? = if controlValue then controlValue else controlSchema.default

	if controlSchema.type == ControlType.Number or controlSchema.type == ControlType.Slider then
		local numberBasedControl = controlSchema :: NumberBasedStoryControl

		if typeof(controlValueOrDefault) == "number" then
			local range = numberBasedControl.range

			if range then
				return math.clamp(controlValueOrDefault, range.Min, range.Max)
			end
		end
	end

	return controlValueOrDefault
end

return transformControlValue
