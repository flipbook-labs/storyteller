local migrateControlsSchema = require("@root/controls/migrateControlsSchema")
local types = require("@root/types")

type StoryControlsSchema = types.StoryControlsSchema

--[[
	Developer Storybook passes any control value through to the story, so
	storybooks written for it use values Storyteller can't migrate, such as a
	dictionary of settings. Migrating each control on its own keeps the rest of
	the controls and the story usable, with a warning for each one dropped.
]]
local function dropUnmigratableControls(schema: { [string]: unknown }, storyModule: ModuleScript): StoryControlsSchema
	local migrated: StoryControlsSchema = {}

	for key, value in schema do
		local singleControlSchema: any = {
			[key] = value,
		}
		local wasMigrated, result = pcall(migrateControlsSchema, singleControlSchema)
		if wasMigrated then
			migrated[key] = result[key]
		else
			warn(`Dropped the "{key}" control from {storyModule:GetFullName()} because it can't be migrated: {result}`)
		end
	end

	return migrated
end

return dropUnmigratableControls
