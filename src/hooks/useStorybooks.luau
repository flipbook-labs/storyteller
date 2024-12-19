local ModuleLoader = require("@pkg/ModuleLoader")
local React = require("@pkg/React")
local Sift = require("@pkg/Sift")

local findStorybookModules = require("@root/findStorybookModules")
local isStorybookModule = require("@root/isStorybookModule")
local loadStorybookModule = require("@root/loadStorybookModule")
local types = require("@root/types")

local useCallback = React.useCallback
local useEffect = React.useEffect
local useRef = React.useRef
local useState = React.useState

type ModuleLoader = ModuleLoader.ModuleLoader
type LoadedStorybook = types.LoadedStorybook
type UnavailableStorybook = {
	problem: string,
	storybook: types.LoadedStorybook,
}

--[=[
	Performs all the discovery and loading of Storybook modules that would
	normally be done via individual API members.

	This hook makes it possible to conveniently load (and reload) Storybooks for
	use in React UI.

	:::info
	In the future version hooks may be migrated to a new package to remove the React dependency from Storyteller.
	:::

	Usage:

	```lua
	local React = require("@pkg/React")
	local Storyteller = require("@pkg/Storyteller")

	local e = React.createElement

	local function StorybookList(props: {
		parent: Instance,
	})
		local storybooks = Storyteller.useStorybooks(props.parent)

		local children = {}
		for index, storybook in storybooks do
			children[storybook.name] = e("TextLabel", {
				Text = storybook.name,
				LayoutOrder = index,
			}),
		end

		return e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, {
			Layout = e("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder
			}),
		}, children)
	end

	return StorybookList
	```

	This hook triggers a rerender when a Storybook module changes. For example,
	updating the `storyRoots` of a Storybook will trigger a rerender, and when
	paired with `useStory` you can get live updates to which Stories a Storybook
	manages.

	@tag React
	@tag Storybook
	@within Storyteller
]=]
local function useStorybooks(parent: Instance): {
	available: { LoadedStorybook },
	unavailable: { UnavailableStorybook },
}
	local storybookConnections = useRef({} :: { [ModuleScript]: { RBXScriptConnection } })
	local storybooks, setStorybooks = useState({} :: { LoadedStorybook })
	local unavailableStorybooks, setUnavailableStorybooks = useState({} :: { UnavailableStorybook })

	local getOrCreateConnectionObject = useCallback(function(storybookModule: ModuleScript): { RBXScriptConnection }
		local existing = storybookConnections.current[storybookModule]
		if existing then
			return existing
		else
			local new = {}
			storybookConnections.current[storybookModule] = new
			return new
		end
	end, {})

	local loadStorybook = useCallback(function(storybookModule: ModuleScript)
		local connections = getOrCreateConnectionObject(storybookModule)
		local loader = ModuleLoader.new()

		local reloadStorybook

		local function load()
			for _, connection in connections do
				connection:Disconnect()
			end

			local storybook: LoadedStorybook?
			local success, result = pcall(function()
				storybook = loadStorybookModule(storybookModule, loader)
			end)

			table.insert(connections, loader.loadedModuleChanged:Connect(reloadStorybook))
			table.insert(connections, storybookModule.AncestryChanged:Connect(reloadStorybook))

			-- TODO: The logic to add/update storybooks at their index is nasty.
			-- Revise this before merging
			if success and storybook then
				setStorybooks(function(prev)
					local new = table.clone(prev)
					local index = Sift.List.findWhere(new, function(other: LoadedStorybook)
						return other.source == storybookModule
					end)

					if index then
						new[index] = storybook
					else
						table.insert(new, storybook)
					end

					return new
				end)
			else
				local unavailableStorybook: UnavailableStorybook = {
					problem = result,
					storybook = {
						name = storybookModule.Name,
						loader = loader,
						source = storybookModule,
						storyRoots = {},
					},
				}

				setUnavailableStorybooks(function(prev)
					local new = table.clone(prev)
					local index = Sift.List.findWhere(new, function(other: UnavailableStorybook)
						return other.storybook.source == storybookModule
					end)

					if index then
						new[index] = unavailableStorybook
					else
						table.insert(new, unavailableStorybook)
					end

					return new
				end)
			end
		end

		function reloadStorybook(instance: Instance)
			if instance == storybookModule and isStorybookModule(instance) then
				for _, connection in connections do
					connection:Disconnect()
				end

				loader:clear()
				load()
			end
		end

		load()
	end, {})

	useEffect(function()
		setStorybooks({})
		setUnavailableStorybooks({})

		local storybookModules = findStorybookModules(parent)

		for _, storybookModule in storybookModules do
			task.spawn(loadStorybook, storybookModule)
		end

		return function()
			for _, connections in storybookConnections.current do
				for _, connection in connections do
					connection:Disconnect()
				end
			end
		end
	end, { parent } :: { unknown })

	return {
		available = storybooks,
		unavailable = unavailableStorybooks,
	}
end

return useStorybooks
