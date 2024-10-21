local ModuleLoader = require("@pkg/ModuleLoader")
local React = require("@pkg/React")

local constants = require("@root/constants")
local findStorybookModules = require("@root/findStorybookModules")
local types = require("@root/types")

local function useStorybooks(parent: Instance, loader: ModuleLoader.ModuleLoader)
	local storybooks, set = React.useState({})

	local modules = React.useMemo(function()
		return findStorybookModules(parent)
	end, { parent })

	local loadStorybooks = React.useCallback(function()
		local newStorybooks = {}

		for _, module in modules do
			local wasRequired, result = pcall(function()
				return loader:require(module :: ModuleScript)
			end)

			if wasRequired then
				local success, message = types.IStorybook(result)

				if success then
					result.name = if result.name
						then result.name
						else module.Name:gsub(constants.STORYBOOK_NAME_PATTERN, "")

					table.insert(newStorybooks, result)
				else
					warn(("Failed to load storybook %s. Error: %s"):format(module:GetFullName(), message))
				end
			end
		end

		set(newStorybooks)
	end, { set, parent, loader, modules } :: { unknown })

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
