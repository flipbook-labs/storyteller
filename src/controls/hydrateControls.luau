local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")
local StorytellerV140Migration = require("@root/controls/migrations/storyteller-v1.4.0")
local UILabsV242Migration = require("@root/controls/migrations/ui-labs-v2.4.2")
local migrateControlsSchema = require("@root/controls/migrateControlsSchema")
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

local function hydrateControls(
	schema: StoryControlsSchema | StorytellerV140Migration.StoryControlsSchema | UILabsV242Migration.StoryControlsSchema,
	controls: StoryControls
): StoryControls
	if not ControlTypes.StoryControlsSchema(schema) then
		local migratedSchema = migrateControlsSchema(schema)
		local success, message = ControlTypes.StoryControlsSchema(migratedSchema)

		if migratedSchema and success then
			schema = migratedSchema
		else
			error(
				`failed to parse controls schema (schema doesn't match a known format and couldn't be migrated)\nerr: {message}`
			)
		end
	end

	local hydrated: StoryControls = {}

	for controlName, controlSchemaOrValue in schema do
		local controlSchema = toStoryControl(controlSchemaOrValue)

		if controlSchema then
			local controlValue: StoryControlValue? = controls[controlName]

			validateControlSchema(controlName, controlSchema)

			if
				controlSchema.type == ControlType.Check
				or controlSchema.type == ControlType.MultiSelect
				or controlSchema.type == ControlType.Radio
				or controlSchema.type == ControlType.Select
			then
				validateListControlValue(controlName, controlSchema, controlValue)
			end

			local transformed = transformControlValue(controlSchema, controlValue)

			if transformed ~= nil then
				hydrated[controlName] = transformed
			end
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
