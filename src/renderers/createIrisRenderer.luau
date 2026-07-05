local types = require("@root/types")

type StoryProps = types.StoryProps
type LoadedStory<T> = types.LoadedStory<T>
type StoryRenderer<T> = types.StoryRenderer<T>

type IrisStory = (props: StoryProps) -> ()

type Packages = {
	Iris: any,
}

--[[
	Iris is an immediate-mode UI library, so unlike the retained-mode renderers
	it re-runs its connected callback every frame and reads state inline. There
	are a few consequences this renderer has to account for:

	- `Iris.Init` is a one-time global singleton and `Iris.Shutdown` is
	  irreversible, so we initialise lazily on the first mount and re-point Iris
	  at the new container on subsequent mounts instead of re-initialising.
	- `Iris` errors each frame unless its parent is a `GuiBase2d`, but our
	  containers are plain Folders, so we render into a Frame placed under the
	  container.
	- Controls are passed through as raw values; the story reads them every
	  frame, so `update` simply swaps the props the callback closes over.
]]
local function createIrisRenderer(packages: Packages): StoryRenderer<IrisStory>
	local Iris = packages.Iris

	local wrapper: Instance?
	local disconnect: (() -> ())?
	local currentProps: StoryProps

	local function mount(container: Instance, story: LoadedStory<IrisStory>, props: StoryProps)
		currentProps = props

		-- Iris requires a GuiBase2d parent, but the container may be a plain
		-- Folder, so we render into a Frame that fills the container.
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundTransparency = 1
		frame.Parent = container
		wrapper = frame

		if not Iris.Internal._started then
			-- `allowMultipleInits` guards against errors if Iris was already
			-- initialised elsewhere (e.g. by the host application).
			Iris.Init(frame, nil, true)
		else
			-- Iris can only be initialised once, so re-point the existing
			-- instance at the new container and regenerate its root.
			Iris.Internal.parentInstance = frame
			Iris.ForceRefresh()
		end

		Iris.Disabled = false

		disconnect = Iris:Connect(function()
			if typeof(story.story) == "function" then
				(story :: any).story(currentProps)
			end
		end)
	end

	local function update(props: StoryProps)
		-- Immediate-mode: the connected callback reads `currentProps` every
		-- frame, so swapping it in is all that's needed to re-render.
		currentProps = props
	end

	local function unmount()
		if disconnect then
			disconnect()
			disconnect = nil
		end

		-- Freeze Iris so the global cycle doesn't regenerate a root into the
		-- container after we've torn it down. This is a singleton flag, so it
		-- also pauses any host-app Iris UI running in the same session.
		Iris.Disabled = true

		if wrapper then
			wrapper:Destroy()
			wrapper = nil
		end
	end

	return {
		mount = mount,
		update = update,
		unmount = unmount,
	}
end

return createIrisRenderer
