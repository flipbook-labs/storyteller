local React = require("@pkg/React")

local StorytellerContext = require("./StorytellerContext")
type StorytellerContext = StorytellerContext.StorytellerContext

local useContext = React.useContext

local function useStorytellerContext(): StorytellerContext
	local context = useContext(StorytellerContext)
	if not context then
		local callerName = debug.info(2, "n") or "useStorytellerContext"
		error(`{callerName} can only be used with StorytellerProvider in the tree`)
	end
	return context
end

return useStorytellerContext
