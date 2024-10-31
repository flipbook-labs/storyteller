local ModuleLoader = require("@pkg/ModuleLoader")
local Sift = require("@pkg/Sift")

local constants = require("@root/constants")
local types = require("@root/types")

type Storybook = types.Storybook
type Story<T> = types.Story<T>

local function loadStoryModule<T>(
	loader: ModuleLoader.ModuleLoader,
	storyModule: ModuleScript,
	storybook: Storybook
): Story<T>
	local success, result = pcall(function()
		return loader:require(storyModule)
	end)

	if not success then
		error(`Failed to load story {storyModule:GetFullName()}. Error: {result})`)
	end

	-- Support for Hoarcekat stories
	if typeof(result) == "function" then
		local callback = result
		result = {
			story = function(props)
				return callback(props.container, props)
			end,
		}
	end

	local isValid, message = types.IStory(result)

	if not isValid then
		error(
			`Story is malformed. Check the source of {storyModule:GetFullName()} and make sure its properties are `
				.. `correct. Error: {message}`
		)
	end

	return Sift.Dictionary.merge({
		name = storyModule.Name:gsub(constants.STORY_NAME_PATTERN, ""),
		storybook = storybook,
		source = storyModule,
	}, result)
end

return loadStoryModule
