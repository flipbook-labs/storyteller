local types = require("@root/types")

type StoryRenderer<T> = types.StoryRenderer<T>

type Packages = {
	Roact: any,
}

local function isRoactElement(maybeElement: any): boolean
	if typeof(maybeElement) == "table" then
		return maybeElement.component and maybeElement.props
	end
	return false
end

local function createRoactRenderer(packages: Packages): StoryRenderer<unknown>
	local Roact = packages.Roact
	local tree
	local currentComponent

	local function mount(container, story, props)
		local element

		if isRoactElement(story.story) then
			currentComponent = story.story.component
			element = story.story
		else
			currentComponent = story.story
			element = Roact.createElement(currentComponent, props)
		end

		tree = Roact.mount(element, container, "RoactRenderer")
	end

	local function update(props)
		if tree and currentComponent then
			local element = Roact.createElement(currentComponent, props)
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
