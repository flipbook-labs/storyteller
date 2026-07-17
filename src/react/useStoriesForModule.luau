local ModuleLoader = require("@pkg/ModuleLoader")
local React = require("@pkg/React")

local loadStoriesFromModule = require("@root/loadStoriesFromModule")
local types = require("@root/types")

local useEffect = React.useEffect
local useState = React.useState

--[=[
	Loads every Story exported by a Story module and reloads them when the
	module or one of its dependencies changes.

	@tag React
	@tag Story
	@within Storyteller
]=]
local function useStoriesForModule(
	module: ModuleScript,
	storybook: types.LoadedStorybook
): ({ types.LoadedStory<unknown> }?, string?)
	local stories, setStories = useState(nil :: { types.LoadedStory<unknown> }?)
	local err, setErr = useState(nil :: string?)

	useEffect(function()
		local changedConn: RBXScriptConnection?
		local isActive = true

		local function loadStories()
			if changedConn then
				changedConn:Disconnect()
				changedConn = nil
			end

			local loader = ModuleLoader.new()
			local newStories
			local success, result = pcall(function()
				newStories = loadStoriesFromModule(module, storybook, loader)
			end)

			if not isActive then
				return
			end

			setStories(if success then newStories else nil)
			setErr(if success then nil else result)

			changedConn = loader.loadedModuleChanged:Connect(loadStories)
		end

		loadStories()

		return function()
			isActive = false
			if changedConn then
				changedConn:Disconnect()
			end
		end
	end, { module, storybook } :: { unknown })

	return stories, err
end

return useStoriesForModule
