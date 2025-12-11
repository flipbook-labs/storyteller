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

	local function queueWhenChanged(instance: Instance)
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
	end

	local function isDescendantOfRoots(instance: Instance)
		for _, root in options.roots do
			if instance:IsDescendantOf(root) then
				return true
			end
		end
		return false
	end

	local function flush()
		local addedInstances: { Instance } = {}
		local removedInstances: { Instance } = {}
		local changedInstances: { Instance } = {}

		local function processInstance(instance: Instance)
			local isMatch = if options.matcher then options.matcher(instance) else true

			if seen[instance] then
				if isMatch and isDescendantOfRoots(instance) then
					local shouldUpdate = if options.shouldUpdate then options.shouldUpdate(instance) else true

					if shouldUpdate then
						table.insert(changedInstances, instance)
					end
				else
					if table.find(matches, instance) then
						table.insert(removedInstances, instance)
					end
				end
			else
				seen[instance] = true

				queueWhenChanged(instance)

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

		if #addedInstances > 0 or #changedInstances > 0 or #removedInstances > 0 then
			local newMatches = table.clone(matches)

			for _, removedInstance in removedInstances do
				local index = table.find(matches, removedInstance)
				if index then
					table.remove(newMatches, index)
				end
			end

			for _, addedInstance in addedInstances do
				table.insert(newMatches, addedInstance)
			end

			for _, changedInstance in changedInstances do
				insertUnique(newMatches, changedInstance)
			end

			matches = newMatches

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

	flush()

	task.defer(function()
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
