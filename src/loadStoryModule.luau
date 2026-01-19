local ModuleLoader = require("@pkg/ModuleLoader")
local Sift = require("@pkg/Sift")

local constants = require("@root/constants")
local migrateControlsSchema = require("@root/controls/migrateControlsSchema")
local migrateLegacyPackages = require("@root/migrateLegacyPackages")
local types = require("@root/types")

type StoryPackages = types.StoryPackages
type LoadedStorybook = types.LoadedStorybook
type LoadedStory<T> = types.LoadedStory<T>

--[=[
	Loads the source of a Story module.

	A [ModuleLoader](https://github.com/flipbook-labs/module-loader) instance is
	used under the hood for handling the requiring of the Story module.

	This function will throw if the return value of `storyModule` does not
	conform to the [Story format](/docs/story-format#story), or if the source
	has a syntax error that `require` would normally fail for.

	For legacy compatibility this function also loads [Hoarcekat](https://github.com/Kampfkarren/hoarcekat)
	stories. Instead of a usual table-based Story definition, it takes the
	returned function and  wraps it in a Story, making the `story` field the
	function body.

	@tag Story
	@tag Module Loading
	@within Storyteller
]=]
local function loadStoryModule<T>(
	storyModule: ModuleScript,
	storybook: LoadedStorybook,
	loader: ModuleLoader.ModuleLoader?
): LoadedStory<T>
	local loaderOrDefault = if loader then loader else ModuleLoader.new()

	local success, err = pcall(function()
		loaderOrDefault:require(storybook.source)
	end)

	if not success then
		error(`Failed to load story {storyModule:GetFullName()}. Error: {err})`)
	end

	local requiredStory
	success, err = pcall(function()
		requiredStory = loaderOrDefault:require(storyModule)
	end)

	if not success then
		error(`Failed to load story {storyModule:GetFullName()}. Error: {err})`)
	end

	local isLegacyStory = typeof(requiredStory) == "function"

	-- Support for Hoarcekat stories
	if isLegacyStory then
		local callback = requiredStory
		requiredStory = {
			story = function(props)
				return callback(props.container, props)
			end,
		}
	end

	do
		-- Roblox internal. This behavior may be substantially changed or
		-- removed in the future. We need support for substories to be
		-- compatible with Developer Storybook, so we're just selecting a
		-- randomly accessed one but ideally we should be able to render them
		-- all out
		if requiredStory.stories and not requiredStory.story then
			local randomSubstory
			for _, substory in requiredStory.stories do
				randomSubstory = substory
				break
			end
			if typeof(randomSubstory) == "table" then
				requiredStory.story = randomSubstory.story
			else
				requiredStory.story = randomSubstory
			end
		end
	end

	if requiredStory.controls then
		requiredStory.controls = migrateControlsSchema(requiredStory.controls)
	end

	local isValid, message = types.IStory(requiredStory)

	if not isValid then
		error(
			`Story is malformed. Check the source of {storyModule:GetFullName()} and make sure its properties are `
				.. `correct. Error: {message}`
		)
	end

	local story: types.Story<T> = requiredStory

	local packages = migrateLegacyPackages(story)
	if not packages then
		packages = storybook.packages
	end

	local loadedStory: types.LoadedStory<T> = {
		name = storyModule.Name:gsub(constants.STORY_NAME_PATTERN, ""),
		storybook = storybook,
		source = storyModule,
		story = story.story,
		packages = if isLegacyStory then {} else packages,
	}

	return Sift.Dictionary.merge(loadedStory, story)
end

return loadStoryModule
