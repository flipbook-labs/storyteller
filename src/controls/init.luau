local ControlType = require("@self/enums/ControlType")
local ControlTypes = require("@self/ControlTypes")

export type ControlType = ControlType.ControlType

export type BooleanControl = ControlTypes.BooleanControl
export type CheckControl = ControlTypes.CheckControl
export type ColorControl = ControlTypes.ColorControl
export type ColourControl = ControlTypes.ColourControl
export type DateControl = ControlTypes.DateControl
export type MultiSelectControl = ControlTypes.MultiSelectControl
export type NumberControl = ControlTypes.NumberControl
export type RadioControl = ControlTypes.RadioControl
export type SelectControl = ControlTypes.SelectControl
export type SliderControl = ControlTypes.SliderControl
export type StringControl = ControlTypes.StringControl
export type StoryControl = ControlTypes.StoryControl
export type StoryControlsSchema = ControlTypes.StoryControlsSchema
export type StoryControls = ControlTypes.StoryControls

return {
	-- Enums
	ControlType = ControlType,

	-- Functions
	hydrateControls = require("@self/hydrateControls"),

	-- Constructors
	createBooleanControl = require("@self/constructors/createBooleanControl"),
	createCheckControl = require("@self/constructors/createCheckControl"),
	createColorControl = require("@self/constructors/createColorControl"),
	createDateControl = require("@self/constructors/createDateControl"),
	createMultiSelectControl = require("@self/constructors/createMultiSelectControl"),
	createNumberControl = require("@self/constructors/createNumberControl"),
	createRadioControl = require("@self/constructors/createRadioControl"),
	createSelectControl = require("@self/constructors/createSelectControl"),
	createSliderControl = require("@self/constructors/createSliderControl"),
	createStringControl = require("@self/constructors/createStringControl"),
}
