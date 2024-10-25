local isStorybookModule = require("@root/isStorybookModule")

local function hasPermission(instance: Instance)
	local success = pcall(function()
		return instance.Name
	end)
	return success
end

local function findStorybookModules(parent: Instance)
	local storybooks: { ModuleScript } = {}

	for _, descendant in parent:GetDescendants() do
		if hasPermission(descendant) and isStorybookModule(descendant) then
			-- Luau FIXME: isStorybookModule already narrows to ModuleScript,
			-- but Luau doesn't pick up on it
			table.insert(storybooks, descendant :: ModuleScript)
		end
	end

	return storybooks
end

return findStorybookModules
