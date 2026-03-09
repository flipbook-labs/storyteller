local React = require("@pkg/React")

local StorytellerStore = require("@root/stores/StorytellerStore").instance

local useEffect = React.useEffect

local function useStorytellerStore()
	useEffect(function()
		task.spawn(function()
			StorytellerStore.init()
		end)
	end, {})

	return StorytellerStore
end

return useStorytellerStore
