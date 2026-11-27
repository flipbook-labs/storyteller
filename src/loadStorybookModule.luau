local ModuleLoader = require("@pkg/ModuleLoader")

local constants = require("@root/constants")
local describeLoadError = require("@root/describeLoadError")
local excludeFromCharmFreeze = require("@root/stores/excludeFromCharmFreeze")
local migrateLegacyPackages = require("@root/migrateLegacyPackages")
local types = require("@root/types")

type LoadedStorybook = types.LoadedStorybook
type ModuleLoader = ModuleLoader.ModuleLoader

--[=[
	Loads the source of a Storybook module.

	A [ModuleLoader](https://github.com/flipbook-labs/module-loader) instance
	is required for handling the requiring of the module.

	This function will throw if the return value of `storybookModule` does not
	conform to [Storybook format](/docs/story-format#storybook), or if the
	source has a syntax error that `require` would normally fail for.

	@tag Storybook
	@tag Module Loading
	@within Storyteller
]=]
local function loadStorybookModule(module: ModuleScript, providedLoader: ModuleLoader?): LoadedStorybook
	local loader = if providedLoader then providedLoader else ModuleLoader.createModuleLoader()

	local result: { [string]: unknown }
	local wasRequired, err = pcall(function()
		result = loader.require(module) :: { [string]: unknown }
	end)

	if not wasRequired then
		error(`failed to load storybook {module:GetFullName()}: {describeLoadError(loader, err)}`, 0)
	end

	-- The loader caches this table, and a story loaded with the same loader can
	-- require the storybook module too. The edits below go on a copy so that
	-- story still gets the table its author wrote.
	if typeof(result) == "table" then
		result = table.clone(result)
	end

	do -- Roblox internal. This behavior may be removed without notice.
		if not result.storyRoots and result.storyRoot then
			-- Some storybooks use `storyRoot: Instance` instead of a
			-- `storyRoots` array.
			result.storyRoots = { result.storyRoot }
			result.storyRoot = nil
		end
	end

	local isStorybook, message = types.IStorybook(result)

	assert(isStorybook, `failed to load storybook {module:GetFullName()}: {message}`)

	if not result.packages then
		result.packages = migrateLegacyPackages(result)
	end

	-- The legacy fields point at the same library tables as `packages`, but
	-- nothing stops Charm's freeze on that path. They're dropped once migrated
	-- so the library is reachable only through `packages`.
	for _, field in constants.LEGACY_PACKAGE_FIELDS do
		result[field] = nil
	end

	local packages = result.packages :: { [unknown]: unknown }?
	if packages then
		--[[
			Loaded storybooks get stored in Charm state, which deep-freezes
			everything it can reach in Studio, but skips tables that have a
			metatable. UI libraries mutate their module-level state while
			rendering (React reassigns ReactCurrentDispatcher.current on every
			render), so freezing has to stop at this foreign-module boundary
			(flipbook-labs/storyteller#100).

			The clone matters: when the storybook declares `packages` directly,
			the table belongs to the author's module and may be shared between
			storybooks or frozen, so we must not attach a metatable in place
		]]
		local clone = table.clone(packages)
		excludeFromCharmFreeze(clone)
		result.packages = clone
	end

	if not result.name then
		local name = module.Name:gsub(constants.STORYBOOK_NAME_PATTERN, "")
		if name == "" then
			result.name = "Unnamed Storybook"
		else
			result.name = name
		end
	end

	do -- Roblox internal. This behavior may be removed without notice.
		if result.group then
			result.name = `{result.group} / {result.name}`
		end
	end

	result.source = module

	-- IStorybook checked the shape above.
	return (result :: unknown) :: LoadedStorybook
end

return loadStorybookModule
