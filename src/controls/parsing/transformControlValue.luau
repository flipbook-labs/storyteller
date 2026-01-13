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

	-- When the user does not specify a default value for a list-based control
	-- we implicitly use the first item instead
	if not controlValueOrDefault then
		local items = rawget(controlSchema, "items")
		if items then
			return items[1]
		end
	end

	return controlValueOrDefault
end

return transformControlValue
