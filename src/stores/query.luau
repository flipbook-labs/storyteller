local Sift = require("@pkg/Sift")

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
	matcher: ((instance: Instance) -> boolean)?,

	-- Array of properties that trigger the query to recalculate matches.
	--
	-- As an example, this can be used to listen to Name and Source changes on ModuleScripts so that even if the hierarchy
	-- watchedProperties: { string }?,

	-- This is called any time one of the matches changes.
	--
	-- This can be used for more granular updates where you may not want a
	-- specific change to always trigger an update to the matches.
	shouldUpdate: ((instance: Instance) -> boolean)?,
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
	changed: RBXScriptSignal<{ Instance }>,

	removed: RBXScriptSignal<{ Instance }>,

	added: RBXScriptSignal<{ Instance }>,
}

local function query(options: QueryOptions): QueryResult
	local matches: { Instance } = {}
	local queue: { Instance } = {}

	local connections: { RBXScriptConnection } = {}

	-- Weak table so we don't leak memory from using Instances as keys
	local seen: { [Instance]: boolean } = {}
	setmetatable(seen, { __mode = "k" })

	local isDestroyed = false

	local added = Instance.new("BindableEvent")
	local changed = Instance.new("BindableEvent")
	local removed = Instance.new("BindableEvent")

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

	local function flush()
		local addedInstances = {}
		local removedInstances = {}
		local changedInstances = {}

		local function processInstance(instance: Instance)
			local isMatch = if options.matcher then options.matcher(instance) else true

			if seen[instance] then
				if isMatch then
					if not options.shouldUpdate or options.shouldUpdate(instance) then
						table.insert(changedInstances, instance)
					end
				else
					-- Might need to do a table.find on `matches` first to make
					-- sure `instance` _was_ a match before removing it
					table.insert(removedInstances, instance)
				end
			else
				seen[instance] = true

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

				if isMatch then
					table.insert(addedInstances, instance)
				end
			end
		end

		while #queue > 0 do
			local candidate = table.remove(queue, 1)
			if candidate then
				processInstance(candidate)
			end
		end

		matches = Sift.List.filter(matches, function(match)
			for _, removedInstance in removedInstances do
				if match == removedInstance then
					return true
				end
			end
			return false
		end)

		if #addedInstances > 0 then
			added:Fire(addedInstances)
		end
		if #changedInstances > 0 then
			changed:Fire(changedInstances)
		end
		if #removedInstances > 0 then
			removed:Fire(removedInstances)
		end
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

		added = added.Event,
		changed = changed.Event,
		removed = removed.Event,
	}
end

return query
