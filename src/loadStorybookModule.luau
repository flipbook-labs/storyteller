local ModuleLoader = require("@pkg/ModuleLoader")

local constants = require("@root/constants")
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
	local loader = if providedLoader then providedLoader else ModuleLoader.new()

	local result
	local wasRequired, err = pcall(function()
		result = loader:require(module)
	end)

	assert(wasRequired, `failed to load storybook {module:GetFullName()}: {err}`)

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

	if result.packages and getmetatable(result.packages) == nil then
		-- Loaded storybooks get stored in Charm state, which deep-freezes
		-- everything it can reach in Studio, but skips tables that have a
		-- metatable. UI libraries mutate their module-level state while
		-- rendering (React reassigns ReactCurrentDispatcher.current on every
		-- render), so freezing has to stop at this foreign-module boundary
		-- (flipbook-labs/storyteller#100).
		--
		-- The clone matters: when the storybook declares `packages` directly,
		-- the table belongs to the author's module and may be shared between
		-- storybooks or frozen, so we must not attach a metatable in place
		result.packages = setmetatable(table.clone(result.packages), {})
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

	return result
end

return loadStorybookModule
