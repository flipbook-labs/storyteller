local Sift = require("@pkg/Sift")

local findStoryModules = require("@root/findStoryModules")
local types = require("@root/types")

--[=[
	Discovers all Story modules that are managed by the given Storybook.

	@tag Storybook
	@tag Story
	@tag Discovery
	@within Storyteller
	@since 0.1.0
]=]
local function findStoryModulesForStorybook(storybook: types.LoadedStorybook): { ModuleScript }
	local storyModules = {}
	for _, root in storybook.storyRoots do
		storyModules = Sift.List.join(storyModules, findStoryModules(root))
	end
	return storyModules
end

return findStoryModulesForStorybook
