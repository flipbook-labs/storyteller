# Migrations

This folder contains small packages for migrating from older versions of
Storyteller's controls schema to the latest. We also include migrations for UI
Labs' controls schema.

To include a new migration:

1. Create a new folder named after the package to migrate, along with its
   version (i.e. `storyteller-v1.4.0`)
2. Inside, create an `init.luau` file which will export two members:
   `isStorytellerControlsSchema` and `migrateStorytellerControlsSchema` where
   `Storyteller` is replaced with the name of the package.
3. Thoroughly test the migration
4. With those members defined and implemented, hook them up in
   `hydrateControls.luau` to have the schema migrated
