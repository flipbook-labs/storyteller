local ModuleLoader = require("@pkg/ModuleLoader")
local Sift = require("@pkg/Sift")

local constants = require("@root/constants")
local loadStorybookModule = require("@root/loadStorybookModule")
local migrateControlsSchema = require("@root/controls/migrateControlsSchema")
local migrateLegacyPackages = require("@root/migrateLegacyPackages")
local types = require("@root/types")

type LoadedStory<T> = types.LoadedStory<T>
type LoadedStorybook = types.LoadedStorybook
type ModuleLoader = ModuleLoader.ModuleLoader
type StoryControlsSchema = types.StoryControlsSchema
type StoryDefinitionSource = types.StoryDefinitionSource
type StoryGroupSource = types.StoryGroupSource
type StoryProps = types.StoryProps
type UnknownDict = types.UnknownDict

export type LoadedStoryModuleData<T> = {
	name: string,
	stories: { LoadedStory<T> },
}

-- A Story entry after validation and defaults inheritance.
type NormalizedStory = {
	id: string,
	name: string,
	story: unknown,
	summary: string?,
	controls: UnknownDict?,
	packages: UnknownDict?,
	props: UnknownDict?,
	-- Every field the Story source defines, including custom metadata that
	-- Storybook middleware such as `mapDefinition` can read.
	sourceFields: UnknownDict,
}

type NormalizedStoryModule = {
	name: string,
	stories: { NormalizedStory },
}

local function mergeOrNil(defaults: UnknownDict?, overrides: UnknownDict?): UnknownDict?
	if defaults == nil and overrides == nil then
		return nil
	end
	return Sift.Dictionary.merge(defaults, overrides)
end

-- Parses one entry of a Story group's `stories`. Entries that are not tables are
-- shorthand for `{ story = entry }`.
--
-- `fallbackDescription` identifies the entry when it has no usable id or name,
-- such as `at index 2` for an array entry.
local function parseStoryEntry(
	entry: unknown,
	storyModule: ModuleScript,
	fallbackDescription: string
): StoryDefinitionSource
	local definition: unknown = if typeof(entry) == "table" then entry else { story = entry }
	local isValid, message = types.IStoryDefinitionSource(definition)
	if not isValid then
		local fields = definition :: UnknownDict
		local label = fields.id or fields.name
		local description = if typeof(label) == "string" then `"{label}"` else fallbackDescription
		error(
			`Story {description} is malformed. Check the source of {storyModule:GetFullName()} and make sure its `
				.. `properties are correct. Error: {message}`
		)
	end
	-- The schema check above guarantees this shape.
	return definition :: StoryDefinitionSource
end

local function inheritDefaults(
	entry: StoryDefinitionSource,
	defaults: StoryGroupSource?,
	id: string,
	name: string
): NormalizedStory
	local sourceFields: UnknownDict = Sift.Dictionary.merge(defaults, entry, { stories = Sift.None })
	return {
		id = id,
		name = name,
		story = entry.story,
		summary = entry.summary or (defaults and defaults.summary),
		controls = mergeOrNil(defaults and defaults.controls, entry.controls),
		packages = mergeOrNil(defaults and defaults.packages, entry.packages) or migrateLegacyPackages(sourceFields),
		props = mergeOrNil(defaults and defaults.props, entry.props),
		sourceFields = sourceFields,
	}
end

