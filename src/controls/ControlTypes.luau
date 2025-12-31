local ControlType = require("@root/controls/enums/ControlType")

type ControlType = ControlType.ControlType

export type Mapping<T> = { [string]: T }

type BaseControl<ControlType, Value> = {
	control: ControlType,
	default: Value?,
}

type BaseNumberControl<ControlType> = BaseControl<ControlType, number> & {
	step: number?,
	range: NumberRange?,
}

type SelectOneControl<ControlType, Value> = BaseControl<ControlType, string> & {
	options: { string },
	mapping: Mapping<Value>?,
}

type SelectManyControl<ControlType, Value> = BaseControl<ControlType, { string }> & {
	options: { string },
	mapping: Mapping<Value>?,
}

export type BooleanControl = BaseControl<"Boolean", boolean>
export type CheckControl<T> = SelectManyControl<"Check", T>
export type ColorControl = BaseControl<"Color", Color3>
export type ColourControl = ColorControl
export type DateControl = BaseControl<"Date", DateTime>
export type MultiSelectControl<T> = SelectManyControl<"MultiSelect", T>
export type NumberControl = BaseNumberControl<"Number">
export type RadioControl<T> = SelectOneControl<"Radio", T>
export type SelectControl<T> = SelectOneControl<"Select", T>
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

export type PrimitiveStoryControl = StringControl | BooleanControl | NumberControl
export type ExtendedStoryControl = SliderControl | ColorControl | DateControl
export type ListBasedStoryControl<T> = SelectControl<T> | MultiSelectControl<T> | CheckControl<T> | RadioControl<T>

export type StoryControl = PrimitiveStoryControl | ExtendedStoryControl | ListBasedStoryControl<unknown>

export type StoryControlsSchema = {
	[string]: StoryControl | StoryControlValue,
}

export type StoryControls = {
	[string]: StoryControlValue,
}

return nil
