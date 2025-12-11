local function insertUnique<T>(arr: { T }, item: T)
	if not table.find(arr, item) then
		table.insert(arr, item)
	end
end

export type QueryOptions = {
	-- Array of the root Instances that will have their descendants queried for
	-- matches.
	roots: { Instance },

	-- Selector pattern that will be used to query for matches.
	-- Read more: https://create.roblox.com/docs/reference/engine/classes/Instance#QueryDescendants
	selector: string,

	-- This function is used for crafting specialized queries that the engine's
	-- selector pattern can't satisfy.
	matcher: ((candidate: Instance) -> boolean)?,

	-- Array of properties that trigger the query to recalculate matches.
	--
	-- As an example, this can be used to listen to Name and Source changes on ModuleScripts so that even if the hierarchy
	-- watchedProperties: { string }?,

	-- This is called any time one of the matches changes.
	--
	-- This can be used for more granular updates where you may not want a
	-- specific change to always trigger an update to the matches.
	shouldUpdate: ((candidate: Instance, prevCandidate: Instance) -> boolean)?,
}

export type QueryResult = {
	-- Returns a snapshot of the current matched Instances
	get: () -> { Instance },

	-- Destroys the query, disconnecting open connections and cleaning itself up.
	destroy: () -> (),

	getQueueSize: () -> number,
	flush: () -> (),

	-- Fired any time the matched Instances change. This happens when the Instance is...
	-- 1. Parented to one of the `roots`
	-- 2.
	changed: RBXScriptSignal,
}

local function query(options: QueryOptions): QueryResult
	local matches: { Instance } = {}
	local queue: { Instance } = {}
	local connections: { RBXScriptConnection } = {}

	local isDestroyed = false

	local changed = Instance.new("BindableEvent")

	local function get()
		return matches
	end

	local function getQueueSize()
		return #queue
	end

	local function destroy()
		isDestroyed = true

		for _, connection in connections do
			connection:Disconnect()
		end
	end

	local function onInstanceAdded(instance: Instance)
		-- TODO: Only connect these events once
		local events: { RBXScriptSignal } = {
			instance.Changed,
			instance.AncestryChanged,
		}

		for _, event in events do
			table.insert(
				connections,
				event:Connect(function()
					insertUnique(queue, instance)
				end)
			)
		end

		if not options.matcher or options.matcher(instance) then
			table.insert(matches, instance)
		end

		if options.shouldUpdate and options.shouldUpdate(instance) then
			-- TODO: For shouldUpdate to provide prevCandidate I might need to keep
			-- around a snapshot of _every_ match as a :Clone(). That could get
			-- expensive fast.
		end
	end

	local function flush()
		for _, instance in queue do
			onInstanceAdded(instance)
		end
		queue = {}
	end

	for _, root in options.roots do
		for _, match in root:QueryDescendants(options.selector) do
			insertUnique(queue, match)
		end

		table.insert(
			connections,
			root.DescendantAdded:Connect(function(instance)
				insertUnique(queue, instance)
			end)
		)
	end

	task.spawn(function()
		while not isDestroyed do
			flush()
			task.wait()
		end
	end)

	return {
		get = get,
		destroy = destroy,

		getQueueSize = getQueueSize,
		flush = flush,

		changed = changed.Event,
	}
end

return query
