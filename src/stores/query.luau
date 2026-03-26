local Charm = require("@pkg/Charm")

local function hasSameMembers<T>(a: { T }, b: { T }): boolean
	if #a ~= #b then
		return false
	end

	local members: { [T]: true } = {}
	for _, member in a do
		members[member] = true
	end

	for _, member in b do
		if not members[member] then
			return false
		end
	end

	return true
end

local function weak<K, V>(obj: { [K]: V }): { [K]: V }
	-- We lie and say there's no metatable so we can use generic for loops. Without
	-- this the return value has to be wrapped in `pairs` for Luau to get the memo.
	return setmetatable(obj, { __mode = "k" }) :: any
end

export type QueryOptions = {
	-- The root Instance that will have its descendants queried for matches.
	root: Instance,

	-- Selector pattern that will be used to query for matches.
	-- Read more: https://create.roblox.com/docs/reference/engine/classes/Instance#QueryDescendants
	selector: string,

	-- This function is used for crafting specialized queries that the engine's
	-- selector pattern can't satisfy.
	matcher: ((instance: Instance) -> boolean)?,
}

export type QueryResult = {
	-- Returns a snapshot of the current matched Instances
	get: () -> { Instance },

	getSet: () -> { [Instance]: true },

	-- Destroys the query, disconnecting open connections and cleaning itself up.
	destroy: () -> (),
}

local function query(options: QueryOptions): QueryResult
	local getMatches, setMatches = Charm.signal({} :: { Instance })

	local connections: { RBXScriptConnection } = {}

	-- We use weak keys so that if an Instance gets removed we release the hold
	-- on its memory. When Instances are destroyed connections are too, so we
	-- don't need to worry about those lingering.
	local changedConnections = weak({} :: { [Instance]: RBXScriptConnection })

	local isDestroyed = false

	local getMatchesSet = Charm.computed(function()
		local set: { [Instance]: true } = {}
		for _, instance in getMatches() do
			set[instance] = true
		end
		return set
	end)

	local function destroy()
		isDestroyed = true

		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)

		for _, connection in changedConnections do
			connection:Disconnect()
		end
		table.clear(changedConnections)
	end

	local function queryDescendantsAsync()
		local matches = {}

		for _, instance in options.root:QueryDescendants(options.selector) do
			local isDescendant = instance:IsDescendantOf(options.root)

			if not isDescendant then
				continue
			end

			local isMatch = if options.matcher then options.matcher(instance) else true

			if isMatch then
				table.insert(matches, instance)
			end
		end

		return matches
	end

	task.spawn(function()
		while not isDestroyed do
			local matches = queryDescendantsAsync()
			local prevMatches = getMatches()

			setMatches(function(prev)
				if hasSameMembers(prevMatches, matches) then
					return prev
				else
					return matches
				end
			end)

			for _, match in matches do
				if not changedConnections[match] then
					changedConnections[match] = match.Changed:Connect(function()
						setMatches(function(prev)
							return table.clone(prev)
						end)
					end)
				end
			end

			task.wait()
		end
	end)

	return {
		get = getMatches,
		getSet = getMatchesSet,
		destroy = destroy,
	}
end

return query
