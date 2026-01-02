local ControlTypes = require("@root/controls/ControlTypes")
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
}

local function migrateControlsSchema(schema: { [any]: any }): StoryControlsSchema?
	for _, migration in migrations do
		if migration.matcher(schema) then
			return migration.migrator(schema)
		end
	end
	return nil
end

return migrateControlsSchema
