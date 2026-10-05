local Charm = require("@pkg/Charm")

local observeModuleCollection = require("./observeModuleCollection")

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
	local getMatches, setMatches = Charm.signal({} :: { Instance })

	local isDestroyed = false
	local isRunning = false
	local generation = 0
	local disposeCollection: (() -> ())?

	local function queryDescendants(): { Instance }
		local matches = {}

		if options.root:IsA(options.selector) then
			local isMatch = if options.matcher then options.matcher(options.root) else true
			if isMatch then
				table.insert(matches, options.root)
			end
		end

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
		generation += 1
		local activeGeneration = generation

		if options.selector == "ModuleScript" and options.matcher == nil then
			local success, collection = pcall(function()
				return game:GetService("CollectionService"):CreateCollection("ModuleScript", options.root)
			end)

			if success then
				disposeCollection = observeModuleCollection(
					(collection :: unknown) :: observeModuleCollection.ModuleCollection,
					options.root,
					setMatches
				)
				return
			end
		end

		local function stepAsync()
			if isDestroyed or not isRunning or activeGeneration ~= generation then
				return
			end

			-- Membership can stay unchanged while names change their classification.
			setMatches(queryDescendants())
			task.delay(QUERY_STEP_COOLDOWN_SEC, stepAsync)
		end

		task.spawn(stepAsync)
	end

	local function stop()
		if isDestroyed or not isRunning then
			return
		end
		isRunning = false
		if disposeCollection then
			disposeCollection()
			disposeCollection = nil
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
