local React = require("@pkg/React")

local StorytellerContext = require("@root/react/StorytellerContext")
local acquireStorytellerStore = require("@root/stores/acquireStorytellerStore")

local useStorytellerContext = StorytellerContext.useStorytellerContext

local useEffect = React.useEffect

local function useStorytellerStore()
	local storytellerContext = useStorytellerContext()
	local store = storytellerContext.store

	useEffect(function()
		return acquireStorytellerStore(store)
	end, { store })

	return store
end

return useStorytellerStore
