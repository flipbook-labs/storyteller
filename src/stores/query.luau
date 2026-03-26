local Charm = require("@pkg/Charm")

local debounce = require("@root/debounce")

-- The amount of time (in milliseconds) that this function can spend processing
-- the queue before deferring to a later frame.
local FRAME_BUDGET_MS = 5

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
	local changedConnections: { [Instance]: RBXScriptConnection } = {}

	local isDestroyed = false

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

		local startTime = os.clock()

		for _, instance in options.root:QueryDescendants(options.selector) do
			local isDescendant = instance:IsDescendantOf(options.root)

			if not isDescendant then
				continue
			end

			local isMatch = if options.matcher then options.matcher(instance) else true

			if isMatch then
				table.insert(matches, instance)
			end

			local elapsed = os.clock() - startTime

			-- We may not even need this in practice
			if elapsed * 1000 > FRAME_BUDGET_MS then
				task.wait()
			end
		end

		return matches
	end

	task.spawn(function()
		while not isDestroyed do
			local matches = queryDescendantsAsync()

			setMatches(matches)

			for _, match in matches do
				if not changedConnections[match] then
					changedConnections[match] = match.Changed:Connect(function()
						print("Changed!")
					end)
				end
			end

			task.wait()
		end
	end)

	return {
		get = getMatches,
		destroy = destroy,
	}
end

return query
