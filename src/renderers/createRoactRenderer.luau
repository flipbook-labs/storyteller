local types = require("@root/types")

type StoryRenderer<T> = types.StoryRenderer<T>

type Packages = {
	Roact: any,
}

local function createRoactRenderer(packages: Packages): StoryRenderer<unknown>
	local Roact = packages.Roact
	local tree
	local currentElement

	local function mount(container, story, props)
		if typeof(story.story) == "function" then
			currentElement = Roact.createElement(story.story, props)
		else
			currentElement = story.story
		end
		tree = Roact.mount(currentElement, container, "RoactRenderer")
	end

	local function update(props)
		if tree and currentElement then
			local element = Roact.createElement(currentElement, props)
			Roact.update(tree, element)
		end
	end

	local function unmount()
		if tree then
			Roact.unmount(tree)
		end
	end

	return {
		mount = mount,
		update = update,
		unmount = unmount,
	}
end

return createRoactRenderer
