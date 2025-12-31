local ControlTypes = require("@root/controls/ControlTypes")

type StoryControl = ControlTypes.StoryControl

local function toStoryControl<T>(value: T): StoryControl?
	if typeof(value) == "table" and rawget(value, "control") then
		return (value :: any) :: StoryControl
	end
	return nil
end

return toStoryControl