local function normalizeStoryModule(requiredStory: unknown, storyModule: ModuleScript): NormalizedStoryModule
	local moduleName = storyModule.Name:gsub(constants.STORY_NAME_PATTERN, "")

	if typeof(requiredStory) == "function" then
		local callback = requiredStory :: (container: Instance, props: StoryProps) -> unknown
		return {
			name = moduleName,
			stories = {
				{
					id = "default",
					name = moduleName,
					story = function(props: StoryProps)
						return callback(props.container, props)
					end,
					-- Hoarcekat Stories manage their own rendering.
					packages = {},
					sourceFields = {},
				},
			},
		}
	end

	local isValid, message = types.IStoryModuleSource(requiredStory)
	if not isValid then
		error(
			`Story is malformed. Check the source of {storyModule:GetFullName()} and make sure its properties are `
				.. `correct. Error: {message}`
		)
	end

	-- The schema check above guarantees a table matching one of the Story
	-- module shapes, and the checks below decide which one.
	local fields = requiredStory :: UnknownDict
	if fields.story ~= nil and fields.stories ~= nil then
		error("Story is malformed. A Story module cannot define both `story` and `stories`")
	end

	if fields.stories == nil then
		local definition = requiredStory :: StoryDefinitionSource
		local id = definition.id or definition.name or "default"
		return {
			name = moduleName,
			stories = { inheritDefaults(definition, nil, id, definition.name or moduleName) },
		}
	end

	local group = requiredStory :: StoryGroupSource
	local normalized: { NormalizedStory } = {}

	if Sift.Array.is(group.stories) then
		for index, entry in group.stories do
			local fallback = tostring(index)
			local definition = parseStoryEntry(entry, storyModule, `at index {index}`)
			local id = definition.id or definition.name or fallback
			table.insert(normalized, inheritDefaults(definition, group, id, definition.name or fallback))
		end
	else
		local keys: { string } = {}
		for key in group.stories do
			if typeof(key) ~= "string" then
				error("Story is malformed. `stories` must be an array or a dictionary with string keys")
			end
			table.insert(keys, key)
		end

		table.sort(keys, function(a, b)
			local lowerA, lowerB = a:lower(), b:lower()
			return if lowerA == lowerB then a < b else lowerA < lowerB
		end)
		for _, key in keys do
			local definition = parseStoryEntry(group.stories[key], storyModule, `"{key}"`)
			table.insert(normalized, inheritDefaults(definition, group, definition.id or key, definition.name or key))
		end
	end

	if #normalized == 0 then
		error("Story is malformed. `stories` must contain at least one story")
	end

	local seenIds: { [string]: boolean } = {}
	for _, story in normalized do
		if seenIds[story.id] then
			error(`Story is malformed. Story id "{story.id}" is duplicated in {storyModule:GetFullName()}`)
		end
		seenIds[story.id] = true
	end

	return {
		name = group.name or moduleName,
		stories = normalized,
	}
end

local function loadStoryModuleData<T>(
	storyModule: ModuleScript,
	storybook: LoadedStorybook,
	providedLoader: ModuleLoader?
): LoadedStoryModuleData<T>
	local loader = providedLoader or ModuleLoader.new()

	local freshStorybook: LoadedStorybook?
	pcall(function()
		freshStorybook = loadStorybookModule(storybook.source, loader)
	end)
	local loadedStorybook = freshStorybook or storybook

	local requiredStory: unknown
	local success, err = pcall(function()
		requiredStory = loader:require(storyModule)
	end)
	if not success then
		error(`Failed to load story {storyModule:GetFullName()}. Error: {err}`)
	end

	local storyModuleData = normalizeStoryModule(requiredStory, storyModule)
	local loadedStories: { LoadedStory<T> } = {}

	for _, normalizedStory in storyModuleData.stories do
		local controls = normalizedStory.controls :: StoryControlsSchema?
		if controls then
			controls = migrateControlsSchema(controls)
		end

		local loadedStory: LoadedStory<T> = {
			id = normalizedStory.id,
			name = normalizedStory.name,
			storybook = loadedStorybook,
			source = storyModule,
			story = normalizedStory.story :: T | (props: StoryProps) -> T,
			packages = normalizedStory.packages or loadedStorybook.packages,
			summary = normalizedStory.summary,
			controls = controls,
			props = normalizedStory.props,
		}
		table.insert(loadedStories, Sift.Dictionary.merge(normalizedStory.sourceFields, loadedStory))
	end

	return {
		name = storyModuleData.name,
		stories = loadedStories,
	}
end

return loadStoryModuleData
