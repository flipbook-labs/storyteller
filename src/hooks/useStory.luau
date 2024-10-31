local ModuleLoader = require("@pkg/ModuleLoader")
local React = require("@pkg/React")

local loadStoryModule = require("@root/loadStoryModule")
local types = require("@root/types")

local function useStory(
	module: ModuleScript,
	storybook: types.Storybook,
	loader: ModuleLoader.ModuleLoader
): (types.Story<unknown>?, string?)
	local state, setState = React.useState({} :: {
		story: types.Story<unknown>?,
		err: string?,
	})

	local loadStory = React.useCallback(function()
		local success, result = pcall(function()
			loadStoryModule(loader, module, storybook)
		end)

		setState({
			story = if success then result else nil,
			err = if success then nil else result,
		})
	end, { loader, module, storybook } :: { unknown })

	React.useEffect(function()
		local conn = loader.loadedModuleChanged:Connect(function(other)
			if other == module then
				loadStory()
			end
		end)

		loadStory()

		return function()
			conn:Disconnect()
		end
	end, { module, loadStory, loader } :: { unknown })

	return state.story, state.err
end

return useStory
