local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")
local types = require("./types")

type StoryControl = ControlTypes.StoryControl
type StoryControls = ControlTypes.StoryControls
type StoryControlsSchema = ControlTypes.StoryControlsSchema
type ListBasedStoryControl = ControlTypes.ListBasedStoryControl
type StoryControlValue = ControlTypes.StoryControlValue
type SimpleControlOptions = ControlTypes.SimpleControlOptions
type MappedControlOptions = ControlTypes.MappedControlOptions

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
			--[[
                Simplest approach is to just turn any Storyteller v1.5.0 options
                into MappedControlOptions. This is a bit excessive for an
                options array of only primitive data types since it would
                convert something like

                ```luau
                controls = {
                    foo = { "Hello",  "Goodbye" }
                }
                ```

                Into...

                ```luau
				controls = {
				    foo = {
				        ["Hello"] = "Hello",
				        ["Goodbye"] = "Goodbye"
				    }
				}
				```

				But this makes life easier later when hydrating the scheme since
                we always have some string mapping to any of our data types,
                which is especially handy for non-primitives like EnumItems.
			]]
			local options: MappedControlOptions = {}
			for _, option in value do
				if typeof(option) ~= "table" then
					options[tostring(option)] = option
				end
			end

			local default = options[tostring(value[1])]

			local migratedControl: ListBasedStoryControl = {
				type = ControlType.Select,
				options = options,
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
