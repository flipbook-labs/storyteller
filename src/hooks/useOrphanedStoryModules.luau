local React = require("@pkg/React")

local isOrphanedStoryModule = require("@root/isOrphanedStoryModule")
local usePrevious = require("@root/hooks/usePrevious")
local useQueryDescendants = require("@root/hooks/useQueryDescendants")
local useStorybooks = require("@root/hooks/useStorybooks")

local useEffect = React.useEffect
local useCallback = React.useCallback
local useState = React.useState
local useRef = React.useRef

--[=[
	This hook is used for the discovery of Story modules that are not associated
	with any Storybooks. These are known as "orphaned" or "unknown" stories

	This hook should be used in conjunction with `useStorybooks` so that a list
	of the available storybooks is determined first, otherwise all stories would
	come back as orphans.

	:::info
	In the future version hooks may be migrated to a new package to remove the
	React dependency from Storyteller.
	:::

	Usage:

	```lua
	local React = require("@pkg/React")
	local Storyteller = require("@pkg/Storyteller")

	local e = React.createElement

	local function OrphanList(props: {
		parent: Instance,
	})
		local storybooks = Storyteller.useStorybooks(props.parent)
		local orphanedStoryModules = Storyteller.useOrphanedStoryModules(props.parent, storybooks.available)

		local children = {}
		for index, orphanedStoryModule in orphanedStoryModules do
			children[orphanedStoryModule.Name] = e("TextLabel", {
				Text = orphanedStoryModule.Name,
				LayoutOrder = index,
			}),
		end

		return e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, {
			Layout = e("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder
			}),
		}, children)
	end

	return OrphanList
	```

	@tag React
	@tag Story
	@within Storyteller
]=]
local function useOrphanedStoryModules(parent: Instance): { ModuleScript }
	local orphanedStoryModules, setOrphanedStoryModules = useState({} :: { ModuleScript })
	local storybooks = useStorybooks(parent)
	local prevStorybooks = usePrevious(storybooks)
	local moduleScripts = (useQueryDescendants(parent, "ModuleScript") :: any) :: { ModuleScript }

	local update = useCallback(function()
		local orphans: { ModuleScript } = {}

		for _, moduleScript in moduleScripts do
			if isOrphanedStoryModule(moduleScript, storybooks.available) then
				table.insert(orphans, moduleScript)
			end
		end

		setOrphanedStoryModules(orphans)
	end, { moduleScripts, storybooks } :: { unknown })

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
	end, { moduleScripts, update } :: { unknown })

	useEffect(function()
		if prevStorybooks and storybooks ~= prevStorybooks then
			update()
		end
	end, { storybooks, prevStorybooks, update } :: { unknown })

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
