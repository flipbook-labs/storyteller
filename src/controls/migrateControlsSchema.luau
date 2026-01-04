local ControlTypes = require("@root/controls/ControlTypes")
local StorytellerV140Migration = require("@root/controls/migrations/storyteller-v1.4.0")
local UILabsV242Migration = require("@root/controls/migrations/ui-labs-v2.4.2")

type StoryControls = ControlTypes.StoryControls
type StoryControlsSchema = ControlTypes.StoryControlsSchema
type AnySchema = {
	[any]: any,
}

type Migration = {
	matcher: (schema: AnySchema) -> (boolean, string?),
	migrator: (schema: AnySchema) -> StoryControlsSchema,
}

-- Migrations happen in order from top to bottom and only the first match will
-- be applied to a schema
local migrations: { Migration } = {
	{
		matcher = UILabsV242Migration.isUILabsControlsSchema,
		migrator = UILabsV242Migration.migrateUILabsControlsSchema,
	},
	{
		matcher = StorytellerV140Migration.isStorytellerControlsSchema,
		migrator = StorytellerV140Migration.migrateStorytellerControlsSchema,
	},
}

local function applyMigration(schema: { [any]: any }): StoryControlsSchema?
	for _, migration in migrations do
		if migration.matcher(schema) then
			return migration.migrator(schema)
		end
	end
	return nil
end

local function migrateControlsSchema(
	schema: StoryControlsSchema | UILabsV242Migration.StoryControlsSchema | StorytellerV140Migration.StoryControlsSchema
): StoryControlsSchema
	if ControlTypes.StoryControlsSchema(schema) then
		return schema :: StoryControlsSchema
	end

	local migratedSchema = applyMigration(schema)
	local success, message = ControlTypes.StoryControlsSchema(migratedSchema)

	if migratedSchema and success then
		return migratedSchema
	else
		error(
			`failed to parse controls schema (schema doesn't match a known format and couldn't be migrated)\nerr: {message}`
		)
	end
end

return migrateControlsSchema
