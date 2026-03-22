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

local defaultValue: StorytellerContext = {
	store = StorytellerStore.instance,
}

local StorytellerContext = React.createContext(defaultValue)
StorytellerContext.displayName = "StorytellerContext"

local defaultProps = {
	store = defaultValue.store,
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
	return useContext(StorytellerContext)
end

return {
	StorytellerProvider = StorytellerProvider,
	useStorytellerContext = useStorytellerContext,
}
