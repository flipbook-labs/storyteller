local ModuleLoader = require("@pkg/ModuleLoader")
local React = require("@pkg/React")

local constants = require("@root/constants")
local debounce = require("@root/debounce")
local loadStoryModuleSnapshot = require("@root/loadStoryModuleSnapshot")
local types = require("@root/types")

local useEffect = React.useEffect
local useState = React.useState

type StoryModuleSnapshot = types.StoryModuleSnapshot
type StoryModuleTarget = types.StoryModuleTarget

--[=[
	Eagerly loads and caches the lightweight metadata needed to build story
	browser nodes. Opening a Story should still use [useStory] or
	[useStoriesForModule] so render-time loading remains cacheless.

	@tag React
	@tag Story
	@within Storyteller
]=]
local function useStoryModuleSnapshots(targets: { StoryModuleTarget }): { [ModuleScript]: StoryModuleSnapshot }
	local snapshots, setSnapshots = useState({} :: { [ModuleScript]: StoryModuleSnapshot })

	useEffect(function()
		local loaderConnections = {} :: { [ModuleScript]: RBXScriptConnection }
		local reloadByModule = {} :: { [ModuleScript]: () -> () }
		local sourceConnections = {} :: { [ModuleScript]: RBXScriptConnection }
		local isActive = true

		setSnapshots({})

		local function loadTarget(target: StoryModuleTarget)
			local storyModule = target.storyModule
			local existingConnection = loaderConnections[storyModule]
			if existingConnection then
				existingConnection:Disconnect()
			end

			local loader = ModuleLoader.new()
			local success, result = pcall(function()
				return loadStoryModuleSnapshot(storyModule, target.storybook, loader)
			end)

			if not isActive then
				return
			end

			local snapshot: StoryModuleSnapshot
			if success then
				snapshot = result
			else
				snapshot = {
					name = storyModule.Name:gsub(constants.STORY_NAME_PATTERN, ""),
					source = storyModule,
					stories = {},
					problem = tostring(result),
				}
			end

			setSnapshots(function(previous)
				local nextSnapshots = table.clone(previous)
				nextSnapshots[storyModule] = snapshot
				return nextSnapshots
			end)

			loaderConnections[storyModule] = loader.loadedModuleChanged:Connect(reloadByModule[storyModule])
		end

		for _, target in targets do
			local storyModule = target.storyModule
			reloadByModule[storyModule] = debounce(function()
				task.spawn(loadTarget, target)
			end, 50)
			sourceConnections[storyModule] = storyModule.Changed:Connect(reloadByModule[storyModule])
			task.spawn(loadTarget, target)
		end

		return function()
			isActive = false
			for _, connection in loaderConnections do
				connection:Disconnect()
			end
			for _, connection in sourceConnections do
				connection:Disconnect()
			end
		end
	end, { targets } :: { unknown })

	return snapshots
end

return useStoryModuleSnapshots
