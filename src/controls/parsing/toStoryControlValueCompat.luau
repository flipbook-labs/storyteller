local ControlTypes = require("@root/controls/ControlTypes")

type StoryControlValueCompat = ControlTypes.StoryControlValueCompat

local function toStoryControlValueCompat<T>(value: T): StoryControlValueCompat?
	if ControlTypes.StoryControlValueCompat(value) then
		return (value :: any) :: StoryControlValueCompat
	end
	return nil
end

return toStoryControlValueCompat
