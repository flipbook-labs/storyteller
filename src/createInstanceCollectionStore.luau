local Signals = require("@rbxpkg/Signals")

export type CollectionMatcher = (instance: Instance) -> boolean?

export type CollectionStatus = "NotStarted" | "Collecting" | "Watching" | "Stopped" | "Destroyed"

local CollectionStatus = {
	NotStarted = "NotStarted" :: "NotStarted",
	Collecting = "Collecting" :: "Collecting",
	Watching = "Watching" :: "Watching",
	Stopped = "Stopped" :: "Stopped",
	Destroyed = "Destroyed" :: "Destroyed",
}

type StopCollecting = () -> ()

export type InstanceCollectionStore = {
	getStatus: Signals.getter<CollectionStatus>,
	getMatches: Signals.getter<{ Instance }>,
	collect: () -> StopCollecting,
	destroy: () -> (),
}

local function createInstanceCollectionStore(
	root: Instance,
	selector: string,
	matcher: CollectionMatcher?
): InstanceCollectionStore
	local getStatus: Signals.getter<CollectionStatus>, setStatus =
		Signals.createSignal(CollectionStatus.NotStarted :: CollectionStatus)
	local getMatches, setMatches = Signals.createSignal({} :: { Instance })
	local effects: { Signals.dispose } = {}
	local descendantAddedConn: RBXScriptConnection?

	--[[
		This queue is used to process new and existing Instances after building
		the initial list of matches.

		The queue gets pushed to when...

		1. A new Instance is added as a descendant of `root`, or
		2. An existing match has one or more of its properties changed

		So long as `collect()` has been called and the store has not been
		destroyed, the queue will be incrementally processed so that the matches
		continue to mirror the DataModel
	]]
	local queue: { Instance } = {}

	local function collectOnce()
		print("collectOnce")
		local matches = {}

		for _, candidate in root:QueryDescendants(selector) do
			if not matcher or matcher(candidate) then
				table.insert(matches, candidate)
			end
		end

		setMatches(matches)
	end

	local function collect()
		print("collect")
		setStatus(CollectionStatus.Collecting)

		if descendantAddedConn then
			descendantAddedConn:Disconnect()
		end

		descendantAddedConn = root.DescendantAdded:Connect(function(descendant)
			print("add descendant to queue", descendant)
			table.insert(queue, descendant)
		end)

		collectOnce()

		task.spawn(function()
			setStatus(CollectionStatus.Watching)

			while getStatus(false) == CollectionStatus.Watching do
				if #queue > 0 then
					collectOnce()
					table.clear(queue)
				end
				task.wait()
			end

			setStatus(CollectionStatus.Stopped)
		end)

		return function()
			setStatus(CollectionStatus.Stopped)
		end
	end

	table.insert(
		effects,
		Signals.createEffect(function(scope)
			local connections: { RBXScriptConnection } = {}

			for _, match in getMatches(scope) do
				print(`connect to {match}.Changed`)
				table.insert(
					connections,
					match.Changed:Connect(function()
						print(`{match} changed, adding to queue...`)
						table.insert(queue, match)
					end)
				)
			end

			return function()
				for _, conn in connections do
					conn:Disconnect()
				end
			end
		end)
	)

	local function destroy()
		setStatus(CollectionStatus.Destroyed)
		for _, dispose in effects do
			dispose()
		end
	end

	return {
		getStatus = getStatus,
		getMatches = getMatches,
		collect = collect,
		destroy = destroy,
	}
end

return createInstanceCollectionStore
