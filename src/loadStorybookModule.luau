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

	local wasRequired, result = pcall(function()
		return loader:require(module)
	end)

	assert(wasRequired, `failed to load storybook {module:GetFullName()}: {result}`)

	-- Interop with some older storybooks. Ideally this shouldn't be merged
	if not result.storyRoots and result.storyRoot then
		-- Some storybooks use `storyRoot: Instance` instead of a
		-- `storyRoots` array.
		result.storyRoots = { result.storyRoot }
		result.storyRoot = nil
	end

	local isStorybook, message = types.IStorybook(result)

	assert(isStorybook, `failed to load storybook {module:GetFullName()}:\n{message}`)

	if not result.packages then
		result.packages = migrateLegacyPackages(result)
	end

	if not result.name then
		local name = module.Name:gsub(constants.STORYBOOK_NAME_PATTERN, "")
		if name == "" then
			result.name = "Unnamed Storybook"
		else
			result.name = name
		end
	end

	if result.group then
		result.name = `{result.group} / {result.name}`
	end

	result.source = module
	result.loader = loader

	return result
end

return loadStorybookModule
