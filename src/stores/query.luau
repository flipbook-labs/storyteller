export type QueryOptions = {
	-- The root Instance that will have its descendants queried for matches.
	root: Instance,

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

	-- Max ms to spend processing the queue per frame. Nil = no limit.
	-- Only applies to the automatic per-frame loop; flush() always drains entirely.
	frameBudgetMs: number?,

	-- Frames to wait after the last queue addition before processing.
	-- Only applies to the automatic per-frame loop; flush() bypasses this.
	settleFrames: number?,
}

export type QueryResult = {
	-- Returns a snapshot of the current matched Instances
	get: () -> { Instance },

	-- Destroys the query, disconnecting open connections and cleaning itself up.
	destroy: () -> (),

	getQueueSize: () -> number,
	flush: () -> (),

	-- Fired any time a matched Instance is removed. This happens when...
	-- 1. The Instance is parented to `root`
	-- 2. The Instance is changed in such a way that starts matching the query
	added: RBXScriptSignal<{ Instance }>,

	-- Fired any time the matched Instances have their properties change.
	changed: RBXScriptSignal<{ Instance }>,

	-- Fired any time a matched Instance is removed. This happens when...
	-- 1. The Instance is parented outside of `root`
	-- 2. The Instance is destroyed
	-- 3. The Instance is changed in such a way that it no longer matches
	removed: RBXScriptSignal<{ Instance }>,
}

local function query(options: QueryOptions): QueryResult
	local matches: { Instance } = {}
	local matchSet: { [Instance]: true } = {}

	-- Queue implemented with head index + membership set to avoid O(n) pops/lookups.
	local queue: { Instance } = {}
	local queueHead = 1
	local queued: { [Instance]: true } = {}
	setmetatable(queued, { __mode = "k" })

	local connections: { RBXScriptConnection } = {}

	-- Weak table so we don't leak memory from using Instances as keys
	local seen: { [Instance]: true } = {}
	setmetatable(seen, { __mode = "k" })

	local isDestroyed = false

	local added = Instance.new("BindableEvent")
	local changed = Instance.new("BindableEvent")
	local removed = Instance.new("BindableEvent")

	local function get()
		return matches
	end

	local function getQueueSize()
		return #queue - queueHead + 1
	end

	local function enqueue(instance: Instance)
		if queued[instance] then
			return
		end
		queued[instance] = true
		table.insert(queue, instance)
	end

	local function destroy()
		isDestroyed = true

		for _, connection in connections do
			connection:Disconnect()
		end
	end

	local function runDrain(budgetMs: number?)
		local addedInstances: { Instance } = {}
		local removedInstances: { Instance } = {}
		local changedInstances: { Instance } = {}

		local function processInstance(instance: Instance)
			local isMatch = if options.matcher then options.matcher(instance) else true

			if seen[instance] then
				if isMatch and instance:IsDescendantOf(options.root) then
					local shouldUpdate = if options.shouldUpdate then options.shouldUpdate(instance) else true

					if shouldUpdate then
						table.insert(changedInstances, instance)
					end
				else
					if matchSet[instance] then
						table.insert(removedInstances, instance)
					end
				end
			else
				seen[instance] = true

				-- If listening to every property change gets expensive another
				-- option is to add `watchedProperties: { string }` to
				-- QueryOptions so only specefied options will trigger changes
				table.insert(
					connections,
					instance.Changed:Connect(function()
						enqueue(instance)
					end)
				)

				if isMatch then
					table.insert(addedInstances, instance)
				end
			end
		end

		local startTime = if budgetMs then os.clock() * 1000 else 0
		while queueHead <= #queue do
			if budgetMs and (os.clock() * 1000 - startTime) > budgetMs then
				break
			end
			local candidate = queue[queueHead]
			queue[queueHead] = nil
			queueHead += 1
			if candidate then
				queued[candidate] = nil
				processInstance(candidate)
			end
		end
		if queueHead > #queue then
			queue = {}
			queueHead = 1
		end

		if #addedInstances > 0 or #changedInstances > 0 or #removedInstances > 0 then
			local removedSet: { [Instance]: boolean } = {}
			for _, removedInstance in removedInstances do
				removedSet[removedInstance] = true
			end

			local newMatches: { Instance } = {}
			for _, existing in matches do
				if removedSet[existing] then
					matchSet[existing] = nil
				else
					table.insert(newMatches, existing)
				end
			end

			for _, addedInstance in addedInstances do
				if not matchSet[addedInstance] then
					matchSet[addedInstance] = true
					table.insert(newMatches, addedInstance)
				end
			end

			for _, changedInstance in changedInstances do
				if not matchSet[changedInstance] then
					matchSet[changedInstance] = true
					table.insert(newMatches, changedInstance)
				end
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

	local function flush()
		runDrain(nil)
	end

	table.insert(
		connections,
		options.root.DescendantAdded:Connect(function(instance)
			enqueue(instance)
		end)
	)

	for _, match in options.root:QueryDescendants(options.selector) do
		enqueue(match)
	end

	task.spawn(function()
		local settleFrames = if options.settleFrames ~= nil then options.settleFrames else 0
		local cooldown = 0
		local lastQueueSize = 0

		while not isDestroyed do
			local currentQueueSize = getQueueSize()
			if currentQueueSize > lastQueueSize then
				cooldown = settleFrames
			end
			lastQueueSize = currentQueueSize

			if cooldown > 0 then
				cooldown -= 1
			elseif currentQueueSize > 0 then
				runDrain(options.frameBudgetMs)
				lastQueueSize = getQueueSize()
			end

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
