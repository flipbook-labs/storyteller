local ModuleLoader = require("@pkg/ModuleLoader")

local loadStoryModuleData = require("@root/loadStoryModuleData")
local types = require("@root/types")

type LoadedStorybook = types.LoadedStorybook
type LoadedStory<T> = types.LoadedStory<T>
type ModuleLoader = ModuleLoader.ModuleLoader

--[=[
	Loads every Story defined by a Story module.

	A Story module can define a single Story, or a group of Stories under
	`stories` as an array or a dictionary. Group-level `summary`, `controls`,
	`packages`, and `props` become defaults for each Story. Stories are returned
	in array order, or sorted by key for dictionaries. See the
	[Story format](/docs/reference/story-format#multiple-stories-in-one-module) for details.

	A [ModuleLoader](https://github.com/flipbook-labs/module-loader) instance is
	used under the hood for handling the requiring of the Story module.

	This function will throw if the module does not conform to the Story
	format, if two Stories share an id, or if the source has a syntax error
	that `require` would normally fail for.

	Legacy [Hoarcekat](https://github.com/Kampfkarren/hoarcekat) stories load as
	a single Story, the same as [Storyteller.loadStoryModule].

	@tag Story
	@tag Module Loading
	@within Storyteller
]=]
local function loadStoriesFromModule<T>(
	storyModule: ModuleScript,
	storybook: LoadedStorybook,
	providedLoader: ModuleLoader?
): { LoadedStory<T> }
	return loadStoryModuleData(storyModule, storybook, providedLoader).stories
end

return loadStoriesFromModule
