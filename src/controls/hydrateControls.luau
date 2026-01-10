local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")
local UILabsV242Migration = require("@root/controls/migrations/ui-labs-v2.4.2")
local migrateControlsSchema = require("@root/controls/migrateControlsSchema")
local toStoryControl = require("@root/controls/parsing/toStoryControl")
local toStoryControlValueCompat = require("@root/controls/parsing/toStoryControlValueCompat")
local transformControlValue = require("@root/controls/parsing/transformControlValue")
local validateListControlHasControlValue = require("@root/controls/parsing/validateListControlHasControlValue")

type StoryControlsSchema = ControlTypes.StoryControlsSchema
type StoryControls = ControlTypes.StoryControls
type StoryControl = ControlTypes.StoryControl
type ListBasedControlSchema = ControlTypes.ListBasedStoryControl
type StoryControlValueCompat = ControlTypes.StoryControlValueCompat

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
	schema: StoryControlsSchema | UILabsV242Migration.StoryControlsSchema,
	controls: StoryControls
): StoryControls
	local migratedSchema = migrateControlsSchema(schema)

	ControlTypes.StoryControlsSchema:assert(migratedSchema)

	local hydrated: StoryControls = {}

	for controlName, controlSchemaOrValue in migratedSchema do
		local controlSchema = toStoryControl(controlSchemaOrValue)

		if controlSchema then
			ControlTypes.StoryControl:assert(controlSchema)

			local controlValue: StoryControlValueCompat? = controls[controlName]

			if
				controlSchema.type == ControlType.Check
				or controlSchema.type == ControlType.MultiSelect
				or controlSchema.type == ControlType.Radio
				or controlSchema.type == ControlType.Select
			then
				validateListControlHasControlValue(controlSchema :: ListBasedControlSchema, controlValue)
			end

			local transformed = transformControlValue(controlSchema, controlValue)

			if transformed ~= nil then
				ControlTypes.StoryControlValueCompat:assert(transformed)
				hydrated[controlName] = transformed
			end
		else
			local controlValue: StoryControlValueCompat?

			if controls[controlName] ~= nil then
				controlValue = controls[controlName]
			else
				controlValue = toStoryControlValueCompat(controlSchemaOrValue)
			end

			if controlValue ~= nil then
				hydrated[controlName] = controlValue
			end
		end
	end

	return hydrated
end

return hydrateControls
