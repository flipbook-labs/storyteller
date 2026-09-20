type StoreLifecycle = {
	start: () -> (),
	stop: () -> (),
}

local consumerCounts = {} :: { [StoreLifecycle]: number }

local function acquireStorytellerStore(store: StoreLifecycle): () -> ()
	local consumerCount = consumerCounts[store] or 0
	if consumerCount == 0 then
		store.start()
	end
	consumerCounts[store] = consumerCount + 1

	local isReleased = false

	return function()
		if isReleased then
			return
		end
		isReleased = true

		local nextConsumerCount = consumerCounts[store] - 1
		if nextConsumerCount == 0 then
			consumerCounts[store] = nil
			store.stop()
		else
			consumerCounts[store] = nextConsumerCount
		end
	end
end

return acquireStorytellerStore
