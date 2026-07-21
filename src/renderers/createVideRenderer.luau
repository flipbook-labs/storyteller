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
	local stopVide: (() -> ())? = nil

	local function transformProps(props: StoryProps)
		local transformed = table.clone(props)

		transformed.controls = {}

		for key, control in props.controls do
			local prevControl = if prevProps ~= nil and prevProps.controls ~= nil then prevProps.controls[key] else nil

			if prevControl ~= nil then
				transformed.controls[key] = prevControl
			else
				transformed.controls[key] = Vide.source(control)
			end
		end

		return transformed
	end

	local function mount(container: Instance, story: LoadedStory<Instance>, props: StoryProps)
		props = transformProps(props)
		prevProps = props

		local mapDefinition = if story.storybook then story.storybook.mapDefinition else nil

		if mapDefinition then
			story = mapDefinition(story)
		end

		local mapStory = if story.storybook then story.storybook.mapStory else nil

		stopVide = Vide.mount(function()
			if mapStory then
				return mapStory(story.story)(props)
			elseif typeof(story.story) == "Instance" then
				return story.story
			else
				return story.story(props)
			end
		end, container)
	end

	local function update(props: StoryProps)
		if prevProps ~= nil then
			Vide.batch(function()
				for key, control in props.controls do
					local prevControl = prevProps.controls[key]

					if prevControl ~= nil then
						prevControl(control)
					end
				end
			end)
		end
	end

	local function unmount()
		if stopVide then
			stopVide()
			stopVide = nil
		end
		prevProps = nil
	end

	return {
		mount = mount,
		unmount = unmount,
		update = update,
	}
end

return createVideRenderer
