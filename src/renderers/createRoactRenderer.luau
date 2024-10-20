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
		currentElement = story.story
		local renderedElement = Roact.createElement(story.story, props)
		tree = Roact.mount(renderedElement, container, "RoactRenderer")
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
