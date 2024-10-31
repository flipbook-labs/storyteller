local types = require("@root/types")

type Story<T> = types.Story<T>
type StoryRenderer<T> = types.StoryRenderer<T>
type LegacyFunctionalStory = <T>(target: Instance, props: types.StoryProps) -> (() -> ())?

--[[
	Renders manual stories in the form:

	```lua
	story = function(target, props)
		local gui = Instance.new("TextLabel")
		gui.Text = props.controls.text
		gui.Parent = target

		return function()
			gui:Destroy()
		end
	end
	```
]]
local function createLegacyFunctionalStoryRenderer(): StoryRenderer<LegacyFunctionalStory>
	local currentContainer
	local currentStory
	local cleanup: (() -> ())?

	local function mount(container, story, initialProps)
		cleanup = story.story(container, initialProps)
		currentContainer = container
		currentStory = story
	end

	local function unmount()
		if cleanup then
			cleanup()
			cleanup = nil
		end
	end

	local function update(controls)
		unmount()
		mount(currentContainer, currentStory, controls)
	end

	return {
		mount = mount,
		update = update,
		unmount = unmount,
	}
end

return createLegacyFunctionalStoryRenderer
