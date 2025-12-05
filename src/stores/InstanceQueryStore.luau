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

	local connections: { [string]: RBXScriptConnection } = {}
	local effects: { Signals.dispose } = {}

	-- This might be expensive when `root` is the whole DataModel. If that
	-- winds up being the case this should be adjusted so that new
	-- descendants are added to a queue and processed over several frames
	connections.DescendantAdded = root.DescendantAdded:Connect(update)

	table.insert(
		effects,
		Signals.createEffect(function(scope)
			for _, instance in getMatches(scope) do
				local key = `{instance:GetFullName()}_AncestryChanged`

				if connections[key] then
					connections[key]:Disconnect()
				end

				connections[key] = instance.AncestryChanged:Connect(update)
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
