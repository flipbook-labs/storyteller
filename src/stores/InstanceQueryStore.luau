local Signals = require("@rbxpkg/Signals")

export type InstanceQueryStore = {
	root: Instance,
	selector: string,

	getMatches: Signals.getter<{ Instance }>,
	destroy: () -> (),
}

local InstanceQueryStore = {}

function InstanceQueryStore.new(root: Instance, selector: string): InstanceQueryStore
	local self = {
		root = root,
		selector = selector,
	}

	local getMatches, setMatches = Signals.createSignal(function()
		return root:QueryDescendants(selector)
	end)
	self.getMatches = getMatches

	local function update()
		setMatches(root:QueryDescendants(selector))
	end

	local connections: { RBXScriptConnection } = {}
	local effects: { Signals.dispose } = {}

	table.insert(
		effects,
		Signals.createEffect(function(scope)
			-- This might be expensive when `root` is the whole DataModel. If that
			-- winds up being the case this should be adjusted so that new
			-- descendants are added to a queue and processed over several frames
			table.insert(connections, root.DescendantAdded:Connect(update))

			for _, instance in getMatches(scope) do
				table.insert(connections, instance.AncestryChanged:Connect(update))
			end
		end)
	)

	self.destroy = function()
		for _, connection in connections do
			connection:Disconnect()
		end

		for _, dispose in effects do
			dispose()
		end
	end

	return self
end

return InstanceQueryStore
