local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")
local types = require("./types")

type Mapping<T> = ControlTypes.Mapping<T>
type StoryControl = ControlTypes.StoryControl
type StoryControls = ControlTypes.StoryControls
type StoryControlsSchema = ControlTypes.StoryControlsSchema
type ListBasedStoryControl<T> = ControlTypes.ListBasedStoryControl<T>
type StoryControlValue = ControlTypes.StoryControlValue

type ControlType = ControlType.ControlType

type LegacyStoryControl = types.StoryControl
type LegacyStoryControlsSchema = types.StoryControlsSchema

local dataTypeToControlType: { [string]: ControlType } = {
	["string"] = ControlType.String,
	["boolean"] = ControlType.Boolean,
	["number"] = ControlType.Number,
}

local function migrateStorytellerControlsSchema(schema: LegacyStoryControlsSchema): StoryControlsSchema
	local migratedSchema: StoryControlsSchema = {}

	for key, value in schema do
		if typeof(value) == "table" then
			local mapping = {}

			local options = {}
			for _, otherValue in value do
				if typeof(otherValue) == "string" then
					table.insert(options, otherValue)
				else
					table.insert(options, tostring(otherValue))
					mapping[tostring(otherValue)] = otherValue
				end
			end

			local default = options[1]

			local migratedControl: ListBasedStoryControl<unknown> = {
				control = ControlType.Select,
				options = options,
				mapping = mapping,
				default = default,
			}

			migratedSchema[key] = migratedControl
		else
			local controlType: ControlType = dataTypeToControlType[typeof(value)]

			local migratedControl: StoryControl = {
				control = controlType,
				default = value,
			}

			migratedSchema[key] = migratedControl
		end
	end

	return migratedSchema
end

return migrateStorytellerControlsSchema
