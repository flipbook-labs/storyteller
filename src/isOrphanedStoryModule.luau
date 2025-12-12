local Sift = require("@pkg/Sift")

local isStoryModule = require("@root/isStoryModule")
local types = require("@root/types")

local function isOrphanedStoryModule(instance: Instance, storybooks: { types.LoadedStorybook }): boolean
	if not isStoryModule(instance) then
		return false
	end

	local storyRoots = Sift.Array.reduce(storybooks, function(accumulated: { Instance }, storybook)
		return Sift.Array.join(accumulated, storybook.storyRoots)
	end, {})

	for _, storyRoot in storyRoots do
		if storyRoot:IsAncestorOf(instance) then
			return false
		end
	end
	return true
end

return isOrphanedStoryModule
