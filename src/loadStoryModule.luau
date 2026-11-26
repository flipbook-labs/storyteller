local ModuleLoader = require("@pkg/ModuleLoader")

local loadStoryModuleData = require("@root/loadStoryModuleData")
local types = require("@root/types")

type LoadedStorybook = types.LoadedStorybook
type LoadedStory<T> = types.LoadedStory<T>
type ModuleLoader = ModuleLoader.ModuleLoader

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
	providedLoader: ModuleLoader?
): LoadedStory<T>
	return loadStoryModuleData(storyModule, storybook, providedLoader).stories[1]
end

return loadStoryModule
