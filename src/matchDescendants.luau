local Prospector = require("@pkg/Prospector")

local function hasPermission(instance: Instance)
	local success = pcall(function()
		return instance.Name
	end)
	return success
end

local function matchDescendants(parent: Instance, predicate: (descendant: Instance) -> boolean): { Instance }
	local matches = {}

	if not hasPermission(parent) then
		return matches
	end

	-- Before Prospector we were calling parent:GetDescendants() but because we
	-- need to support the DataModel being passed in that case would allocate a
	-- gigantic array. Prospector will traverse the hierarchy manually, which
	-- takes longer but won't freeze up consumers
	return Prospector.Collect.descendantsDFS(parent, predicate)
end

return matchDescendants
