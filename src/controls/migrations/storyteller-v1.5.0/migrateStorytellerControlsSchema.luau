local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")
local types = require("./types")

type StoryControl = ControlTypes.StoryControl
type StoryControls = ControlTypes.StoryControls
type StoryControlsSchema = ControlTypes.StoryControlsSchema
type ListBasedStoryControl = ControlTypes.ListBasedStoryControl
type StoryControlValue = ControlTypes.StoryControlValue
type ControlOptions = ControlTypes.ControlOptions

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
			local mapping: { [string]: StoryControlValue } = {}
			local options: ControlOptions = {}

			for _, option in value do
				if typeof(option) ~= "table" then
					mapping[tostring(option)] = option
				end

				table.insert(options, tostring(option))
			end

			local default = tostring(value[1])

			local migratedControl: ListBasedStoryControl = {
				type = ControlType.Select,
				options = options,
				mapping = mapping,
				default = default,
			}

			migratedSchema[key] = migratedControl
		else
			local controlType: ControlType = dataTypeToControlType[typeof(value)]

			local migratedControl: StoryControl = {
				type = controlType,
				default = value,
			}

			migratedSchema[key] = migratedControl
		end
	end

	return migratedSchema
end

return migrateStorytellerControlsSchema
