local gt = require("@pkg/GreenTea")

local ControlTypes = require("@root/controls/ControlTypes")
local StorytellerV140Migration = require("@root/controls/migrations/storyteller-v1.5.0")
local UILabsV242Migration = require("@root/controls/migrations/ui-labs-v2.4.2")

type StoryControls = ControlTypes.StoryControls
type StoryControlsSchema = ControlTypes.StoryControlsSchema
type UILabsControlsSchema = UILabsV242Migration.StoryControlsSchema
type StorytellerV140ControlsSchema = StorytellerV140Migration.StoryControlsSchema

type Migration = {
	matcher: (schema: unknown) -> (boolean, gt.Cause?),
	migrator: (schema: unknown) -> StoryControlsSchema,
}

-- Migrations happen in order from top to bottom and only the first match will
-- be applied to a schema. A migrator only runs on a schema its matcher
-- accepted, so each one casts the schema to the format its matcher checks for.
local migrations: { Migration } = {
	{
		matcher = UILabsV242Migration.isUILabsControlsSchema,
		migrator = function(schema)
			return UILabsV242Migration.migrateUILabsControlsSchema(schema :: UILabsControlsSchema)
		end,
	},
	{
		matcher = StorytellerV140Migration.isStorytellerControlsSchema,
		migrator = function(schema)
			return StorytellerV140Migration.migrateStorytellerControlsSchema(schema :: StorytellerV140ControlsSchema)
		end,
	},
}

local function applyMigration(schema: unknown): StoryControlsSchema?
	for _, migration in migrations do
		if migration.matcher(schema) then
			return migration.migrator(schema)
		end
	end
	return nil
end

local function migrateControlsSchema(
	schema: StoryControlsSchema | UILabsControlsSchema | StorytellerV140ControlsSchema
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
