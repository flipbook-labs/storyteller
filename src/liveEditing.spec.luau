--[[
	Stories change while they're open in a host like Flipbook, and those
	changes reach Storyteller in different ways depending on who makes them.

	File sync tools such as Rojo write a whole file into a ModuleScript's
	`Source` each time it's saved. They also create and destroy instances when
	files are added, removed, or renamed, and one save can touch several
	modules at once.

	Studio's script editor writes `Source` on every keystroke, so a story
	passes through many versions that don't compile on the way to one that
	does.

	Roblox's internal Storybooks load the same way as any other, but some use
	the older `storyRoot` field instead of `storyRoots`.

	Each test requests a story with `requestStoryModule`, acts out one of
	those changes, and checks the record `getStoryModuleRecord` returns. A
	change to loading or reloading has to keep every flow working to pass.
]]

local JestGlobals = require("@pkg/JestGlobals")

local StorytellerStore = require("@root/stores/StorytellerStore")
local getStoryModuleRecord = require("@root/getStoryModuleRecord")
local requestStoryModule = require("@root/requestStoryModule")
local types = require("@root/types")
local waitFor = require("@root/test-utils/waitFor")

local afterEach = JestGlobals.afterEach
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

type StoryRequest = types.StoryRequest

-- Storyteller can wait for edits to stop before it reloads a story, so a
-- reload can take longer than `waitFor`'s default of one second.
local WAIT_OPTIONS = { timeout = 5 }

-- How far apart keystrokes land when a test types into a module.
local KEYSTROKE_INTERVAL_SECONDS = 0.02

local roots: { Instance } = {}
local releases: { () -> () } = {}

beforeEach(function()
	StorytellerStore.get().stop()
end)

afterEach(function()
	for _, release in releases do
		release()
	end
	table.clear(releases)
	for _, root in roots do
		root:Destroy()
	end
	table.clear(roots)
	StorytellerStore.get().stop()
end)

local function createRoot(): Folder
	local root = Instance.new("Folder")
	table.insert(roots, root)
	return root
end

local function createModule(parent: Instance, name: string, source: string): ModuleScript
	local module = Instance.new("ModuleScript")
	module.Name = name
	module.Source = source
	module.Parent = parent
	return module
end

-- A story whose name is `prefix` followed by the value its `Dependency`
-- sibling returns.
local function dependentStorySource(prefix: string, dependencyName: string?): string
	return `local value = require(script.Parent.{dependencyName or "Dependency"})\n`
		.. `return \{ name = "{prefix} " .. tostring(value), story = function() end \}`
end

local function request(storyModule: ModuleScript, storybookSource: ModuleScript?): StoryRequest
	local storyRequest: StoryRequest = {
		storyModule = storyModule,
		storybook = {
			name = "Storybook",
			source = storybookSource or Instance.new("ModuleScript"),
			storyRoots = {},
		},
	}
	table.insert(releases, requestStoryModule(storyRequest))
	return storyRequest
end

local function waitForStoryName(storyRequest: StoryRequest, name: string)
	waitFor(function()
		local record = getStoryModuleRecord(storyRequest)
		assert(record and record.status == "Loaded", `expected {storyRequest.storyModule.Name} to load`)
		expect(record.stories[1].name).toBe(name)
	end, WAIT_OPTIONS)
end

describe("file sync tools such as Rojo", function()
	test("load the final version when a story and its dependency are saved together", function()
		local root = createRoot()
		local dependency = createModule(root, "Dependency", "return 1")
		local storyModule = createModule(root, "Synced.story", dependentStorySource("Version"))
		local storyRequest = request(storyModule)
		waitForStoryName(storyRequest, "Version 1")

		dependency.Source = "return 2"
		storyModule.Source = dependentStorySource("Saved")

		waitForStoryName(storyRequest, "Saved 2")
	end)

	test("pick up a dependency that is replaced by a new instance", function()
		local root = createRoot()
		local dependency = createModule(root, "Dependency", "return 1")
		local storyRequest = request(createModule(root, "Replaced.story", dependentStorySource("Version")))
		waitForStoryName(storyRequest, "Version 1")

		dependency:Destroy()
		createModule(root, "Dependency", "return 2")

		waitForStoryName(storyRequest, "Version 2")
	end)

	test("load a story edited to require a module created in the same sync", function()
		local root = createRoot()
		local storyModule = createModule(root, "Grows.story", `return \{ name = "Before", story = function() end \}`)
		local storyRequest = request(storyModule)
		waitForStoryName(storyRequest, "Before")

		storyModule.Source = dependentStorySource("After", "NewDependency")
		createModule(root, "NewDependency", "return 1")

		waitForStoryName(storyRequest, "After 1")
	end)

	test("keep reloading a story module after it is renamed", function()
		local root = createRoot()
		local storyModule = createModule(root, "Old.story", `return \{ name = "Before", story = function() end \}`)
		local storyRequest = request(storyModule)
		waitForStoryName(storyRequest, "Before")

		storyModule.Name = "New.story"
		storyModule.Source = `return \{ name = "After", story = function() end \}`

		waitForStoryName(storyRequest, "After")
	end)

	test("reload every story that shares a dependency, after one of them was edited", function()
		local root = createRoot()
		local dependency = createModule(root, "Dependency", "return 1")
		local first = createModule(root, "First.story", dependentStorySource("First"))
		local second = createModule(root, "Second.story", dependentStorySource("Second"))
		local firstRequest = request(first)
		local secondRequest = request(second)
		waitForStoryName(firstRequest, "First 1")
		waitForStoryName(secondRequest, "Second 1")

		first.Source = dependentStorySource("Edited")
		waitForStoryName(firstRequest, "Edited 1")

		dependency.Source = "return 2"

		waitForStoryName(firstRequest, "Edited 2")
		waitForStoryName(secondRequest, "Second 2")
	end)
end)

