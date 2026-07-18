local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")

local QUERY_STEP_COOLDOWN_SEC = 0.2
local QUERY_WORK_BUDGET_MS = 4

export type QueryOptions = {
	-- The root Instance that will have its descendants queried for matches.
	root: Instance,

	-- Selector pattern that will be used to query for matches.
	-- Read more: https://create.roblox.com/docs/reference/engine/classes/Instance#QueryDescendants
	selector: string,

	-- This function is used for crafting specialized queries that the engine's
	-- selector pattern can't satisfy.
	matcher: ((instance: Instance) -> boolean)?,

	-- Direct children of root to query first, in order. Initial matches from
	-- each priority root are published before the remaining roots are queried.
	priorityRootNames: { string }?,
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
	local hasCompletedInitialQuery = false

	local function setCurrentMatches(matches: { Instance })
		setMatches(function(prev)
			if #matches == #prev and #Sift.List.differenceSymmetric(matches, prev) == 0 then
				return prev
			end

			return matches
		end)
	end

	local function getQueryRoots(): ({ Instance }, number)
		if not options.priorityRootNames then
			return { options.root }, 0
		end

		local roots = {}
		local seenRoots = {}

		for _, name in options.priorityRootNames do
			local priorityRoot = options.root:FindFirstChild(name)
			if priorityRoot and not seenRoots[priorityRoot] then
				seenRoots[priorityRoot] = true
				table.insert(roots, priorityRoot)
			end
		end

		local priorityRootCount = #roots
		for _, child in options.root:GetChildren() do
			if not seenRoots[child] then
				table.insert(roots, child)
			end
		end

		return roots, priorityRootCount
	end

	local function queryDescendantsAsync(): { Instance }?
		local matches = {}
		local roots, priorityRootCount = getQueryRoots()
		local workStarted = os.clock()

		for index, root in roots do
			for _, instance in root:QueryDescendants(options.selector) do
				local isMatch = if options.matcher then options.matcher(instance) else true
				if isMatch then
					table.insert(matches, instance)
				end
			end

			local isPriorityRoot = index <= priorityRootCount
			if not hasCompletedInitialQuery and isPriorityRoot then
				setCurrentMatches(table.clone(matches))
			end

			local hasExceededBudget = (os.clock() - workStarted) * 1000 >= QUERY_WORK_BUDGET_MS
			if index < #roots and (isPriorityRoot or hasExceededBudget) then
				task.wait()
				if isDestroyed or not isRunning then
					return nil
				end
				workStarted = os.clock()
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

			local matches = queryDescendantsAsync()
			if not matches then
				return
			end

			setCurrentMatches(matches)
			hasCompletedInitialQuery = true
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
