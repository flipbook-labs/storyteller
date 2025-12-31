local Sift = require("@pkg/Sift")

local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")
local UILabsTypes = require("@root/controls/migrations/ui-labs-v2.4.2/UILabsTypes")

type UILabsControl = UILabsTypes.Control

type StoryControl = ControlTypes.StoryControl
type StringControl = ControlTypes.StringControl
type NumberControl = ControlTypes.NumberControl
type BooleanControl = ControlTypes.BooleanControl
type SelectControl<T> = ControlTypes.SelectControl<T>
type SliderControl = ControlTypes.SliderControl
type ColorControl = ControlTypes.ColorControl

local function migrateUILabsControl(control: UILabsControl): StoryControl?
	if control.Type == "String" then
		local migrated: StringControl = {
			control = ControlType.String,
			default = control.ControlValue,
		}
		return migrated
	elseif control.Type == "Number" then
		local migrated: NumberControl = {
			control = ControlType.Number,
			default = control.ControlValue,
			range = if control.Min and control.Max then NumberRange.new(control.Min, control.Max) else nil,
			step = control.Step,
		}
		return migrated
	elseif control.Type == "Boolean" then
		local migrated: BooleanControl = {
			control = ControlType.Boolean,
			default = control.ControlValue,
		}
		return migrated
	elseif control.Type == "Choose" then
		local migrated: SelectControl<unknown> = {
			control = ControlType.Select,
			options = Sift.List.map(control.List, tostring),
			default = tostring(control.List[control.DefIndex]),
		}
		return migrated
	elseif control.Type == "EnumList" then
		local migrated: SelectControl<unknown> = {
			control = ControlType.Select,
			options = Sift.List.sort(Sift.Dictionary.values(control.List)),
			default = control.List[control.DefIndex],
		}
		return migrated
	elseif control.Type == "Slider" then
		local migrated: SliderControl = {
			control = ControlType.Slider,
			default = control.ControlValue,
			range = NumberRange.new(control.Min, control.Max),
			step = control.Step,
		}
		return migrated
	elseif control.Type == "RGBA" then
		local migrated: ColorControl = {
			control = ControlType.Color,
			default = control.ControlValue.Color,
		}
		return migrated
	elseif control.Type == "Object" then
		return nil
	end
	return nil
end

return migrateUILabsControl
