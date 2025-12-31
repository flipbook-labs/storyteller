local controls = require("@self/controls")
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
export type StoryProps = types.StoryProps
export type StoryRenderer<T> = types.StoryRenderer<T>

export type BooleanControl = controls.BooleanControl
export type CheckControl<T> = controls.CheckControl<T>
export type ColorControl = controls.ColorControl
export type ColourControl = controls.ColourControl
export type DateControl = controls.DateControl
export type MultiSelectControl<T> = controls.MultiSelectControl<T>
export type NumberControl = controls.NumberControl
export type RadioControl<T> = controls.RadioControl<T>
export type SelectControl<T> = controls.SelectControl<T>
export type SliderControl = controls.SliderControl
export type StringControl = controls.StringControl
export type StoryControl = controls.StoryControl
export type StoryControlsSchema = controls.StoryControlsSchema
export type StoryControls = controls.StoryControls
export type ControlType = controls.ControlType

return {
	-- Validation
	isStorybookModule = require("@self/isStoryModule"),
	isStoryModule = require("@self/isStoryModule"),

	-- Discovery
	findStorybookModules = require("@self/findStorybookModules"),
	findStoryModulesForStorybook = require("@self/findStoryModulesForStorybook"),
	findOrphanedStoryModules = require("@self/findOrphanedStoryModules"),

	-- Module loading
	loadStoryModule = require("@self/loadStoryModule"),
	loadStorybookModule = require("@self/loadStorybookModule"),

	-- Rendering
	render = require("@self/render"),

	-- React
	StoryContainer = require("@self/react/StoryContainer"),
	useStory = require("@self/react/useStory"),
	useStorybooks = require("@self/react/useStorybooks"),
	useOrphanedStoryModules = require("@self/react/useOrphanedStoryModules"),

	-- Enums
	ControlType = controls.ControlType,

	-- Controls
	boolean = controls.createBooleanControl,
	check = controls.createCheckControl,
	choose = controls.createSelectControl,
	color = controls.createColorControl,
	date = controls.createDateControl,
	multiChoose = controls.createMultiSelectControl,
	number = controls.createNumberControl,
	radio = controls.createRadioControl,
	slider = controls.createSliderControl,
	text = controls.createStringControl,
}
