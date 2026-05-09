local ControlTypes = require("@root/controls/ControlTypes")

type StoryControlValue = ControlTypes.StoryControlValue

local function toStoryControlValue<T>(value: T): StoryControlValue?
	if ControlTypes.StoryControlValue(value) then
		return (value :: any) :: StoryControlValue
	end
	return nil
end

return toStoryControlValue
