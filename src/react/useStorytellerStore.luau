local React = require("@pkg/React")

local useStorytellerContext = require("@root/react/useStorytellerContext")

local useEffect = React.useEffect

local function useStorytellerStore()
	local storytellerContext = useStorytellerContext()
	local store = storytellerContext.store

	useEffect(function()
		task.spawn(function()
			store.start()
		end)
	end, { store })

	return store
end

return useStorytellerStore