describe("Studio's script editor", function()
	test("keeps the last working version while an edit doesn't compile, then loads the fix", function()
		local root = createRoot()
		local storyModule = createModule(root, "Typed.story", `return \{ name = "Working", story = function() end \}`)
		local storyRequest = request(storyModule)
		waitForStoryName(storyRequest, "Working")

		storyModule.Source = `return \{ name = "Working", story = function() end`

		waitFor(function()
			local record = getStoryModuleRecord(storyRequest)
			assert(record and record.status == "Loaded", "expected the last working version to stay loaded")
			expect(record.stories[1].name).toBe("Working")
			expect((record :: { problem: string? }).problem).toEqual(expect.any("string"))
		end, WAIT_OPTIONS)

		storyModule.Source = `return \{ name = "Fixed", story = function() end \}`

		waitForStoryName(storyRequest, "Fixed")
	end)

	test("ends on the final version after typing a new name one keystroke at a time", function()
		local root = createRoot()
		local storyModule = createModule(root, "Typed.story", `return \{ name = "Start", story = function() end \}`)
		local storyRequest = request(storyModule)
		waitForStoryName(storyRequest, "Start")

		-- None of these versions close the string, so none of them compile.
		local finalName = "Typed out"
		for length = 0, #finalName do
			storyModule.Source = `return \{ name = "{finalName:sub(1, length)}`
			task.wait(KEYSTROKE_INTERVAL_SECONDS)
		end
		storyModule.Source = `return \{ name = "{finalName}", story = function() end \}`

		waitForStoryName(storyRequest, finalName)
	end)
end)

describe("Storybooks", function()
	test("give an edited story the same packages the Storybook loaded", function()
		local root = createRoot()
		createModule(root, "Shared", "return {}")
		local storybookSource = createModule(
			root,
			"Packages.storybook",
			"return { storyRoots = { script.Parent }, packages = { Shared = require(script.Parent.Shared) } }"
		)
		local storySource = function(name: string)
			return "local Shared = require(script.Parent.Shared)\n"
				.. `return \{ name = "{name}", story = function() return Shared end \}`
		end
		local storyModule = createModule(root, "UsesPackages.story", storySource("First"))
		local storyRequest = request(storyModule, storybookSource)

		local function expectSharedPackage(name: string)
			waitFor(function()
				local record = getStoryModuleRecord(storyRequest)
				assert(record and record.status == "Loaded", "expected the story to load")
				local story = record.stories[1]
				expect(story.name).toBe(name)
				assert(story.packages, "expected the story to have the Storybook's packages")
				local storyFn = story.story :: () -> unknown
				expect(storyFn()).toBe(story.packages.Shared)
			end, WAIT_OPTIONS)
		end

		expectSharedPackage("First")

		storyModule.Source = storySource("Edited")

		expectSharedPackage("Edited")
	end)

	test(
		"reload stories under a Storybook that uses `storyRoot`, as some of Roblox's internal Storybooks do",
		function()
			local root = createRoot()
			local storybookSource = createModule(root, "Internal.storybook", "return { storyRoot = script.Parent }")
			local storyModule =
				createModule(root, "Internal.story", `return \{ name = "Before", story = function() end \}`)
			local storyRequest = request(storyModule, storybookSource)
			waitForStoryName(storyRequest, "Before")

			storyModule.Source = `return \{ name = "After", story = function() end \}`

			waitFor(function()
				local record = getStoryModuleRecord(storyRequest)
				assert(record and record.status == "Loaded", "expected the edited story to load")
				expect(record.stories[1].name).toBe("After")
				expect(record.stories[1].storybook.storyRoots).toEqual({ root })
			end, WAIT_OPTIONS)
		end
	)
end)
