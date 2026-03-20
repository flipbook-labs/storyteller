local debounce = require("@root/debounce")

-- The amount of time (in milliseconds) that this function can spend processing
-- the queue before deferring to a later frame.
local FRAME_BUDGET_MS = 2

local function insertUnique<T>(arr: { T }, item: T)
	if not table.find(arr, item) then
		table.insert(arr, item)
	end
end

export type QueryOptions = {
	-- The root Instance that will have its descendants queried for matches.
	root: Instance,

	-- Selector pattern that will be used to query for matches.
	-- Read more: https://create.roblox.com/docs/reference/engine/classes/Instance#QueryDescendants
	selector: string,

	-- This function is used for crafting specialized queries that the engine's
	-- selector pattern can't satisfy.
	matcher: ((instance: Instance) -> boolean)?,

	-- This is called right before an Instance is processed and allows you to
	-- either proceed with processing or defer for later.
	--
	-- Return `true` to process now and `false` to defer.
	shouldProcess: ((instance: Instance) -> boolean)?,

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
	-- We keep track of an ordered queue and a dict of each queued Instance for
	-- fast lookups.
	--
	--  Also note that we use weak tables when keying by Instance to ensure we
	-- don't hold a lock on those instances (and leak memory) if we forget to
	-- remove them from the dict
	local queue: { Instance } = {}
	local queued = setmetatable({} :: { [Instance]: true }, { __mode = "k" })

	local seen = setmetatable({} :: { [Instance]: true }, { __mode = "k" })

	local matches: { Instance } = {}
	local connections: { RBXScriptConnection } = {}

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

	local function flush()
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
					if table.find(matches, instance) then
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
					instance.Changed:Connect(debounce(function()
						enqueue(instance)
					end))
				)

				if isMatch then
					table.insert(addedInstances, instance)
				end
			end
		end

		local startTime = os.clock()
		while #queue > 0 do
			local candidate = table.remove(queue, 1)

			if candidate then
				local shouldProcess = if options.shouldProcess then options.shouldProcess(candidate) else true

				if shouldProcess then
					queued[candidate] = nil
					processInstance(candidate)
				else
					-- Place the candidate back at the end of the queue to be
					-- processed again later
					table.insert(queue, candidate)
				end
			end

			local elapsed = os.clock() - startTime

			if elapsed * 1000 > FRAME_BUDGET_MS then
				break
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
				if table.find(removedInstances, addedInstance) ~= nil then
					continue
				end

				insertUnique(newMatches, addedInstance)
			end

			for _, changedInstance in changedInstances do
				if table.find(removedInstances, changedInstance) ~= nil then
					continue
				end

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
		while not isDestroyed do
			if #queue > 0 then
				flush()
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
