local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")

local QUERY_STEP_COOLDOWN_SEC = 0.2

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
	local initialMatches: { Instance } = {}
	local getMatches, setMatches = Charm.signal(initialMatches)

	local isDestroyed = false
	local isRunning = false

	local function setCurrentMatches(matches: { Instance })
		setMatches(function(prev)
			if #matches == #prev and #Sift.List.differenceSymmetric(matches, prev) == 0 then
				return prev
			end

			return matches
		end)
	end

	local function queryDescendants(): { Instance }
		local matches = {}
		local root = options.root

		if root:IsA(options.selector) then
			local isMatch = if options.matcher then options.matcher(root) else true
			if isMatch then
				table.insert(matches, root)
			end
		end

		for _, instance in root:QueryDescendants(options.selector) do
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

		local function stepAsync()
			if isDestroyed or not isRunning then
				return
			end

			setCurrentMatches(queryDescendants())
			task.delay(QUERY_STEP_COOLDOWN_SEC, stepAsync)
		end

		task.spawn(stepAsync)
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

	return {
		get = getMatches,
		destroy = destroy,

		start = start,
		stop = stop,
	}
end

return query
