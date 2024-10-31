local ModuleLoader = require("@pkg/ModuleLoader")

local constants = require("@root/constants")
local types = require("@root/types")

local function loadStorybookModule(loader: ModuleLoader.ModuleLoader, module: ModuleScript): types.Storybook
	local wasRequired, result = pcall(function()
		return loader:require(module)
	end)

	assert(wasRequired, `failed to load storybook`)

	local isStorybook, message = types.IStorybook(result)

	assert(isStorybook, `failed to load storybook {module:GetFullName()}: {message}`)

	if not result.name then
		result.name = module.Name:gsub(constants.STORYBOOK_NAME_PATTERN, "")
	end

	return result
end

return loadStorybookModule
