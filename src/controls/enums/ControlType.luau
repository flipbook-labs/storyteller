export type ControlType =
	-- Primitives
	"Boolean"
	| "Number"
	| "String"
	-- Advanced
	| "Check"
	| "Color"
	| "Date"
	| "MultiSelect"
	| "Radio"
	| "Select"
	| "Slider"

local ControlType = {
	-- Primitives
	Boolean = "Boolean" :: "Boolean",
	Number = "Number" :: "Number",
	String = "String" :: "String",

	-- Advanced
	Check = "Check" :: "Check",
	Color = "Color" :: "Color",
	Date = "Date" :: "Date",
	MultiSelect = "MultiSelect" :: "MultiSelect",
	Radio = "Radio" :: "Radio",
	Select = "Select" :: "Select",
	Slider = "Slider" :: "Slider",
}

return ControlType
