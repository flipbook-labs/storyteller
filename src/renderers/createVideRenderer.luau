local types = require("@root/types")

type LoadedStory<T> = types.LoadedStory<T>
type StoryProps = types.StoryProps
type StoryRenderer<T> = types.StoryRenderer<T>

type Packages = {
	Vide: any,
}

local function createVideRenderer(packages: Packages): StoryRenderer<Instance>
	local Vide = packages.Vide

	local prevProps: StoryProps? = nil
	local unmount: (() -> ())? = nil

	local function transformProps(props: StoryProps)
		local transformed = table.clone(props)

		transformed.controls = {}

		for key, control in props.controls do
			local prevControl = if prevProps ~= nil and prevProps.controls ~= nil then prevProps.controls[key] else nil

			if prevControl ~= nil then
				transformed.controls[key] = prev
			else
				transformed.controls[key] = Vide.source(control)
			end
		end

		return transformed
	end

	local function mount(container: Instance, story: LoadedStory<Instance>, props: StoryProps)
		props = transformProps(props)
		prevProps = props

		unmount = Vide.mount(story.story(props), container)
	end

	local function update(props: StoryProps)
		if prevProps ~= nil then
			for key, control in props.controls do
				local prevControl = prevProps.controls[key]

				if prevControl ~= nil then
					prevControl(control)
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

return createVideRenderer
