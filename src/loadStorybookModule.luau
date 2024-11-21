local ModuleLoader = require("@pkg/ModuleLoader")

local constants = require("@root/constants")
local migrateLegacyPackages = require("@root/migrateLegacyPackages")
local types = require("@root/types")

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
local function loadStorybookModule(loader: ModuleLoader.ModuleLoader, module: ModuleScript): types.LoadedStorybook
	local wasRequired, result = pcall(function()
		return loader:require(module)
	end)

	assert(wasRequired, `failed to load storybook:\n{result}`)

	local isStorybook, message = types.IStorybook(result)

	assert(isStorybook, `failed to load storybook {module:GetFullName()}:\n{message}`)

	if not result.packages then
		result.packages = migrateLegacyPackages(result)
	end

	if not result.name then
		result.name = module.Name:gsub(constants.STORYBOOK_NAME_PATTERN, "")
	end

	-- selene: allow(global_usage)
	if _G.ROBLOX_INTERNAL then
		if result.group then
			result.name = `{result.group} / {result.name}`
		end
	end

	return result
end

return loadStorybookModule
