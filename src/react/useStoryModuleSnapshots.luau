local ModuleLoader = require("@pkg/ModuleLoader")
local React = require("@pkg/React")

local constants = require("@root/constants")
local debounce = require("@root/debounce")
local loadStoryModuleSnapshot = require("@root/loadStoryModuleSnapshot")
local types = require("@root/types")

local useEffect = React.useEffect
local useState = React.useState

type ModuleLoader = ModuleLoader.ModuleLoader
type StoryModuleSnapshot = types.StoryModuleSnapshot
type StoryModuleTarget = types.StoryModuleTarget

type PendingTarget = {
	loader: ModuleLoader?,
	target: StoryModuleTarget,
}

local WORK_BUDGET_SECONDS = 0.004

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
		local initialLoaderConnections = {} :: { [ModuleScript]: RBXScriptConnection }
		local initialLoaders = {} :: { [ModuleScript]: ModuleLoader }
		local initialTargets = {} :: { [ModuleScript]: { [ModuleScript]: StoryModuleTarget } }
		local loaderConnections = {} :: { [ModuleScript]: RBXScriptConnection }
		local pendingTargets = {} :: { [ModuleScript]: PendingTarget }
		local reloadByModule = {} :: { [ModuleScript]: () -> () }
		local sourceConnections = {} :: { [ModuleScript]: RBXScriptConnection }
		local isActive = true
		local isProcessing = false

		setSnapshots({})

		local function loadTarget(pendingTarget: PendingTarget): (ModuleScript?, StoryModuleSnapshot?)
			local target = pendingTarget.target
			local storyModule = target.storyModule
			local existingConnection = loaderConnections[storyModule]
			if existingConnection then
				existingConnection:Disconnect()
				loaderConnections[storyModule] = nil
			end

			local loader = if pendingTarget.loader then pendingTarget.loader else ModuleLoader.new()
			local success, result = pcall(function()
				return loadStoryModuleSnapshot(storyModule, target.storybook, loader)
			end)

			if not isActive then
				return nil, nil
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

			-- Shared initial loaders avoid repeatedly evaluating common
			-- dependencies. Source changes are observed separately below; once
			-- a module reloads with an isolated loader, dependency changes can
			-- be tracked without invalidating every module in the Storybook.
			if not pendingTarget.loader then
				loaderConnections[storyModule] = loader.loadedModuleChanged:Connect(reloadByModule[storyModule])
			end

			return storyModule, snapshot
		end

		local function processPendingTargets()
			if isProcessing then
				return
			end
			isProcessing = true

			task.defer(function()
				local pendingSnapshots = {} :: { [ModuleScript]: StoryModuleSnapshot }
				local workStarted = os.clock()

				local function publishSnapshots()
					if not isActive or next(pendingSnapshots) == nil then
						return
					end

					local snapshotsToPublish = pendingSnapshots
					pendingSnapshots = {}
					setSnapshots(function(previous)
						local nextSnapshots = table.clone(previous)
						for storyModule, snapshot in snapshotsToPublish do
							nextSnapshots[storyModule] = snapshot
						end
						return nextSnapshots
					end)
				end

				while isActive do
					local nextTarget: PendingTarget?
					for storyModule, pendingTarget in pendingTargets do
						pendingTargets[storyModule] = nil
						nextTarget = pendingTarget
						break
					end

					if not nextTarget then
						break
					end

					local storyModule, snapshot = loadTarget(nextTarget)
					if storyModule and snapshot then
						pendingSnapshots[storyModule] = snapshot
					end

					-- Some Storybooks contain hundreds of Stories whose
					-- dependencies are expensive to evaluate. Use a small work
					-- budget to load cheap modules together while still
					-- yielding before Studio's UI becomes unresponsive.
					if os.clock() - workStarted >= WORK_BUDGET_SECONDS then
						publishSnapshots()
						task.wait()
						workStarted = os.clock()
					end
				end

				publishSnapshots()
				isProcessing = false
			end)
		end

		local function queueTarget(target: StoryModuleTarget)
			pendingTargets[target.storyModule] = {
				target = target,
			}
			processPendingTargets()
		end

		for _, target in targets do
			local storyModule = target.storyModule
			reloadByModule[storyModule] = debounce(function()
				queueTarget(target)
			end, 50)
			sourceConnections[storyModule] =
				storyModule:GetPropertyChangedSignal("Source"):Connect(reloadByModule[storyModule])

			local initialLoader = initialLoaders[target.storybook.source]
			if not initialLoader then
				initialLoader = ModuleLoader.new()
				initialLoaders[target.storybook.source] = initialLoader
				initialTargets[target.storybook.source] = {}
			end
			initialTargets[target.storybook.source][storyModule] = target
			pendingTargets[storyModule] = {
				loader = initialLoader,
				target = target,
			}
		end

		for storybookSource, loader in initialLoaders do
			initialLoaderConnections[storybookSource] = loader.loadedModuleChanged:Connect(function(changedModule)
				local targetsForStorybook = initialTargets[storybookSource]
				local changedTarget = targetsForStorybook[changedModule]
				if changedTarget then
					queueTarget(changedTarget)
				else
					for _, target in targetsForStorybook do
						queueTarget(target)
					end
				end
			end)
		end
		processPendingTargets()

		return function()
			isActive = false
			table.clear(pendingTargets)
			for _, connection in initialLoaderConnections do
				connection:Disconnect()
			end
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
