local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")
local getPossibleControlOptions = require("@root/controls/parsing/getPossibleControlOptions")

type StoryControl = ControlTypes.StoryControl
type StoryControlValue = ControlTypes.StoryControlValue
type StoryControlValueBase = ControlTypes.StoryControlValueBase
type NumberBasedStoryControl = ControlTypes.NumberBasedStoryControl
type ListBasedStoryControl = ControlTypes.ListBasedStoryControl
type MappedControlOptions = ControlTypes.MappedControlOptions

local function transformControlOption(
	controlSchema: ListBasedStoryControl,
	controlValue: StoryControlValueBase?
): StoryControlValueBase?
	for _, option in getPossibleControlOptions(controlSchema.options) do
		if option == controlValue then
			if ControlTypes.MappedControlOptions:matches(controlSchema.options) then
				local options = controlSchema.options :: MappedControlOptions
				return options[tostring(controlValue)]
			else
				return controlValue
			end
		end
	end
	return nil
end

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
		if typeof(controlValueOrDefault) == "table" then
			local result: { StoryControlValueBase } = {}
			for _, option in controlValueOrDefault do
				local transformed = transformControlOption(controlSchema :: ListBasedStoryControl, option)
				if transformed then
					table.insert(result, transformed)
				end
			end
			return result
		end
	end

	if controlSchema.type == ControlType.Radio or controlSchema.type == ControlType.Select then
		return transformControlOption(controlSchema :: ListBasedStoryControl, controlValueOrDefault)
	end

	return controlValueOrDefault
end

return transformControlValue
