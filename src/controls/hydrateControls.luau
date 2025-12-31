local t = require("@pkg/t")

local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")
local StorytellerV140Migration = require("@root/controls/migrations/storyteller-v1.4.0")
local UILabsV242Migration = require("@root/controls/migrations/ui-labs-v2.4.2")
local migrateControlsSchema = require("@root/controls/migrateControlsSchema")
local transformControlValue = require("@root/controls/parsing/transformControlValue")
local validateControlSchema = require("@root/controls/parsing/validateControlSchema")
local validateListControlValue = require("@root/controls/parsing/validateListControlValue")

type StoryControlsSchema = ControlTypes.StoryControlsSchema
type StoryControls = ControlTypes.StoryControls

local IStoryControl = t.interface({
	control = t.string,
	default = t.optional(t.any),
})

local IStoryControlsSchema = t.map(t.string, IStoryControl)

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
	if not IStoryControlsSchema(schema) then
		local migratedSchema = migrateControlsSchema(schema)

		local success, message = IStoryControlsSchema(migratedSchema)

		if migratedSchema and success then
			schema = migratedSchema
		else
			error(
				`failed to parse controls schema (schema doesn't match a known format and couldn't be migrated)\nerr: {message}`
			)
		end
	end

	local hydrated: StoryControls = {}

	for controlName, controlSchema in schema do
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
