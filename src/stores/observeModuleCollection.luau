export type ModuleCollection = {
	OnAdded: ((Instance) -> ())?,
	OnRemoved: ((Instance) -> ())?,
	OnPropertyChanged: {
		Name: ((Instance) -> ())?,
	},
	ForEach: (ModuleCollection, (Instance) -> ()) -> (),
	Destroy: (ModuleCollection) -> (),
}

local function observeModuleCollection(
	collection: ModuleCollection,
	root: Instance,
	onSnapshot: ({ Instance }) -> ()
): () -> ()
	local isDestroyed = false
	local isScheduled = false
	local rootConnection: RBXScriptConnection?
	local published: { [Instance]: true } = {}

	local function publishSnapshot()
		local modules: { Instance } = {}
		table.clear(published)

		if root:IsA("ModuleScript") then
			table.insert(modules, root)
			published[root] = true
		end

		collection:ForEach(function(instance)
			if instance ~= root then
				table.insert(modules, instance)
				published[instance] = true
			end
		end)

		onSnapshot(modules)
	end

	local function scheduleSnapshot()
		if isDestroyed or isScheduled then
			return
		end
		isScheduled = true

		-- Coalesce collection callbacks so a large insertion does not publish once per module.
		task.delay(0.2, function()
			isScheduled = false
			if isDestroyed then
				return
			end

			publishSnapshot()
		end)
	end

	-- The engine replays OnAdded for every existing member once the callback
	-- is assigned. Skipping members the last snapshot already holds keeps that
	-- replay from republishing an identical snapshot.
	collection.OnAdded = function(instance)
		if not published[instance] then
			scheduleSnapshot()
		end
	end
	collection.OnRemoved = function(instance)
		if published[instance] then
			scheduleSnapshot()
		end
	end
	collection.OnPropertyChanged.Name = scheduleSnapshot

	if root:IsA("ModuleScript") then
		rootConnection = root:GetPropertyChangedSignal("Name"):Connect(scheduleSnapshot)
	end

	publishSnapshot()

	return function()
		if isDestroyed then
			return
		end
		isDestroyed = true

		if rootConnection then
			rootConnection:Disconnect()
		end
		collection:Destroy()
	end
end

return observeModuleCollection
