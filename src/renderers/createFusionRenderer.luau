local Sift = require("@pkg/Sift")

local createRobloxRenderer = require("@root/renderers/createRobloxRenderer")
local types = require("@root/types")

type Story<T> = types.Story<T>
type StoryProps<T> = types.StoryProps<T>
type StoryRenderer<T> = types.StoryRenderer<T>

type Packages = {
	Fusion: any,
}

local function createFusionRenderer(packages: Packages): StoryRenderer<Instance>
	local Fusion = packages.Fusion
	local robloxRenderer = createRobloxRenderer()

	local function mount(container: Instance, story: Story<Instance>, initialProps: StoryProps<Instance>)
		return robloxRenderer.mount(container, story, initialProps)
	end

	local function unmount()
		if robloxRenderer.unmount then
			robloxRenderer.unmount()
		end
	end

	local function shouldUpdate(_props: StoryProps<Instance>, prevProps: StoryProps<Instance>?)
		-- Arg changes should never trigger a remount. We retain the Value
		-- identities to Fusion can handle its update logic
		if prevProps then
			return false
		end
		return true
	end

	local function transformProps(props: StoryProps<Instance>, prevProps: StoryProps<Instance>?)
		if props.controls then
			local transformed = table.clone(props)

			transformed.controls = Sift.Dictionary.map(props.controls, function(arg, key)
				-- Retain Fusion.Value identities and update the internal value
				-- with the new arg's value
				local prevControl = if prevProps and prevProps.controls then prevProps.controls[key] else nil
				if prevControl then
					prevControl:set(arg)
					return prevControl
				else
					return Fusion.Value(arg)
				end
			end)

			return transformed
		end

		return props
	end

	return {
		mount = mount,
		unmount = unmount,
		shouldUpdate = shouldUpdate,
		transformProps = transformProps,
	}
end

return createFusionRenderer
