local createFusionRenderer = require("@root/renderers/createFusionRenderer")
local createIrisRenderer = require("@root/renderers/createIrisRenderer")
local createManualRenderer = require("@root/renderers/createManualRenderer")
local createReactRenderer = require("@root/renderers/createReactRenderer")
local createRoactRenderer = require("@root/renderers/createRoactRenderer")
local createVideRenderer = require("@root/renderers/createVideRenderer")
local types = require("@root/types")

type LoadedStory<T> = types.LoadedStory<T>
type StoryRenderer<T> = types.StoryRenderer<T>

--[[
	This function will do its best to determine which of the renderers to use
	based off the Story’s properties.

	Each renderer is given its own file so that it’s easy to add on new UI
	libraries in the future. See [Story Renderer Spec](https://www.notion.so/Story-Renderer-Spec-4260feeab4574ad68f87006dee57cf75?pvs=21) for more details.

	@tag Rendering
	@tag Story
	@within Storyteller
]]
local function createRendererForStory<T>(story: LoadedStory<T>): StoryRenderer<T>
	local packages = if story.packages then story.packages else story.storybook.packages
	local renderer: unknown

	if packages then
		if packages.Roact then
			renderer = createRoactRenderer(packages)
		elseif packages.React and packages.ReactRoblox then
			renderer = createReactRenderer(packages)
		elseif packages.Fusion then
			renderer = createFusionRenderer(packages)
		elseif packages.Vide then
			renderer = createVideRenderer(packages)
		elseif packages.Iris then
			renderer = createIrisRenderer(packages)
		end
	end

	if not renderer then
		renderer = createManualRenderer()
	end

	-- The packages a story brings decide its renderer, and each renderer
	-- expects the kind of story its UI library makes. A story's type can't
	-- express that pairing, so the renderer is cast to match the story here.
	return renderer :: StoryRenderer<T>
end

return createRendererForStory
