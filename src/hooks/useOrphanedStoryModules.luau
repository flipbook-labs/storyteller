local React = require("@pkg/React")

local isOrphanedStoryModule = require("@root/isOrphanedStoryModule")
local useQueryDescendants = require("@root/hooks/useQueryDescendants")
local useStorybooks = require("@root/hooks/useStorybooks")

local useEffect = React.useEffect
local useCallback = React.useCallback
local useState = React.useState
local useRef = React.useRef

local function useOrphanedStoryModules(parent: Instance): { ModuleScript }
	local orphanedStoryModules, setOrphanedStoryModules = useState({} :: { ModuleScript })
	local storybooks = useStorybooks(parent)
	local moduleScripts = (useQueryDescendants(parent, "ModuleScript") :: any) :: { ModuleScript }

	local update = useCallback(function()
		local orphans: { ModuleScript } = {}

		for _, moduleScript in moduleScripts do
			if isOrphanedStoryModule(moduleScript, storybooks.available) then
				table.insert(orphans, moduleScript)
			end
		end

		setOrphanedStoryModules(orphans)
	end, { moduleScripts } :: { unknown })

	useEffect(function()
		local connections = {}

		-- Any ModuleScript can be renamed to become a Story, so we need to
		-- watch property changes on all of them
		for _, moduleScript in moduleScripts do
			table.insert(connections, moduleScript:GetPropertyChangedSignal("Name"):Connect(update))
		end

		return function()
			for _, conn in connections do
				conn:Disconnect()
			end
		end
	end, { moduleScripts })

	local didInitialSearch = useRef(false)
	useEffect(function()
		if not (storybooks.isLoading or didInitialSearch.current) then
			update()
			didInitialSearch.current = true
		end
	end, { storybooks.isLoading, update } :: { unknown })

	return orphanedStoryModules
end

return useOrphanedStoryModules
