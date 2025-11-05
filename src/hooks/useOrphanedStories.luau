local React = require("@pkg/React")

local findOrphanedStoryModules = require("@root/findOrphanedStoryModules")
local useStorybooks = require("@root/hooks/useStorybooks")

local useMemo = React.useMemo

local function useOrphanedStories(parent: Instance): { ModuleScript }
	local storybooks = useStorybooks(parent)

	return useMemo(function()
		-- We make sure to only look for orphans after all storybooks (available
		-- and unavailable) have been searched for, otherwise on the first
		-- render we could return stories that do in fact have a storybook
		-- associated with them
		if storybooks.isLoading then
			return {}
		end

		return findOrphanedStoryModules(parent, storybooks.available)
	end, { storybooks.isLoading, storybooks.available } :: { unknown })
end

return useOrphanedStories
