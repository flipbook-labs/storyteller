local types = require("@root/types")

type LoadedStory<T> = types.LoadedStory<T>
type StoryControls = types.StoryControls
type StoryProps = types.StoryProps
type StoryRenderer<T> = types.StoryRenderer<T>

type Packages = {
	Vide: any,
}

type VideSource = (unknown) -> unknown
type VideSources = { [string]: VideSource }

local function createVideRenderer(packages: Packages): StoryRenderer<Instance>
	local Vide = packages.Vide

	local prevProps: StoryProps? = nil
	local stopVide: (() -> ())? = nil

	local function transformProps(props: StoryProps)
		local transformed = table.clone(props)

		local prevControls: VideSources? = if prevProps ~= nil then prevProps.controls :: VideSources? else nil
		local sources: VideSources = {}

		for key, control in props.controls :: StoryControls do
			local prevControl = if prevControls ~= nil then prevControls[key] else nil

			if prevControl ~= nil then
				sources[key] = prevControl
			else
				sources[key] = Vide.source(control)
			end
		end

		transformed.controls = sources

		return transformed
	end

	local function mount(container: Instance, story: LoadedStory<Instance>, props: StoryProps)
		props = transformProps(props)
		prevProps = props

		local mapDefinition = if story.storybook then story.storybook.mapDefinition else nil

		if mapDefinition then
			story = mapDefinition(story) :: LoadedStory<Instance>
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
			local prevControls = prevProps.controls :: VideSources

			Vide.batch(function()
				for key, control in props.controls :: StoryControls do
					local prevControl = prevControls[key]

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
