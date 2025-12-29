local Sift = require("@pkg/Sift")

local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type StoryControls = ControlTypes.StoryControls
type StoryControlsSchema = ControlTypes.StoryControlsSchema
type ControlType = ControlType.ControlType

type LegacyStoryControls = {
	[string]: any,
}

local dataTypeToControlType: { [string]: ControlType } = {
	["string"] = ControlType.String,
	["boolean"] = ControlType.Boolean,
	["number"] = ControlType.Number,
}

local function migrateStorytellerV140ControlsSchema(schema: LegacyStoryControls)
	-- Implicitly set the default of an array
	local migratedSchema: StoryControlsSchema = {}

	for key, value in schema do
		local valueType = typeof(value)
		local controlType: ControlType = dataTypeToControlType[valueType]

		if valueType == "table" then
			local mapping = {}

			local options = {}
			for otherKey, otherValue in value do
				if typeof(otherValue) == "string" then
					table.insert(options, otherValue)
					mapping[otherKey] = otherValue
				else
					table.insert(options, tostring(otherValue))
					mapping[otherKey] = otherValue
				end
			end

			local default = options[1]

			migratedSchema[key] = {
				control = controlType,
				options = options,
				mapping = mapping,
				default = default,
			}
		else
			migratedSchema[key] = {
				control = controlType,
				default = value,
			}
		end
	end

	return migratedSchema
end

return migrateStorytellerV140ControlsSchema
