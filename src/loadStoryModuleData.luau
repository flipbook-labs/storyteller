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
type ExtraStoryProps = types.ExtraStoryProps
type Story<T> = types.Story<T>
type StoryControlsSchema = types.StoryControlsSchema
type StoryPackages = types.StoryPackages
type StoryProps = types.StoryProps

export type LoadedStoryModuleData<T> = {
	name: string,
	stories: { LoadedStory<T> },
}

type RawStory = { [string]: unknown }

local function getOptionalString(story: RawStory, field: string): string?
	local value = story[field]
	if value ~= nil and typeof(value) ~= "string" then
		error(`Story is malformed. \`{field}\` must be a string`)
	end
	return value :: string?
end

local function mergeField(defaults: RawStory?, overrides: RawStory?): RawStory?
	if not defaults and not overrides then
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

local function inheritDefaults(entry: RawStory, defaults: RawStory, id: string, name: string): RawStory
	local story = Sift.Dictionary.merge(defaults, entry) :: RawStory
	story.controls = mergeField(defaults.controls :: RawStory?, entry.controls :: RawStory?)
	story.packages = mergeField(defaults.packages :: RawStory?, entry.packages :: RawStory?)
	story.props = mergeField(defaults.props :: RawStory?, entry.props :: RawStory?)
	story.id = id
	story.name = name
	return story
end

local function validateStoryDefinition(story: RawStory, storyModule: ModuleScript, id: string)
	local isValid, message = types.IStoryDefinition(story)
	if not isValid or story.story == nil then
		local problem = if story.story == nil then "`story` is required" else message
		error(
			`Story "{id}" is malformed. Check the source of {storyModule:GetFullName()} and make sure its `
				.. `properties are correct. Error: {problem}`
		)
	end
end

local function normalizeStoryModule(requiredStory: unknown, storyModule: ModuleScript): (string, { RawStory }, boolean)
	local moduleName = storyModule.Name:gsub(constants.STORY_NAME_PATTERN, "")

	if typeof(requiredStory) == "function" then
		local callback = requiredStory :: (Instance, StoryProps) -> unknown
		local story: RawStory = {
			id = "default",
			name = moduleName,
			story = function(props: StoryProps)
				return callback(props.container :: Instance, props)
			end,
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
	if module.story ~= nil and module.stories ~= nil then
		error("Story is malformed. A Story module cannot define both `story` and `stories`")
	end

	if module.stories == nil then
		local id = getOptionalString(module, "id") or getOptionalString(module, "name") or "default"
		local name = getOptionalString(module, "name") or moduleName
		return moduleName, { inheritDefaults(module, {}, id, name) }, false
	end

	local defaults = table.clone(module)
	defaults.id = nil
	defaults.name = nil
	defaults.story = nil
	defaults.stories = nil

	local stories = module.stories :: { [unknown]: unknown }
	local normalized: { RawStory } = {}

	if Sift.Array.is(stories) then
		for index, entry in stories :: { unknown } do
			local raw = toRawStory(entry)
			local fallback = tostring(index)
			local name = getOptionalString(raw, "name")
			local id = getOptionalString(raw, "id") or name or fallback
			validateStoryDefinition(raw, storyModule, id)
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
			table.insert(
				normalized,
				inheritDefaults(
					raw,
					defaults,
					getOptionalString(raw, "id") or key,
					getOptionalString(raw, "name") or key
				)
			)
		end
	end

	if #normalized == 0 then
		error("Story is malformed. `stories` must contain at least one story")
	end

	return getOptionalString(module, "name") or moduleName, normalized, false
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

	local requiredStory
	local success, err = pcall(function()
		requiredStory = loader:require(storyModule)
	end)
	if not success then
		error(`Failed to load story {storyModule:GetFullName()}. Error: {err}`)
	end

	local groupName, normalizedStories, isLegacyStory = normalizeStoryModule(requiredStory, storyModule)
	local loadedStories: { LoadedStory<T> } = {}
	local seenIds: { [string]: boolean } = {}

	for _, raw in normalizedStories do
		local id = raw.id :: string
		if seenIds[id] then
			error(`Story is malformed. Story id "{id}" is duplicated in {storyModule:GetFullName()}`)
		end
		seenIds[id] = true

		validateStoryDefinition(raw, storyModule, id)
		local story: Story<T> = {
			id = id,
			name = raw.name :: string?,
			story = raw.story :: T | (StoryProps) -> T,
			summary = raw.summary :: string?,
			controls = raw.controls :: StoryControlsSchema?,
			packages = raw.packages :: StoryPackages?,
			props = raw.props :: ExtraStoryProps?,
		}
		if story.controls then
			story.controls = migrateControlsSchema(story.controls)
		end

		local packages = if isLegacyStory
			then {}
			else story.packages or migrateLegacyPackages(raw) or loadedStorybook.packages

		table.insert(loadedStories, {
			id = id,
			name = story.name or id,
			storybook = loadedStorybook,
			source = storyModule,
			story = story.story,
			packages = packages,
			summary = story.summary,
			controls = story.controls,
			props = story.props,
		})
	end

	return {
		name = groupName,
		stories = loadedStories,
	}
end

return loadStoryModuleData
