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
type StoryProps = types.StoryProps

export type LoadedStoryModuleData<T> = {
	name: string,
	stories: { LoadedStory<T> },
}

type RawStory = { [string]: unknown }
type StoryMap = { [string]: unknown }

-- A Story entry after validation and defaults inheritance. `fields` keeps the
-- merged table so legacy package keys can still be migrated.
type NormalizedStory = {
	id: string,
	name: string,
	story: unknown,
	summary: string?,
	controls: StoryMap?,
	packages: StoryMap?,
	props: StoryMap?,
	fields: RawStory,
}

local function mergeField(defaults: unknown, overrides: unknown): StoryMap?
	if defaults == nil and overrides == nil then
		return nil
	end
	return Sift.Dictionary.merge(defaults, overrides)
end

local function toRawStory(entry: unknown): RawStory
	if typeof(entry) == "table" then
		return table.clone(entry :: RawStory)
	end
	return { story = entry }
end

-- Both tables must already have passed story validation, which guarantees the
-- shapes of the fields read here.
local function inheritDefaults(entry: RawStory, defaults: RawStory, id: string, name: string): NormalizedStory
	local fields: RawStory = Sift.Dictionary.merge(defaults, entry)
	return {
		id = id,
		name = name,
		story = fields.story,
		summary = fields.summary :: string?,
		controls = mergeField(defaults.controls, entry.controls),
		packages = mergeField(defaults.packages, entry.packages),
		props = mergeField(defaults.props, entry.props),
		fields = fields,
	}
end

local function validateStoryDefinition(story: RawStory, storyModule: ModuleScript, fallbackLabel: string)
	local isValid, message = types.IStoryDefinition(story)
	if not isValid then
		local label = story.id or story.name
		error(
			`Story "{if typeof(label) == "string" then label else fallbackLabel}" is malformed. Check the source of `
				.. `{storyModule:GetFullName()} and make sure its properties are correct. Error: {message}`
		)
	end
end

local function normalizeStoryModule(
	requiredStory: unknown,
	storyModule: ModuleScript
): (string, { NormalizedStory }, boolean)
	local moduleName = storyModule.Name:gsub(constants.STORY_NAME_PATTERN, "")

	if typeof(requiredStory) == "function" then
		local callback = requiredStory :: (container: Instance, props: StoryProps) -> unknown
		local story: NormalizedStory = {
			id = "default",
			name = moduleName,
			story = function(props: StoryProps)
				return callback(props.container, props)
			end,
			fields = {},
		}
		return moduleName, { story }, true
	end

	local isValid, message = types.IStory(requiredStory)
	if not isValid then
		error(
			`Story is malformed. Check the source of {storyModule:GetFullName()} and make sure its properties are `
				.. `correct. Error: {message}`
		)
	end

	local module = requiredStory :: RawStory
	local moduleStoryName = module.name :: string?
	if module.story ~= nil and module.stories ~= nil then
		error("Story is malformed. A Story module cannot define both `story` and `stories`")
	end

	if module.stories == nil then
		local id = module.id :: string? or moduleStoryName or "default"
		return moduleName, { inheritDefaults(module, {}, id, moduleStoryName or moduleName) }, false
	end

	local defaults = table.clone(module)
	defaults.id = nil
	defaults.name = nil
	defaults.story = nil
	defaults.stories = nil

	local stories = module.stories :: { [unknown]: unknown }
	local normalized: { NormalizedStory } = {}

	if Sift.Array.is(stories) then
		for index, entry in stories :: { unknown } do
			local raw = toRawStory(entry)
			local fallback = tostring(index)
			validateStoryDefinition(raw, storyModule, fallback)
			local name = raw.name :: string?
			local id = raw.id :: string? or name or fallback
			table.insert(normalized, inheritDefaults(raw, defaults, id, name or fallback))
		end
	else
		local keys = Sift.Dictionary.keys(stories)
		if not Sift.Array.every(keys, function(key)
			return typeof(key) == "string"
		end) then
			error("Story is malformed. `stories` must be an array or a dictionary with string keys")
		end

		local sortedKeys = Sift.Array.sort(keys :: { string }, function(a, b)
			local lowerA, lowerB = a:lower(), b:lower()
			return if lowerA == lowerB then a < b else lowerA < lowerB
		end)
		for _, key in sortedKeys do
			local raw = toRawStory(stories[key])
			validateStoryDefinition(raw, storyModule, key)
			local id = raw.id :: string? or key
			local name = raw.name :: string? or key
			table.insert(normalized, inheritDefaults(raw, defaults, id, name))
		end
	end

	if #normalized == 0 then
		error("Story is malformed. `stories` must contain at least one story")
	end

	return moduleStoryName or moduleName, normalized, false
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

	local groupName, normalizedStories, isLegacyStory = normalizeStoryModule(requiredStory, storyModule)
	local loadedStories: { LoadedStory<T> } = {}
	local seenIds: { [string]: boolean } = {}

	for _, normalizedStory in normalizedStories do
		local id = normalizedStory.id
		if seenIds[id] then
			error(`Story is malformed. Story id "{id}" is duplicated in {storyModule:GetFullName()}`)
		end
		seenIds[id] = true

		local controls = normalizedStory.controls :: StoryControlsSchema?
		if controls then
			controls = migrateControlsSchema(controls)
		end

		local packages = if isLegacyStory
			then {}
			else normalizedStory.packages or migrateLegacyPackages(normalizedStory.fields) or loadedStorybook.packages

		table.insert(loadedStories, {
			id = id,
			name = normalizedStory.name,
			storybook = loadedStorybook,
			source = storyModule,
			story = normalizedStory.story :: T | (props: StoryProps) -> T,
			packages = packages,
			summary = normalizedStory.summary,
			controls = controls,
			props = normalizedStory.props,
		})
	end

	return {
		name = groupName,
		stories = loadedStories,
	}
end

return loadStoryModuleData
