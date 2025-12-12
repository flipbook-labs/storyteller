local isStoryModule = require("@root/isStoryModule")

--[=[
	Discovers all Story modules that are descendants of `parent`.

	@within Storyteller
	@tag Story
	@tag Discovery
]=]
local function findStoryModules(parent: Instance): { ModuleScript }
	local candidates = (parent:QueryDescendants("ModuleScript") :: any) :: { ModuleScript }
	local storyModules: { ModuleScript } = {}

	for _, candidate in candidates do
		if isStoryModule(candidate) then
			table.insert(storyModules, candidate)
		end
	end

	return storyModules
end

return findStoryModules
