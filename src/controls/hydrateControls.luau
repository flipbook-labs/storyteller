local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")
local toStoryControl = require("@root/controls/parsing/toStoryControl")
local toStoryControlValue = require("@root/controls/parsing/toStoryControlValue")
local transformControlValue = require("@root/controls/parsing/transformControlValue")
local validateControlSchema = require("@root/controls/parsing/validateControlSchema")
local validateListControlValue = require("@root/controls/parsing/validateListControlValue")

type StoryControlsSchema = ControlTypes.StoryControlsSchema
type StoryControls = ControlTypes.StoryControls
type StoryControl = ControlTypes.StoryControl
type StoryControlValue = ControlTypes.StoryControlValue

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

	for controlName, controlSchemaOrValue in schema do
		local controlSchema = toStoryControl(controlSchemaOrValue)

		if controlSchema then
			local controlValue: StoryControlValue? = controls[controlName]

			validateControlSchema(controlName, controlSchema)

			if
				controlSchema.control == ControlType.Check
				or controlSchema.control == ControlType.MultiSelect
				or controlSchema.control == ControlType.Radio
				or controlSchema.control == ControlType.Select
			then
				validateListControlValue(controlName, controlSchema, controlValue)
			end

			local transformed = transformControlValue(controlSchema, controlValue)

			hydrated[controlName] = transformed
		else
			local controlValue: StoryControlValue?

			if controls[controlName] ~= nil then
				controlValue = controls[controlName]
			else
				controlValue = toStoryControlValue(controlSchemaOrValue)
			end

			if controlValue ~= nil then
				hydrated[controlName] = controlValue
			end
		end
	end

	return hydrated
end

return hydrateControls
