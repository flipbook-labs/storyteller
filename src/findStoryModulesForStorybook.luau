local Sift = require("@pkg/Sift")

local isStoryModule = require("@root/isStoryModule")
local matchDescendants = require("@root/matchDescendants")
local types = require("@root/types")

local function findStoryModulesForStorybook(storybook: types.Storybook): { ModuleScript }
	local storyModules = {}
	for _, root in storybook.storyRoots do
		storyModules = Sift.List.join(
			storyModules,
			matchDescendants(root, function(descendant)
				return isStoryModule(descendant)
			end)
		)
	end
	return storyModules
end

return findStoryModulesForStorybook
