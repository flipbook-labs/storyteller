local Signals = require("@rbxpkg/Signals")

export type CollectionMatcher = (instance: Instance) -> boolean?

export type InstanceCollectionStore = {
	getMatches: Signals.getter<{ Instance }>,
	destroy: () -> (),
}

local function createInstanceCollectionStore(
	root: Instance,
	selector: string,
	matcher: CollectionMatcher?
): InstanceCollectionStore
	local getMatches, setMatches = Signals.createSignal({} :: { Instance })
	local effects: { Signals.dispose } = {}

	local function collect()
		local matches = {}

		for _, candidate in root:QueryDescendants(selector) do
			if not matcher or matcher(candidate) then
				table.insert(matches, candidate)
			end
		end

		setMatches(matches)
	end

	local descendantAddedConn = root.DescendantAdded:Connect(collect)

	table.insert(
		effects,
		Signals.createEffect(function(scope)
			local connections: { RBXScriptConnection } = {}

			for _, match in getMatches(scope) do
				table.insert(connections, match.Changed:Connect(collect))
			end

			return function()
				for _, conn in connections do
					conn:Disconnect()
				end
			end
		end)
	)

	local function destroy()
		descendantAddedConn:Disconnect()
		for _, dispose in effects do
			dispose()
		end
	end

	task.spawn(collect)

	return {
		getMatches = getMatches,
		destroy = destroy,
	}
end

return createInstanceCollectionStore
