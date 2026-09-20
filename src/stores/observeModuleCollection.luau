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

			local modules: { Instance } = {}
			if root:IsA("ModuleScript") then
				table.insert(modules, root)
			end

			collection:ForEach(function(instance)
				if instance ~= root then
					table.insert(modules, instance)
				end
			end)

			onSnapshot(modules)
		end)
	end

	collection.OnAdded = scheduleSnapshot
	collection.OnRemoved = scheduleSnapshot
	collection.OnPropertyChanged.Name = scheduleSnapshot

	if root:IsA("ModuleScript") then
		rootConnection = root:GetPropertyChangedSignal("Name"):Connect(scheduleSnapshot)
	end

	scheduleSnapshot()

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
