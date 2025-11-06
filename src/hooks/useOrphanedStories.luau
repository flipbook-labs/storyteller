local React = require("@pkg/React")

local findOrphanedStoryModules = require("@root/findOrphanedStoryModules")
local isStoryModule = require("@root/isStoryModule")
local isStorybookModule = require("@root/isStorybookModule")
local useStorybooks = require("@root/hooks/useStorybooks")

local useEffect = React.useEffect
local useMemo = React.useMemo
local useCallback = React.useCallback
local useState = React.useState
local useRef = React.useRef

local function useOrphanedStories(parent: Instance): { ModuleScript }
	local orphanedStories, setOrphanedStories = useState({} :: { ModuleScript })

	local storybooks = useStorybooks(parent)

	local update = useCallback(function()
		-- We make sure to only look for orphans after all storybooks (available
		-- and unavailable) have been searched for, otherwise on the first
		-- render we could return stories that do in fact have a storybook
		-- associated with them
		if storybooks.isLoading then
			setOrphanedStories({})
		else
			setOrphanedStories(findOrphanedStoryModules(parent, storybooks.available))
		end
	end, { parent, storybooks.isLoading, storybooks.available } :: { unknown })

	useEffect(function()
		local conn = parent.DescendantAdded:Connect(function(instance)
			if isStoryModule(instance) or isStorybookModule(instance) then
				print("NEW STORY OR STORYBOOK ADDED", instance)
				update()
			end
		end)

		return function()
			conn:Disconnect()
		end
	end, { parent, update } :: { unknown })

	useEffect(function()
		local connections = {}

		for _, orphan in orphanedStories do
			table.insert(connections, orphan.AncestryChanged:Connect(update))
		end

		return function()
			for _, conn in connections do
				conn:Disconnect()
			end
		end
	end, { orphanedStories, update } :: { unknown })

	local didInitialSearch = useRef(false)
	useEffect(function()
		if not (storybooks.isLoading or didInitialSearch.current) then
			update()
			didInitialSearch.current = true
		end
	end, { storybooks.isLoading, update } :: { unknown })

	return orphanedStories
end

return useOrphanedStories
