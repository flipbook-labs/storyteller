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

-- The context must not touch StorytellerStore.instance at module scope:
-- requiring this module happens transitively inside ModuleLoader sandboxes,
-- and eagerly resolving the shared instance would construct a game-wide store
-- per sandbox. The instance is resolved at render/hook time instead.
local StorytellerContext = React.createContext(nil :: StorytellerContext?)
StorytellerContext.displayName = "StorytellerContext"

local function StorytellerProvider(storytellerProviderProps: StorytellerProviderProps)
	local store = storytellerProviderProps.store or StorytellerStore.instance

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
		store = StorytellerStore.instance,
	}
end

return {
	StorytellerProvider = StorytellerProvider,
	useStorytellerContext = useStorytellerContext,
}
