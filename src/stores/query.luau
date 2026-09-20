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

type QueryState = {
	matcher: ((instance: Instance) -> boolean)?,
	setCurrentMatches: (matches: { Instance }) -> (),
}

type QueryGroup = {
	isRunning: boolean,
	root: Instance,
	selector: string,
	states: { [QueryState]: boolean },
}

local queryGroupsByRoot = {} :: { [Instance]: { [string]: QueryGroup } }

local function queryDescendants(group: QueryGroup): { Instance }
	local candidates = {}

	if group.root:IsA(group.selector) then
		table.insert(candidates, group.root)
	end

	for _, instance in group.root:QueryDescendants(group.selector) do
		table.insert(candidates, instance)
	end

	return candidates
end

local function updateQuery(state: QueryState, candidates: { Instance })
	if not state.matcher then
		state.setCurrentMatches(candidates)
		return
	end

	local matches = {}
	for _, instance in candidates do
		if state.matcher(instance) then
			table.insert(matches, instance)
		end
	end
	state.setCurrentMatches(matches)
end

local function stepAsync(group: QueryGroup)
	if not group.isRunning then
		return
	end

	local candidates = queryDescendants(group)
	for state in group.states do
		updateQuery(state, candidates)
	end
	task.delay(QUERY_STEP_COOLDOWN_SEC, stepAsync, group)
end

local function getQueryGroup(root: Instance, selector: string): QueryGroup
	local groupsBySelector = queryGroupsByRoot[root]
	if not groupsBySelector then
		groupsBySelector = {}
		queryGroupsByRoot[root] = groupsBySelector
	end

	local group = groupsBySelector[selector]
	if not group then
		group = {
			isRunning = false,
			root = root,
			selector = selector,
			states = {},
		}
		groupsBySelector[selector] = group
	end

	return group
end

local function removeQueryGroupIfEmpty(group: QueryGroup)
	if next(group.states) ~= nil then
		return
	end

	group.isRunning = false
	local groupsBySelector = queryGroupsByRoot[group.root]
	if not groupsBySelector then
		return
	end

	groupsBySelector[group.selector] = nil
	if next(groupsBySelector) == nil then
		queryGroupsByRoot[group.root] = nil
	end
end

local function query(options: QueryOptions): QueryResult
	local getMatches, setMatches = Charm.signal({} :: { Instance })

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

	local state: QueryState = {
		matcher = options.matcher,
		setCurrentMatches = setCurrentMatches,
	}
	local activeGroup: QueryGroup?

	local function start()
		if isDestroyed or isRunning then
			return
		end
		isRunning = true

		local group = getQueryGroup(options.root, options.selector)
		activeGroup = group
		group.states[state] = true
		if not group.isRunning then
			group.isRunning = true
			task.defer(stepAsync, group)
		end
	end

	local function stop()
		if isDestroyed or not isRunning then
			return
		end
		isRunning = false

		local group = activeGroup
		activeGroup = nil
		if group then
			group.states[state] = nil
			removeQueryGroupIfEmpty(group)
		end
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
