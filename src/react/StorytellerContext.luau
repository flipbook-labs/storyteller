local React = require("@pkg/React")
local Sift = require("@pkg/Sift")

local StorytellerStore = require("@root/stores/StorytellerStore")

local useContext = React.useContext
local useEffect = React.useEffect
local useMemo = React.useMemo

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

	local context = useMemo(function(): StorytellerContext
		return {
			store = props.store,
		}
	end, { props.store })

	useEffect(function()
		task.spawn(function()
			props.store.start()
		end)

		return function()
			props.store.stop()
		end
	end, { props.store })

	return React.createElement(StorytellerContext.Provider, {
		value = context,
	}, props.children)
end

local function useStorytellerContext(): StorytellerContext
	return useContext(StorytellerContext)
end

return {
	StorytellerProvider = StorytellerProvider,
	useStorytellerContext = useStorytellerContext,
}
