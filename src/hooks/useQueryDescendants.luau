local React = require("@pkg/React")

local usePrevious = require("@root/hooks/usePrevious")

local useEffect = React.useEffect
local useCallback = React.useCallback
local useState = React.useState

local function useQueryDescendants(parent: Instance, selector: string): { Instance }
	local descendants, setDescendants = useState({} :: { Instance })
	local prevParent: Instance? = usePrevious(parent)

	local update = useCallback(function()
		setDescendants(parent:QueryDescendants(selector))
	end, { parent })

	useEffect(function()
		if parent ~= prevParent then
			update()
		end
	end, { parent, prevParent, update } :: { unknown })

	useEffect(function()
		local connections = {}

		-- This might wind up being expensive when `parent` is the whole
		-- DataModel. If that winds up being the case this should be adjusted so
		-- that new descendants are added to a queue and processed over several
		-- frames
		table.insert(connections, parent.DescendantAdded:Connect(update))

		for _, instance in descendants do
			table.insert(connections, instance.AncestryChanged:Connect(update))
		end

		return function()
			for _, conn in connections do
				conn:Disconnect()
			end
		end
	end, { parent, prevParent, descendants, update } :: { unknown })

	return descendants
end

return useQueryDescendants
