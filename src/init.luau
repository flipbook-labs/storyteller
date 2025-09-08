local types = require("@self/types")

--[=[
	Storyteller is a library for the discovery and rendering of UI stories and
	powers our storybook plugin [Flipbook](https://github.com/flipbook-labs/flipbook).

	The API for this package focuses around the following areas:

	1. **Validation** for the [Story](/docs/reference/story-format#story) format and [Storybook](/docs/reference/story-format#storybook) format
	2. **Discovery** of valid ModuleScripts with `.story` and `.storybook` extensions
	3. **Loading** of Stories and Storybooks into a sandbox with cacheless module requiring
	4. **Rendering** stories into a container with lifecycle callbacks for updating and unmounting

	There also exist React hooks for ease of integration into storybook apps.

	@class Storyteller
]=]

export type RenderLifecycle = types.RenderLifecycle
export type Story<T> = types.Story<T>
export type LoadedStory<T> = types.LoadedStory<T>
export type Storybook = types.Storybook
export type LoadedStorybook = types.LoadedStorybook
export type UnavailableStorybook = types.UnavailableStorybook
export type StoryControls = types.StoryControls
export type StoryProps = types.StoryProps
export type StoryRenderer<T> = types.StoryRenderer<T>

return {
	-- Validation
	isStorybookModule = require("@self/isStoryModule"),
	isStoryModule = require("@self/isStoryModule"),

	-- Discovery
	findStorybookModules = require("@self/findStorybookModules"),
	findStoryModulesForStorybook = require("@self/findStoryModulesForStorybook"),

	-- Module loading
	loadStoryModule = require("@self/loadStoryModule"),
	loadStorybookModule = require("@self/loadStorybookModule"),

	-- Rendering
	render = require("@self/render"),

	-- Hooks
	useStory = require("@self/hooks/useStory"),
	useStorybooks = require("@self/hooks/useStorybooks"),
}
