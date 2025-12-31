-- local t = require("@pkg/t")

local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")
local transformControlValue = require("@root/controls/parsing/transformControlValue")
local validateControlSchema = require("@root/controls/parsing/validateControlSchema")
local validateListControlValue = require("@root/controls/parsing/validateListControlValue")

type StoryControlsSchema = ControlTypes.StoryControlsSchema
type StoryControls = ControlTypes.StoryControls

--[[
	As a principle:
	1. Throw when there's an issue with the schema
	2. Constrain when there's an issue with a control

	For example, if a Number control's schema defined the default value as out
	of range then that should cause an error. But if a user supplies a value out
	of range, we constrain the value that gets passed off to the story to make
	sure its within the range.
]]

local function hydrateControls(schema: StoryControlsSchema, controls: StoryControls): StoryControls
	local hydrated: StoryControls = {}

	for controlName, controlSchema in pairs(schema) do
		local controlValue = controls[controlName]

		validateControlSchema(controlName, controlSchema)

		if
			controlSchema.control == ControlType.Check
			or controlSchema.control == ControlType.MultiSelect
			or controlSchema.control == ControlType.Radio
			or controlSchema.control == ControlType.Select
		then
			validateListControlValue(controlName, controlSchema, controlValue)
		end

		controlValue = transformControlValue(controlSchema, controlValue)

		if controlValue ~= nil then
			hydrated[controlName] = controlValue
		end
	end

	return hydrated
end

return hydrateControls
