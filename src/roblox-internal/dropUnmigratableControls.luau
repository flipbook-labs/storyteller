local migrateControlsSchema = require("@root/controls/migrateControlsSchema")
local types = require("@root/types")

type StoryControls = types.StoryControls
type StoryControlsSchema = types.StoryControlsSchema

--[[
	Developer Storybook passes any control value through to the story, so
	storybooks written for it use values Storyteller can't migrate, such as a
	list of enum values or a dictionary of settings. Migrating each control on
	its own keeps the rest of the controls and the story usable.

	Each control that can't be migrated is dropped from the schema with a
	warning. The second return value holds the value Developer Storybook gives
	each of them, the first item of a list, so the story still renders as it
	did there. The third holds each dropped control as the story declared it,
	so a host can say which controls it can't offer.
]]
local function dropUnmigratableControls(
	schema: { [string]: unknown },
	storyModule: ModuleScript
): (StoryControlsSchema, StoryControls, { [string]: unknown })
	local migrated: StoryControlsSchema = {}
	local fixedValues: { [string]: any } = {}
	local dropped: { [string]: unknown } = {}

	for key, value in schema do
		local singleControlSchema: any = {
			[key] = value,
		}
		local wasMigrated, result = pcall(migrateControlsSchema, singleControlSchema)
		if wasMigrated then
			migrated[key] = result[key]
		else
			fixedValues[key] = if typeof(value) == "table" then (value :: { unknown })[1] else value
			dropped[key] = value
			warn(`Dropped the "{key}" control from {storyModule:GetFullName()} because it can't be migrated: {result}`)
		end
	end

	return migrated, fixedValues, dropped
end

return dropUnmigratableControls
