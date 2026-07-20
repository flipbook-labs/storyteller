local React = require("@pkg/React")

local StorytellerStore = require("@root/stores/StorytellerStore")

local useContext = React.useContext
local useEffect = React.useEffect
local useMemo = React.useMemo

export type StorytellerContext = {
	store: StorytellerStore.StorytellerStore,
}

export type StorytellerProviderProps = {
	store: StorytellerStore.StorytellerStore?,
	children: React.ReactNode,
}

-- The default is nil instead of a context holding the shared store: calling
-- StorytellerStore.get() here would create the store whenever this module is
-- required. useStorytellerContext falls back to the shared store at hook time.
local StorytellerContext = React.createContext(nil :: StorytellerContext?)
StorytellerContext.displayName = "StorytellerContext"

local function StorytellerProvider(storytellerProviderProps: StorytellerProviderProps)
	local store = storytellerProviderProps.store or StorytellerStore.get()

	local context = useMemo(function(): StorytellerContext
		return {
			store = store,
		}
	end, { store })

	useEffect(function()
		task.spawn(function()
			store.start()
		end)

		return function()
			store.stop()
		end
	end, { store })

	return React.createElement(StorytellerContext.Provider, {
		value = context,
	}, storytellerProviderProps.children)
end

local function useStorytellerContext(): StorytellerContext
	local context = useContext(StorytellerContext)
	if context then
		return context
	end
	return {
		store = StorytellerStore.get(),
	}
end

return {
	StorytellerProvider = StorytellerProvider,
	useStorytellerContext = useStorytellerContext,
}
