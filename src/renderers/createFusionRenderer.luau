local Sift = require("@pkg/Sift")

local types = require("@root/types")

type LoadedStory<T> = types.LoadedStory<T>
type StoryProps = types.StoryProps
type StoryRenderer<T> = types.StoryRenderer<T>

type Packages = {
	Fusion: any,
}

local function createFusionRenderer(packages: Packages): StoryRenderer<Instance>
	local Fusion = packages.Fusion

	local handle: Instance?
	local scope
	local prevProps: StoryProps?

	local function transformProps(props: StoryProps)
		local transformed = table.clone(props)

		if not scope and rawget(Fusion, "scoped") then
			-- Fusion V3
			scope = Fusion:scoped()
		end

		transformed.controls = Sift.Dictionary.map(props.controls, function(arg, key)
			local prevControl = if prevProps and prevProps.controls then prevProps.controls[key] else nil

			if prevControl ~= nil then
				return prevControl
			else
				return if scope then scope:Value(arg) else Fusion.Value(arg)
			end
		end)

		return transformed
	end

	local function mount(container: Instance, story: LoadedStory<Instance>, props: StoryProps)
		props = transformProps(props)
		prevProps = props

		if typeof(story.story) == "Instance" then
			handle = story.story
		elseif typeof(story.story) == "function" then
			handle = story.story(props)
		end

		if handle then
			handle.Parent = container
		end
	end

	local function unmount()
		if handle then
			handle:Destroy()
		end
		if scope then
			scope:doCleanup()
		end
	end

	local function update(props: StoryProps)
		-- Fusion needs to retain its Instance identity. Instead of remounting,
		-- we leave `handle` alone and mutate the controls with the newly
		-- updated values
		if prevProps then
			for key, value in props.controls do
				local prevControl = prevProps.controls[key]

				if prevControl ~= nil then
					prevControl:set(value)
				end
			end
		end

		return nil
	end

	return {
		mount = mount,
		unmount = unmount,
		update = update,
	}
end

return createFusionRenderer
