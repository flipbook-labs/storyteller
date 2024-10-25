local createFusionRenderer = require("@root/renderers/createFusionRenderer")
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
	return createRobloxRenderer()
end

return createRendererForStory
