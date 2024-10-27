local ModuleLoader = require("@pkg/ModuleLoader")
local React = require("@pkg/React")

local findStorybookModules = require("@root/findStorybookModules")
local loadStorybookModule = require("@root/loadStorybookModule")
local types = require("@root/types")

local function useStorybooks(parent: Instance, loader: ModuleLoader.ModuleLoader): { types.Storybook }
	local storybooks, setStorybooks = React.useState({})

	local loadStorybooks = React.useCallback(function()
		local newStorybooks = {}

		for _, storybookModule in findStorybookModules(parent) do
			local success, result = pcall(function()
				return loadStorybookModule(loader, storybookModule)
			end)

			if success then
				table.insert(newStorybooks, result)
			else
				warn(result)
			end
		end

		setStorybooks(newStorybooks)
	end, { parent, loader } :: { unknown })

	React.useEffect(function()
		local conn = loader.loadedModuleChanged:Connect(function(other)
			if types.IStorybook(other) then
				loadStorybooks()
			end
		end)

		loadStorybooks()

		return function()
			conn:Disconnect()
		end
	end, { loadStorybooks, loader } :: { unknown })

	return storybooks
end

return useStorybooks
