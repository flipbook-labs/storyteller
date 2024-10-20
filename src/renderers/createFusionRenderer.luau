local Sift = require("@pkg/Sift")

local createRobloxRenderer = require("@root/renderers/createRobloxRenderer")
local types = require("@root/types")

type StoryRenderer<T> = types.StoryRenderer<T>

type Packages = {
	Fusion: any,
}

local function createFusionRenderer(packages: Packages): StoryRenderer<unknown>
	local Fusion = packages.Fusion
	local robloxRenderer = createRobloxRenderer()

	local function transformProps(props, prevProps)
		if props.controls then
			local transformed = table.clone(props)

			transformed.controls = Sift.Dictionary.map(transformed.controls, function(arg, key)
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

	local function shouldUpdate(_props, prevProps)
		-- Arg changes should never trigger a remount. We retain the Value
		-- identities to Fusion can handle its update logic
		if prevProps then
			return false
		end
		return true
	end

	return {
		mount = robloxRenderer.mount,
		unmount = robloxRenderer.unmount,
		shouldUpdate = shouldUpdate,
		transformProps = transformProps,
	}
end

return createFusionRenderer
