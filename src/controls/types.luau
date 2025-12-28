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

export type ListBasedStoryControl<T> = SelectControl<T> | MultiSelectControl<T> | CheckControl<T> | RadioControl<T>

export type StoryControl =
	StringControl
	| BooleanControl
	| NumberControl
	| SliderControl
	| ColorControl
	| DateControl
	| ListBasedStoryControl<unknown>

export type StoryControlsSchema = {
	[string]: StoryControl,
}

export type StoryControls = {
	[string]: unknown,
}

return nil
