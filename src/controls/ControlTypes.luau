local t = require("@pkg/t")

local ControlType = require("@root/controls/enums/ControlType")

local types = {}

type ControlType = ControlType.ControlType

export type Mapping = { [string]: StoryControlValue }
export type ControlOptions = { string }

type BaseControl<ControlType, Value> = {
	type: ControlType,
	default: Value?,
}

type BaseNumberControl<ControlType> = BaseControl<ControlType, number> & {
	step: number?,
	range: NumberRange?,
}

type SelectOneControl<ControlType> = BaseControl<ControlType, string> & {
	options: ControlOptions,
	mapping: Mapping?,
}

type SelectManyControl<ControlType> = BaseControl<ControlType, ControlOptions> & {
	options: ControlOptions,
	mapping: Mapping?,
}

export type BooleanControl = BaseControl<"Boolean", boolean>
export type CheckControl = SelectManyControl<"Check">
export type ColorControl = BaseControl<"Color", Color3>
export type ColourControl = ColorControl
export type DateControl = BaseControl<"Date", DateTime>
export type MultiSelectControl = SelectManyControl<"MultiSelect">
export type NumberControl = BaseNumberControl<"Number">
export type RadioControl = SelectOneControl<"Radio">
export type SelectControl = SelectOneControl<"Select">
export type SliderControl = BaseNumberControl<"Slider">
export type StringControl = BaseControl<"String", string>

-- Make sure to update this when adding new control types!
export type StoryControlValue =
	boolean
	| number
	| string
	-- Roblox datatypes
	| Color3
	| DateTime
	| EnumItem
	| { StoryControlValue }
local StoryControlValue = t.union(t.boolean, t.number, t.string, t.Color3, t.DateTime, t.EnumItem)
types.StoryControlValue = t.union(StoryControlValue, t.array(StoryControlValue))

export type PrimitiveStoryControl = StringControl | BooleanControl | NumberControl
export type ExtendedStoryControl = SliderControl | ColorControl | DateControl
export type ListBasedStoryControl = SelectControl | MultiSelectControl | CheckControl | RadioControl
export type NumberBasedStoryControl = SliderControl | NumberControl

export type StoryControl = PrimitiveStoryControl | ExtendedStoryControl | ListBasedStoryControl

export type StoryControlsSchema = {
	[string]: StoryControl | StoryControlValue,
}

export type StoryControls = {
	[string]: StoryControlValue,
}

return types
