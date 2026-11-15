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
	| "Object"
	| "Radio"
	| "Select"
	| "Slider"

local ControlType = table.freeze({
	-- Primitives
	Boolean = "Boolean" :: "Boolean",
	Number = "Number" :: "Number",
	String = "String" :: "String",

	-- Advanced
	Check = "Check" :: "Check",
	Color = "Color" :: "Color",
	Date = "Date" :: "Date",
	MultiSelect = "MultiSelect" :: "MultiSelect",
	Object = "Object" :: "Object",
	Radio = "Radio" :: "Radio",
	Select = "Select" :: "Select",
	Slider = "Slider" :: "Slider",
})

return ControlType
