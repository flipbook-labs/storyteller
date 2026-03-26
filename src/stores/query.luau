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

	start: () -> (),
	stop: () -> (),
}

local function query(options: QueryOptions): QueryResult
	local getMatches, setMatches = Charm.signal({} :: { Instance })

	local isDestroyed = false
	local isRunning = false

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

	local function start()
		if isDestroyed or isRunning then
			return
		end
		isRunning = true

		task.spawn(function()
			while not isDestroyed and isRunning do
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
	end

	local function stop()
		if isDestroyed or not isRunning then
			return
		end
		isRunning = false
	end

	local function destroy()
		stop()
		isDestroyed = true
	end

	start()

	return {
		get = getMatches,
		destroy = destroy,

		start = start,
		stop = stop,
	}
end

return query
