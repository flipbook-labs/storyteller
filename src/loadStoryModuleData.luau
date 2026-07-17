local ModuleLoader = require("@pkg/ModuleLoader")

local constants = require("@root/constants")
local loadStorybookModule = require("@root/loadStorybookModule")
local migrateControlsSchema = require("@root/controls/migrateControlsSchema")
local migrateLegacyPackages = require("@root/migrateLegacyPackages")
local types = require("@root/types")

type LoadedStory<T> = types.LoadedStory<T>
type LoadedStorybook = types.LoadedStorybook
type ModuleLoader = ModuleLoader.ModuleLoader
type Story<T> = types.Story<T>

export type LoadedStoryModuleData<T> = {
	name: string,
	stories: { LoadedStory<T> },
}

local function mergeDictionaries<T>(defaults: { [string]: T }?, overrides: { [string]: T }?): { [string]: T }?
	if defaults == nil and overrides == nil then
		return nil
	end

	local merged = if defaults then table.clone(defaults) else {}
	if overrides then
		for key, value in overrides do
			merged[key] = value
		end
	end
	return merged
end

local function isArray(value: { [any]: any }): boolean
	local count = 0
	local largestIndex = 0

	for key in value do
		if typeof(key) ~= "number" or key < 1 or key % 1 ~= 0 then
			return false
		end

		count += 1
		largestIndex = math.max(largestIndex, key)
	end

	return count == largestIndex
end

local function sortedDictionaryKeys(value: { [any]: any }): { string }
	local keys = {}
	for key in value do
		if typeof(key) ~= "string" then
			error("Story is malformed. `stories` must be an array or a dictionary with string keys")
		end
		table.insert(keys, key)
	end

	table.sort(keys, function(a, b)
		local lowerA = string.lower(a)
		local lowerB = string.lower(b)
		return if lowerA == lowerB then a < b else lowerA < lowerB
	end)

	return keys
end

local function mergeStoryDefaults(defaults: { [string]: any }, entry: { [string]: any }): { [string]: any }
	local story = table.clone(defaults)
	for key, value in entry do
		story[key] = value
	end

	story.controls = mergeDictionaries(defaults.controls, entry.controls)
	story.packages = mergeDictionaries(defaults.packages, entry.packages)
	story.props = mergeDictionaries(defaults.props, entry.props)

	return story
end

local function normalizeEntry(
	entry: any,
	defaults: { [string]: any },
	fallbackId: string,
	fallbackName: string
): ({ [string]: any }, string)
	local definition
	if typeof(entry) == "table" then
		definition = table.clone(entry)
	else
		definition = {
			story = entry,
		}
	end

	local story = mergeStoryDefaults(defaults, definition)
	local id = if typeof(story.id) == "string"
		then story.id
		elseif typeof(story.name) == "string" then story.name
		else fallbackId
	story.id = id
	story.name = if typeof(story.name) == "string" then story.name else fallbackName

	return story, id
end

local function normalizeStoryModule(
	requiredStory: any,
	storyModule: ModuleScript
): (string, { { definition: { [string]: any }, id: string } }, boolean)
	local moduleName = storyModule.Name:gsub(constants.STORY_NAME_PATTERN, "")
	local isLegacyStory = typeof(requiredStory) == "function"

	if isLegacyStory then
		local callback = requiredStory
		return moduleName,
			{
				{
					id = "default",
					definition = {
						id = "default",
						name = moduleName,
						story = function(props)
							return callback(props.container, props)
						end,
					},
				},
			},
			true
	end

	local isValid, message = types.IStory(requiredStory)
	if not isValid then
		error(
			`Story is malformed. Check the source of {storyModule:GetFullName()} and make sure its properties are `
				.. `correct. Error: {message}`
		)
	end

	if requiredStory.story ~= nil and requiredStory.stories ~= nil then
		error("Story is malformed. A Story module cannot define both `story` and `stories`")
	end

	if requiredStory.stories == nil then
		local definition, id = normalizeEntry(requiredStory, {}, "default", moduleName)
		return moduleName, {
			{
				id = id,
				definition = definition,
			},
		}, false
	end

	local defaults = table.clone(requiredStory)
	defaults.id = nil
	defaults.name = nil
	defaults.story = nil
	defaults.stories = nil

	local stories = requiredStory.stories
	local normalized = {}
	local groupName = if typeof(requiredStory.name) == "string" then requiredStory.name else moduleName

	if isArray(stories) then
		for index, entry in stories do
			local fallback = tostring(index)
			local definition, id = normalizeEntry(entry, defaults, fallback, fallback)
			table.insert(normalized, {
				id = id,
				definition = definition,
			})
		end
	else
		for _, key in sortedDictionaryKeys(stories) do
			local definition, id = normalizeEntry(stories[key], defaults, key, key)
			table.insert(normalized, {
				id = id,
				definition = definition,
			})
		end
	end

	if #normalized == 0 then
		error("Story is malformed. `stories` must contain at least one story")
	end

	return groupName, normalized, false
end

local function loadStoryModuleData<T>(
	storyModule: ModuleScript,
	storybook: LoadedStorybook,
	providedLoader: ModuleLoader?
): LoadedStoryModuleData<T>
	local loader = if providedLoader then providedLoader else ModuleLoader.new()

	-- Pre-cache the Storybook so its packages resolve to the same values when a
	-- Story requires it. Tests may provide a source-less Storybook, so failure
	-- here falls back to the already loaded definition.
	local freshStorybook: LoadedStorybook?
	pcall(function()
		freshStorybook = loadStorybookModule(storybook.source, loader)
	end)
	local loadedStorybook = if freshStorybook then freshStorybook else storybook

	local requiredStory
	local success, err = pcall(function()
		requiredStory = loader:require(storyModule)
	end)
	if not success then
		error(`Failed to load story {storyModule:GetFullName()}. Error: {err}`)
	end

	local groupName, normalizedStories, isLegacyStory = normalizeStoryModule(requiredStory, storyModule)
	local loadedStories = {}
	local seenIds = {}

	for _, normalizedStory in normalizedStories do
		local story = normalizedStory.definition
		local id = normalizedStory.id

		if seenIds[id] then
			error(`Story is malformed. Story id "{id}" is duplicated in {storyModule:GetFullName()}`)
		end
		seenIds[id] = true

		if story.controls then
			story.controls = migrateControlsSchema(story.controls)
		end

		local isValid, message = types.IStoryDefinition(story)
		if not isValid then
			error(
				`Story "{id}" is malformed. Check the source of {storyModule:GetFullName()} and make sure its `
					.. `properties are correct. Error: {message}`
			)
		end

		local typedStory: Story<T> = story
		local packages = if isLegacyStory
			then {}
			else typedStory.packages or migrateLegacyPackages(typedStory) or loadedStorybook.packages

		local loadedStory: LoadedStory<T> = {
			id = id,
			name = typedStory.name or id,
			storybook = loadedStorybook,
			source = storyModule,
			story = typedStory.story,
			packages = packages,
			summary = typedStory.summary,
			controls = typedStory.controls,
			props = typedStory.props,
		}
		table.insert(loadedStories, loadedStory)
	end

	return {
		name = groupName,
		stories = loadedStories,
	}
end

return loadStoryModuleData
