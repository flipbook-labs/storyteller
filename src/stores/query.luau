local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")

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

	-- Destroys the query, disconnecting open connections and cleaning itself up.
	destroy: () -> (),
}

local function query(options: QueryOptions): QueryResult
	local getMatches, setMatches = Charm.signal({} :: { Instance })

	local connections: { RBXScriptConnection } = {}

	local isDestroyed = false

	local function destroy()
		isDestroyed = true

		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end

	local function queryDescendantsAsync()
		local matches = {}

		for _, instance in options.root:QueryDescendants(options.selector) do
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

			setMatches(function(prev)
				if #Sift.List.differenceSymmetric(matches, prev) == 0 then
					return prev
				else
					return matches
				end
			end)

			task.wait()
		end
	end)

	return {
		get = getMatches,
		destroy = destroy,
	}
end

return query
