local React = require("@pkg/React")
local Sift = require("@pkg/Sift")

local StorytellerStore = require("@root/stores/StorytellerStore")

local useEffect = React.useEffect
local useContext = React.useContext

export type StorytellerContext = {
	store: StorytellerStore.StorytellerStore,
}

export type StorytellerProviderProps = {
	store: StorytellerStore.StorytellerStore,
	children: React.ReactNode,
}

local StorytellerContext = React.createContext(nil :: StorytellerContext?)
StorytellerContext.displayName = "StorytellerContext"

local defaultProps = {
	store = StorytellerStore.instance,
}

local function StorytellerProvider(storytellerProviderProps: StorytellerProviderProps)
	local props: StorytellerProviderProps = Sift.Dictionary.join(defaultProps, storytellerProviderProps)

	useEffect(function()
		task.spawn(function()
			props.store.start()
		end)

		return function()
			props.store.stop()
		end
	end, { props.store })

	return React.createElement(StorytellerContext.Provider, {
		value = {
			store = props.store,
		},
	}, props.children)
end

local function useStorytellerContext(): StorytellerContext
	local context = useContext(StorytellerContext)
	if not context then
		local callerName = debug.info(2, "n") or "useStorytellerContext"
		error(`{callerName} can only be used with StorytellerProvider in the tree`)
	end
	return context
end

return {
	StorytellerProvider = StorytellerProvider,
	useStorytellerContext = useStorytellerContext,
}
