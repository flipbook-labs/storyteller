local ControlType = require("@self/controls/enums/ControlType")
local ControlTypes = require("@self/controls/ControlTypes")
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
export type StoryProps = types.StoryProps
export type StoryRenderer<T> = types.StoryRenderer<T>

export type BooleanControl = ControlTypes.BooleanControl
export type CheckControl<T> = ControlTypes.CheckControl<T>
export type ColorControl = ControlTypes.ColorControl
export type ColourControl = ControlTypes.ColourControl
export type DateControl = ControlTypes.DateControl
export type MultiSelectControl<T> = ControlTypes.MultiSelectControl<T>
export type NumberControl = ControlTypes.NumberControl
export type RadioControl<T> = ControlTypes.RadioControl<T>
export type SelectControl<T> = ControlTypes.SelectControl<T>
export type SliderControl = ControlTypes.SliderControl
export type StringControl = ControlTypes.StringControl
export type StoryControl = ControlTypes.StoryControl
export type StoryControlsSchema = ControlTypes.StoryControlsSchema
export type StoryControls = ControlTypes.StoryControls

export type ControlType = ControlType.ControlType

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
	ControlType = ControlType,

	-- Controls
	boolean = require("@self/controls/creators/createBooleanControl"),
	check = require("@self/controls/creators/createCheckControl"),
	choose = require("@self/controls/creators/createSelectControl"),
	color = require("@self/controls/creators/createColorControl"),
	date = require("@self/controls/creators/createDateControl"),
	multiChoose = require("@self/controls/creators/createMultiSelectControl"),
	number = require("@self/controls/creators/createNumberControl"),
	radio = require("@self/controls/creators/createRadioControl"),
	slider = require("@self/controls/creators/createSliderControl"),
	text = require("@self/controls/creators/createStringControl"),
}
