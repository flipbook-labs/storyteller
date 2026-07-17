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
		local pendingTargets = {} :: { [ModuleScript]: StoryModuleTarget }
		local reloadByModule = {} :: { [ModuleScript]: () -> () }
		local sourceConnections = {} :: { [ModuleScript]: RBXScriptConnection }
		local isActive = true
		local isProcessing = false

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

		local function processPendingTargets()
			if isProcessing then
				return
			end
			isProcessing = true

			task.spawn(function()
				while isActive do
					local nextTarget: StoryModuleTarget?
					for storyModule, target in pendingTargets do
						pendingTargets[storyModule] = nil
						nextTarget = target
						break
					end

					if not nextTarget then
						break
					end

					loadTarget(nextTarget)

					-- Some Storybooks contain hundreds of Stories whose
					-- dependencies are expensive to evaluate. Yield after each
					-- snapshot so initial discovery and dependency changes do
					-- not exhaust Studio's script timeout.
					task.wait()
				end

				isProcessing = false
			end)
		end

		local function queueTarget(target: StoryModuleTarget)
			pendingTargets[target.storyModule] = target
			processPendingTargets()
		end

		for _, target in targets do
			local storyModule = target.storyModule
			reloadByModule[storyModule] = debounce(function()
				queueTarget(target)
			end, 50)
			sourceConnections[storyModule] =
				storyModule:GetPropertyChangedSignal("Source"):Connect(reloadByModule[storyModule])
			pendingTargets[storyModule] = target
		end
		processPendingTargets()

		return function()
			isActive = false
			table.clear(pendingTargets)
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
