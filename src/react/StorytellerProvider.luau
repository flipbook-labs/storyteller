local React = require("@pkg/React")

local StorytellerContext = require("@root/react/StorytellerContext")
local StorytellerStore = require("@root/stores/StorytellerStore")

local useEffect = React.useEffect

export type StorytellerProviderProps = {
	store: StorytellerStore.StorytellerStore,
	children: React.ReactNode,
}

local function StorytellerProvider(props: StorytellerProviderProps)
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

return StorytellerProvider
