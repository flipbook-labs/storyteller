local ControlTypes = require("@root/controls/ControlTypes")
local toStoryControl = require("@root/controls/parsing/toStoryControl")

type StoryControlValue = ControlTypes.StoryControlValue

local function toStoryControlValue<T>(value: T): StoryControlValue?
	if not toStoryControl(value) then
		return (value :: any) :: StoryControlValue
	end
	return nil
end

return toStoryControlValue
