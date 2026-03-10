local ModuleLoader = require("@pkg/ModuleLoader")
local Sift = require("@pkg/Sift")

local migrateControlsSchema = require("@root/controls/migrateControlsSchema")
local types = require("@root/types")

local function createStory<T>(partial: {
	story: T,
	[string]: any,
}): types.LoadedStory<T>
	local story: types.LoadedStory<T> = Sift.Dictionary.join({
		name = "Sample",
		source = Instance.new("ModuleScript"),
		storybook = {
			name = "Storybook",
			loader = ModuleLoader.new(),
			source = Instance.new("ModuleScript"),
			storyRoots = {},
		},
	}, partial)

	if story.controls then
		story.controls = migrateControlsSchema(story.controls)
	end

	return story
end

return createStory
