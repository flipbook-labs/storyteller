local Charm = require("@pkg/Charm")

local FRAME_BUDGET_MS = 2

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

	-- This is called right before an Instance is processed and allows you to
	-- either proceed with processing or defer for later.
	--
	-- Return `true` to process now and `false` to defer.
	shouldProcess: ((instance: Instance) -> boolean)?,
}

export type QueryResult = {
	-- Returns a snapshot of the current matched Instances
	get: () -> { Instance },

	-- Destroys the query, disconnecting open connections and cleaning itself up.
	destroy: () -> (),

	getQueueSize: () -> number,

	-- Fired any time a matched Instance is added. This happens when...
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

local function weak<K, V>(t: { [K]: V }): { [K]: V }
	return setmetatable(t, { __mode = "k" }) :: any
end

local function query(options: QueryOptions): QueryResult
	local getMatches, setMatches = Charm.signal({} :: { Instance })
	local getQueue, setQueue = Charm.signal({} :: { Instance })

	local changes = weak({} :: { [Instance]: true })
	local queued = weak({} :: { [Instance]: true })
	local seen = weak({} :: { [Instance]: true })

	local observeDispose

	local connections: { RBXScriptConnection } = {}
	local isDestroyed = false

	local added = Instance.new("BindableEvent")
	local changed = Instance.new("BindableEvent")
	local removed = Instance.new("BindableEvent")

	local getQueueSize = Charm.computed(function()
		return #getQueue()
	end)

	local function enqueueSelectedDescendants()
		local matches = {}

		for _, instance in options.root:QueryDescendants(options.selector) do
			-- TODO: We may need to hash the instances so we can handle the
			-- ModuleLoader cloning strategy. Or....Could we just use
			-- GetFullName? Is it important at all to use instances for these?
			if seen[instance] or queued[instance] then
				continue
			end

			local isMatch = if options.matcher then options.matcher(instance) else true
			local shouldProcess = if options.shouldProcess then options.shouldProcess(instance) else true

			if isMatch and shouldProcess then
				table.insert(matches, instance)
			end
		end

		if #matches == 0 then
			return
		end

		setQueue(function(prev)
			local new = table.clone(prev)
			for _, match in matches do
				table.insert(new, match)
			end
			return new
		end)
	end

	local function destroy()
		isDestroyed = true
		observeDispose()

		for _, connection in connections do
			connection:Disconnect()
		end
	end

	local function onInstanceAdded(instance: Instance)
		seen[instance] = true

		-- NOTE: Let's keep using Changed. We should debounce it, but I
		-- think we could treat any instance change as a reason to
		-- refresh for now. We shouldn't need to re-queue though. Maybe
		-- just move the match to the end of the array so we can trigger
		-- an update?
		table.insert(
			connections,
			instance.Changed:Connect(function(property)
				changes[instance] = true
			end)
		)

		setMatches(function(prev)
			local new = table.clone(prev)
			table.insert(new, instance)
			return new
		end)
	end

	local function onInstanceRemoved(instance: Instance)
		queued[instance] = nil
		seen[instance] = nil
		changes[instance] = nil

		setMatches(function(prev)
			local new = table.clone(prev)
			local index = table.find(new, instance)
			if index then
				table.remove(new, index)
			end
			return new
		end)
	end

	local function onInstanceChanged(instance: Instance)
		changes[instance] = nil

		changed:Fire(instance)

		local isMatch = if options.matcher then options.matcher(instance) else true

		if not (isMatch and instance:IsDescendantOf(options.root)) then
			onInstanceRemoved(instance)
		end

		setMatches(function(prev)
			local new = table.clone(prev)
			local index = table.find(new, instance)

			if index then
				table.remove(new, index)

				if isMatch then
					table.insert(new, instance)
				end
			end
			return new
		end)
	end

	local function onProcessSeenInstance(instance: Instance)
		local isMatch = if options.matcher then options.matcher(instance) else true

		if isMatch and instance:IsDescendantOf(options.root) then
			local shouldUpdate = if options.shouldUpdate then options.shouldUpdate(instance) else false

			if shouldUpdate then
				changes[instance] = true
			end
		else
			onInstanceRemoved(instance)
		end
	end

	local function flushAsync()
		local startTime = os.clock()

		while true do
			if #getQueue() == 0 then
				break
			end

			local candidate = getQueue()[1]

			if candidate then
				local shouldProcess = if options.shouldProcess then options.shouldProcess(candidate) else true

				if shouldProcess then
					-- Now that we know we're going to process this instance we can
					-- remove it from the queue
					setQueue(function(prev)
						local new = table.clone(prev)
						table.remove(new, 1)
						return new
					end)

					if seen[candidate] then
						onProcessSeenInstance(candidate)
					else
						onInstanceAdded(candidate)
					end
				end
			end

			local elapsed = (os.clock() - startTime) * 1000
			if elapsed > FRAME_BUDGET_MS then
				break
			end
		end
	end

	local function startProcessingAsync()
		while not isDestroyed do
			enqueueSelectedDescendants()

			if #getQueue() > 0 then
				flushAsync()
			end

			for change in pairs(changes) do
				onInstanceChanged(change)
			end

			task.wait(1 / 30)
		end
	end

	-- Does this even work?
	observeDispose = Charm.observe(getMatches, function(instance)
		added:Fire({ instance })

		return function()
			removed:Fire({ instance })
		end
	end)

	task.spawn(startProcessingAsync)

	return {
		get = getMatches,
		destroy = destroy,

		getQueueSize = getQueueSize,

		added = added.Event,
		changed = changed.Event,
		removed = removed.Event,
	}
end

return query
