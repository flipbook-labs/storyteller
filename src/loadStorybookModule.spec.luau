local Charm = require("@pkg/Charm")
local JestGlobals = require("@pkg/JestGlobals")
local ModuleLoader = require("@pkg/ModuleLoader")

local loadStorybookModule = require("./loadStorybookModule")
local types = require("@root/types")

local afterEach = JestGlobals.afterEach
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local test = JestGlobals.test
local expect = JestGlobals.expect

local function createMockStorybookModule(source: string): ModuleScript
	local storybookModule = Instance.new("ModuleScript")
	storybookModule.Name = "Foo.storybook"
	storybookModule.Source = source

	return storybookModule
end

test("load a storybook module as a table", function()
	local loader = ModuleLoader.new()
	local storybookModule = createMockStorybookModule([[
			return {
				name = "Sample",
				storyRoots = {
					Instance.new("Folder")
				}
			}
		]])

	local storybook = loadStorybookModule(storybookModule, loader)

	expect(storybook.name).toBe("Sample")
	expect(#storybook.storyRoots).toBe(1)
end)

test("use the name of the storybook module by default", function()
	local loader = ModuleLoader.new()
	local storybookModule = createMockStorybookModule([[
		return {
			storyRoots = {}
		}
	]])
	storybookModule.Name = "SampleStorybook.storybook"

	local storybook = loadStorybookModule(storybookModule, loader)

	expect(storybook.name).toBe("SampleStorybook")
end)

test("nameless storybook", function()
	local loader = ModuleLoader.new()
	local storybookModule = createMockStorybookModule([[
		return {
			storyRoots = {}
		}
	]])
	storybookModule.Name = ".storybook"

	local storybook = loadStorybookModule(storybookModule, loader)

	expect(storybook.name).toBe("Unnamed Storybook")
end)

test("generic failures for storybook", function()
	local loader = ModuleLoader.new()
	local storybookModule = createMockStorybookModule([[
		return {
		}
	]])

	local success, result = pcall(function()
		return loadStorybookModule(storybookModule, loader)
	end)

	expect(success).toBeFalsy()
	expect(result).toMatch("failed to load storybook")
end)

test("malformed storybook", function()
	local loader = ModuleLoader.new()
	local storybookModule = createMockStorybookModule([[
		return {
			name = false,
			storyRoots = "should be a table"
		}
	]])

	local success, result = pcall(function()
		return loadStorybookModule(storybookModule, loader)
	end)

	expect(success).toBeFalsy()
	expect(result).toMatch("failed to load storybook")
end)

describe("legacy support", function()
	test("packages attached to the storybook get grouped in `packages` object", function()
		local loader = ModuleLoader.new()

		local storybookModule = createMockStorybookModule([[
			return {
				storyRoots = {
					Instance.new("Folder")
				},
				react = {},
				reactRoblox = {},
			}
		]])

		local storybook = loadStorybookModule(storybookModule, loader)

		expect(storybook).toMatchObject({
			storyRoots = expect.anything(),
			packages = {
				React = expect.anything(),
				ReactRoblox = expect.anything(),
			},
		})
	end)
end)

test("leaves the table the storybook module returns untouched", function()
	local loader = ModuleLoader.new()
	local storybookModule = createMockStorybookModule([[
		return {
			storyRoots = {},
			react = {},
			reactRoblox = {},
		}
	]])

	loadStorybookModule(storybookModule, loader)

	local source = loader:require(storybookModule) :: { [string]: unknown }
	expect(source.react).toBeDefined()
	expect(source.packages).toBeUndefined()
end)

describe("roblox internal", function()
	test("map storyRoot (single instance) to storyRoots (array of instances)", function()
		local storybookModule = createMockStorybookModule([[
			return {
				storyRoot = Instance.new("Folder"),
			}
		]])

		local storybook = loadStorybookModule(storybookModule)

		expect(#storybook.storyRoots).toBe(1)
	end)

	test("grouping storybooks", function()
		local loader = ModuleLoader.new()

		local storybookModule = createMockStorybookModule([[
			return {
				group = "Group",
				storyRoots = {
					Instance.new("Folder")
				},
				react = {},
				reactRoblox = {},
			}
		]])

		local storybook = loadStorybookModule(storybookModule, loader)

		expect(storybook.name).toBe("Group / Foo")
	end)
end)

describe("frozen Charm state (Studio behavior)", function()
	local prevFrozen: boolean = Charm.flags.frozen

	beforeEach(function()
		-- Charm only freezes state below optimization level 2, so tests run
		-- with freezing off. Force it on to reproduce what Studio does.
		prevFrozen = Charm.flags.frozen
		Charm.flags.frozen = true
	end)

	afterEach(function()
		Charm.flags.frozen = prevFrozen
	end)

	test("a loaded storybook's packages survive being stored in Charm state", function()
		local loader = ModuleLoader.new()
		local storybookModule = createMockStorybookModule([[
			return {
				storyRoots = {},
				packages = {
					FakeUILibrary = {
						internalState = {},
					},
				},
			}
		]])

		local storybook = loadStorybookModule(storybookModule, loader)

		local getStorybook, setStorybook = Charm.signal<<types.LoadedStorybook?>>(nil)
		setStorybook(storybook)

		local stored = getStorybook()
		assert(stored, "storybook was not stored in Charm state")
		local packages = stored.packages
		assert(packages, "loaded storybook has no packages")
		expect(table.isfrozen(packages.FakeUILibrary)).toBe(false)
		expect(table.isfrozen(packages.FakeUILibrary.internalState)).toBe(false)
	end)

	test("a legacy storybook's library survives being stored in Charm state", function()
		local loader = ModuleLoader.new()
		local storybookModule = createMockStorybookModule([[
			return {
				storyRoots = {},
				react = {
					internalState = {},
				},
				reactRoblox = {},
			}
		]])

		local storybook = loadStorybookModule(storybookModule, loader)

		local getStorybook, setStorybook = Charm.signal<<types.LoadedStorybook?>>(nil)
		setStorybook(storybook)

		local stored = getStorybook()
		assert(stored, "storybook was not stored in Charm state")
		local packages = stored.packages
		assert(packages, "loaded storybook has no packages")
		local React = packages.React :: { internalState: {} }
		expect(table.isfrozen(React)).toBe(false)
		expect(table.isfrozen(React.internalState)).toBe(false)
	end)
end)
