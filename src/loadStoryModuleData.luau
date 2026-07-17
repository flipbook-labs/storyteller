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
type StoryProps = types.StoryProps

export type LoadedStoryModuleData<T> = {
	name: string,
	stories: { LoadedStory<T> },
}

type RawStory = { [string]: unknown }

local function optionalString(value: unknown): string?
	return if typeof(value) == "string" then value else nil
end

local function mergeDictionaries(defaults: RawStory?, overrides: RawStory?): RawStory?
	if not defaults and not overrides then
		return nil
	end

	local merged: RawStory = if defaults then table.clone(defaults) else {}
	if overrides then
		for key, value in overrides do
			merged[key] = value
		end
	end
	return merged
end

local function isArray(value: { [unknown]: unknown }): boolean
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

local function sortedKeys(value: { [unknown]: unknown }): { string }
	local keys = {}
	for key in value do
		if typeof(key) ~= "string" then
			error("Story is malformed. `stories` must be an array or a dictionary with string keys")
		end
		table.insert(keys, key)
	end

	table.sort(keys, function(a, b)
		local lowerA, lowerB = a:lower(), b:lower()
		return if lowerA == lowerB then a < b else lowerA < lowerB
	end)
	return keys
end

local function toRawStory(entry: unknown): RawStory
	if typeof(entry) == "table" then
		return table.clone(entry :: RawStory)
	end
	return { story = entry }
end

-- The dictionary fields (controls, packages, props) merge key-by-key rather
-- than being replaced wholesale, so an entry only overrides the keys it sets.
local function inheritDefaults(entry: RawStory, defaults: RawStory, id: string, name: string): RawStory
	local story = mergeDictionaries(defaults, entry) :: RawStory
	story.controls = mergeDictionaries(defaults.controls :: RawStory?, entry.controls :: RawStory?)
	story.packages = mergeDictionaries(defaults.packages :: RawStory?, entry.packages :: RawStory?)
	story.props = mergeDictionaries(defaults.props :: RawStory?, entry.props :: RawStory?)
	story.id = id
	story.name = name
	return story
end

local function normalizeStoryModule(requiredStory: unknown, storyModule: ModuleScript): (string, { RawStory }, boolean)
	local moduleName = storyModule.Name:gsub(constants.STORY_NAME_PATTERN, "")

	if typeof(requiredStory) == "function" then
		local callback = requiredStory :: (Instance, StoryProps) -> unknown
		local story: RawStory = {
			id = "default",
			name = moduleName,
			story = function(props: StoryProps)
				return callback(props.container, props)
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
		local id = optionalString(module.id) or optionalString(module.name) or "default"
		local name = optionalString(module.name) or moduleName
		return moduleName, { inheritDefaults(module, {}, id, name) }, false
	end

	local defaults = table.clone(module)
	defaults.id = nil
	defaults.name = nil
	defaults.story = nil
	defaults.stories = nil

	local stories = module.stories :: { [unknown]: unknown }
	local normalized: { RawStory } = {}

	if isArray(stories) then
		for index, entry in stories :: { unknown } do
			local raw = toRawStory(entry)
			local fallback = tostring(index)
			local id = optionalString(raw.id) or optionalString(raw.name) or fallback
			table.insert(normalized, inheritDefaults(raw, defaults, id, optionalString(raw.name) or fallback))
		end
	else
		-- The dictionary key is the stable id, so renaming an entry's `name`
		-- does not change the id consumers persist.
		for _, key in sortedKeys(stories) do
			local raw = toRawStory(stories[key])
			table.insert(
				normalized,
				inheritDefaults(raw, defaults, optionalString(raw.id) or key, optionalString(raw.name) or key)
			)
		end
	end

	if #normalized == 0 then
		error("Story is malformed. `stories` must contain at least one story")
	end

	return optionalString(module.name) or moduleName, normalized, false
end

local function loadStoryModuleData<T>(
	storyModule: ModuleScript,
	storybook: LoadedStorybook,
	providedLoader: ModuleLoader?
): LoadedStoryModuleData<T>
	local loader = providedLoader or ModuleLoader.new()

	-- Pre-cache the Storybook so its packages resolve to the same values when a
	-- Story requires it. Tests may provide a source-less Storybook, so failure
	-- here falls back to the already loaded definition.
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

		local isValid, message = types.IStoryDefinition(raw)
		if not isValid then
			error(
				`Story "{id}" is malformed. Check the source of {storyModule:GetFullName()} and make sure its `
					.. `properties are correct. Error: {message}`
			)
		end

		local story = (raw :: any) :: Story<T>
		if story.controls then
			story.controls = migrateControlsSchema(story.controls)
		end

		local packages = if isLegacyStory
			then {}
			else story.packages or migrateLegacyPackages(raw :: { [string]: any }) or loadedStorybook.packages

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
