local ModuleLoader = require("@pkg/ModuleLoader")
local Sift = require("@pkg/Sift")

local types = require("@root/types")

local Errors = {
	MalformedStory = "Story is malformed. Check the source of %q and make sure its properties are correct",
	Generic = "Failed to load story %q. Error: %s",
}

local function loadStoryModule<T>(
	loader: ModuleLoader.ModuleLoader,
	storyModule: ModuleScript,
	storybook: types.Storybook
): (types.Story<T>?, string?)
	local success, result = pcall(function()
		return loader:require(storyModule)
	end)

	if not success then
		return nil, Errors.Generic:format(storyModule:GetFullName(), tostring(result))
	end

	local story: types.Story<T>
	if typeof(result) == "function" then
		story = {
			name = storyModule.Name,
			story = result,
			storybook = storybook,
			source = storyModule,
		}
	else
		local isValid, message = types.IStory(result)

		if isValid then
			story = Sift.Dictionary.merge({
				name = storyModule.Name,
				storybook = storybook,
				source = storyModule,
			}, result)
		else
			return nil, Errors.Generic:format(storyModule:GetFullName(), message)
		end
	end

	if story then
		return story, nil
	else
		return nil, Errors.MalformedStory:format(storyModule:GetFullName())
	end
end

return loadStoryModule
