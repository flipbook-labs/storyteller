local isStorybookModule = require("@root/isStorybookModule")

--[=[
	Discovers all Storybook modules that are descendants of `parent`.

	This is the first step in the discovery of Stories. Once you load a
	Storybook, you can then use its `storyRoots` array to discover all the
	Stories it manages.

	@within Storyteller
	@tag Storybook
	@tag Discovery
]=]
local function findStorybookModules(parent: Instance): { ModuleScript }
	local candidates = (parent:QueryDescendants("ModuleScript") :: any) :: { ModuleScript }
	local storybookModules: { ModuleScript } = {}

	for _, candidate in candidates do
		if isStorybookModule(candidate) then
			table.insert(storybookModules, candidate)
		end
	end

	return storybookModules
end

return findStorybookModules
