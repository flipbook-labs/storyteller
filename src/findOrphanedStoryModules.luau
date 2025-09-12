local Sift = require("@pkg/Sift")

local isStoryModule = require("@root/isStoryModule")
local matchDescendants = require("@root/matchDescendants")
local types = require("@root/types")

--[=[
	Discovers all Story modules that don't have a Storybook targetting them with its `storyRoots`.

	@tag Storybook
	@tag Story
	@tag Discovery
	@within Storyteller
	@since 0.1.0
]=]
local function findOrphanedStoryModules(parent: Instance, storybooks: { types.LoadedStorybook }): { ModuleScript }
	local storyModules = matchDescendants(parent, isStoryModule)

	local storyRoots = Sift.Array.reduce(storybooks, function(accumulated: { Instance }, storybook)
		return Sift.Array.join(accumulated, storybook.storyRoots)
	end, {})

	local orphans: { ModuleScript } = {}

	for _, storyModule in storyModules do
		local isOrphaned = true

		for _, storyRoot in storyRoots do
			if storyRoot:IsAncestorOf(storyModule) then
				isOrphaned = false
				break
			end
		end

		if isOrphaned then
			table.insert(orphans, storyModule :: ModuleScript)
		end
	end

	return orphans
end

return findOrphanedStoryModules
