local Prospector = require("@pkg/Prospector")
local Signals = require("@rbxpkg/Signals")

type CollectionPredicate = (instance: Instance) -> boolean?

export type InstanceCollectionStore = {
	getIsRunning: Signals.getter<boolean>,
	createCollection: (predicate: CollectionPredicate) -> Signals.getter<Instance>,
	collect: (root: Instance) -> (),
}

type Collection = {
	predicate: CollectionPredicate,
	setCollection: Signals.setter<{ Instance }>,
}

local function createInstanceCollectionStore(): InstanceCollectionStore
	local getIsRunning, setIsRunning = Signals.createSignal(false)
	local getMatches, setMatches = Signals.createSignal({} :: { Instance })
	local getCollections, setCollections = Signals.createSignal({} :: { Collection })
	local effects: { Signals.dispose } = {}

	local function createCollection(predicate: CollectionPredicate)
		local getCollection, setCollection = Signals.createSignal({} :: { Instance })

		setCollections(function(prev)
			local new = table.clone(prev)
			table.insert(new, {
				predicate = predicate,
				setCollection = setCollection,
			})
			return new
		end)

		return getCollection
	end

	local function collect(root: Instance)
		setIsRunning(true)

		task.spawn(function()
			local matches = Prospector.Collect.descendantsBFS(root, function(descendant)
				for _, collection in getCollections(false) do
					-- If at least one predicate matches then this descendant is
					-- included. We disambiguate the final list of instances
					-- into their logical groupings later
					if collection.predicate(descendant) then
						return true
					end
				end
				return false
			end)

			setMatches(matches)

			for _, collection in getCollections(false) do
				local collectionMatches = {}
				for _, match in matches do
					if collection.predicate(match) then
						table.insert(collectionMatches, match)
					end
				end
				collection.setCollection(collectionMatches)
			end

			setIsRunning(false)
		end)
	end

	local function destroy()
		for _, dispose in effects do
			dispose()
		end
	end

	return {
		getIsRunning = getIsRunning,
		createCollection = createCollection,
		collect = collect,
		destroy = destroy,
	}
end

return createInstanceCollectionStore
