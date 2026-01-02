local gt = require("@pkg/GreenTea")

local ControlType = require("@root/controls/enums/ControlType")

type ControlType = ControlType.ControlType

local export = {}

local Mapping = gt.build(gt.dictionary(gt.string(), gt.any()))
type Mapping = typeof(Mapping:type())

export type ControlOptions = { string }

local function BaseControl<T>(controlType: ControlType, valueType: T)
	return gt.table({
		type = gt.literal(controlType),
		default = gt.optional(valueType),
	})
end

local function BaseNumberControl(controlType)
	return gt.table({
		type = controlType,
		default = gt.optional(gt.number()),
		step = gt.optional(gt.number()),
		range = gt.optional(gt.isTypeof("NumberRange")),
	})
end

local function SelectOneControl(controlType)
	return gt.table({
		type = gt.literal(controlType),
		options = gt.array(gt.string()),
		mapping = gt.optional(gt.dictionary(gt.string(), gt.any())),
		default = gt.optional(gt.string()),
	})
end

local function SelectManyControl(controlType)
	return gt.table({
		type = gt.literal(controlType),
		options = gt.array(gt.string()),
		mapping = gt.optional(gt.dictionary(gt.string(), gt.any())),
		default = gt.optional(gt.array(gt.string())),
	})
end

local BooleanControl = gt.build(BaseControl("Boolean", gt.boolean()))
export.BooleanControl = BooleanControl
export type BooleanControl = typeof(BooleanControl:type())

local StringControl = gt.build(BaseControl("String", gt.string()))
export.StringControl = StringControl
export type StringControl = typeof(StringControl:type())

local NumberControl = gt.build(BaseNumberControl("Number"))
export.NumberControl = NumberControl
export type NumberControl = typeof(NumberControl:type())

local SliderControl = gt.build(BaseNumberControl("Slider"))
export.SliderControl = SliderControl
export type SliderControl = typeof(SliderControl:type())

local ColorControl = gt.build(BaseControl("Color", gt.Color3()))
export.ColorControl = ColorControl
export type ColorControl = typeof(ColorControl:type())
export type ColourControl = ColorControl

local DateControl = gt.build(BaseControl("Date", gt.isTypeof("DateTime")))
export.DateControl = DateControl
export type DateControl = typeof(DateControl:type())

local SelectControl = gt.build(SelectOneControl("Select"))
export.SelectControl = SelectControl
export type SelectControl = typeof(SelectControl:type())

local RadioControl = gt.build(SelectOneControl("Radio"))
export.RadioControl = RadioControl
export type RadioControl = typeof(RadioControl:type())

local MultiSelectControl = gt.build(SelectManyControl("MultiSelect"))
export.MultiSelectControl = MultiSelectControl
export type MultiSelectControl = typeof(MultiSelectControl:type())

local CheckControl = gt.build(SelectManyControl("Check"))
export.CheckControl = CheckControl
export type CheckControl = typeof(CheckControl:type())

-- Make sure to update this when adding new control types!
local StoryControlValueBase = gt.union(
	gt.union(
		-- Primitives
		gt.boolean(),
		gt.number(),
		gt.string()
	),
	gt.union(
		-- Roblox datatypes
		gt.Color3(),
		gt.isTypeof("DateTime") :: DateTime,
		gt.isTypeof("EnumItem") :: EnumItem
	)
)
local StoryControlValue = gt.build(gt.union(StoryControlValueBase, gt.array(StoryControlValueBase)))
export.StoryControlValue = StoryControlValue
export type StoryControlValue = typeof(StoryControlValue:type())

local PrimitiveStoryControl = gt.build(gt.union(StringControl, BooleanControl, NumberControl))
export.PrimitiveStoryControl = PrimitiveStoryControl
export type PrimitiveStoryControl = typeof(PrimitiveStoryControl:type())

local AdvancedStoryControl =
	gt.build(gt.union(SliderControl, SelectControl, MultiSelectControl, CheckControl, RadioControl))
export.AdvancedStoryControl = AdvancedStoryControl
export type AdvancedStoryControl = typeof(AdvancedStoryControl:type())

local RobloxStoryControl = gt.build(gt.union(ColorControl, DateControl))
export.RobloxStoryControl = RobloxStoryControl
export type RobloxStoryControl = typeof(RobloxStoryControl:type())

local StoryControl = gt.build(gt.union(PrimitiveStoryControl, AdvancedStoryControl, RobloxStoryControl))
export.StoryControl = StoryControl
export type StoryControl = typeof(StoryControl:type())

local StoryControlsSchema = gt.build(gt.dictionary(gt.string, gt.union(StoryControl, StoryControlValue)))
export.StoryControlsSchema = StoryControlsSchema
export type StoryControlsSchema = typeof(StoryControlsSchema:type())

local StoryControls = gt.build(gt.dictionary(gt.string(), StoryControl))
export.StoryControls = StoryControls
export type StoryControls = typeof(StoryControls:type())

return export
