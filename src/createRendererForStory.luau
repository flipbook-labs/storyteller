local createFusionRenderer = require("@root/renderers/createFusionRenderer")
local createLegacyFunctionalStoryRenderer = require("@root/renderers/createLegacyFunctionalStoryRenderer")
local createReactRenderer = require("@root/renderers/createReactRenderer")
local createRoactRenderer = require("@root/renderers/createRoactRenderer")
local createRobloxRenderer = require("@root/renderers/createRobloxRenderer")
local types = require("@root/types")

type Story<T> = types.Story<T>
type StoryRenderer<T> = types.StoryRenderer<T>

local function createRendererForStory<T>(story: Story<T>): StoryRenderer<any>
	local packages = if story.packages then story.packages else story.storybook.packages
	if packages then
		if packages.Roact then
			return createRoactRenderer(packages)
		elseif packages.React and packages.ReactRoblox then
			return createReactRenderer(packages)
		elseif packages.Fusion then
			return createFusionRenderer(packages)
		end
	end

	-- For backwards compatability. The older format of functional stories takes
	-- in the parent as the first argument, followed by props. This call to
	-- debug.info lets us know how many args the function takes so we can
	-- conditionally pass in the container to support older stories. This should
	-- be removed in a future major version
	if typeof(story.story) == "function" and debug.info(story.story, "a") >= 2 then
		return createLegacyFunctionalStoryRenderer()
	end

	return createRobloxRenderer()
end

return createRendererForStory
