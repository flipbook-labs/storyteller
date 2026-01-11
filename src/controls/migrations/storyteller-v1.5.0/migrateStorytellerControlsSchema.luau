local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")
local toStoryControlValue = require("@root/controls/parsing/toStoryControlValue")
local types = require("./types")

type StoryControl = ControlTypes.StoryControl
type StoryControls = ControlTypes.StoryControls
type StoryControlsSchema = ControlTypes.StoryControlsSchema
type ListBasedStoryControl = ControlTypes.ListBasedStoryControl
type StoryControlValue = ControlTypes.StoryControlValue

type ControlType = ControlType.ControlType

type LegacyStoryControl = types.StoryControl
type LegacyStoryControlsSchema = types.StoryControlsSchema

local function migrateStorytellerControlsSchema(schema: LegacyStoryControlsSchema): StoryControlsSchema
	local migratedSchema: StoryControlsSchema = {}

	for key, value in schema do
		-- The only thing we actually have to migrate is how arrays are handled
		if typeof(value) == "table" then
			local items: { StoryControlValue } = {}

			for _, item in value do
				local casted = toStoryControlValue(item)
				if casted then
					table.insert(items, casted)
				end
			end

			local migratedControl: ListBasedStoryControl = {
				type = ControlType.Select,
				items = items,
				default = items[1],
			}

			migratedSchema[key] = migratedControl
		else
			migratedSchema[key] = value
		end
	end

	return migratedSchema
end

return migrateStorytellerControlsSchema
