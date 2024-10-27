local isStorybookModule = require("@root/isStorybookModule")
local matchDescendants = require("@root/matchDescendants")

local function findStorybookModules(parent: Instance): { ModuleScript }
	local storybooks = matchDescendants(parent, function(descendant)
		return isStorybookModule(descendant)
	end)

	-- Luau FIXME: isStorybookModule already narrows to ModuleScript, but Luau
	-- doesn't pick up on it
	return (storybooks :: any) :: { ModuleScript }
end

return findStorybookModules
