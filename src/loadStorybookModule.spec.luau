local JestGlobals = require("@pkg/JestGlobals")
local ModuleLoader = require("@pkg/ModuleLoader")

local loadStorybookModule = require("./loadStorybookModule")

local describe = JestGlobals.describe
local test = JestGlobals.test
local expect = JestGlobals.expect

type ModuleLoader = ModuleLoader.ModuleLoader

local function createMockStorybookModule(source: string): ModuleScript
	local storybookModule = Instance.new("ModuleScript")
	storybookModule.Name = "Foo.storybook"
	storybookModule.Source = source

	return storybookModule
end

-- A loader that hands back the same table on every require, like Roblox's
-- native `require` cache does.
local function createCachingLoader(result: unknown): ModuleLoader
	local loader = {
		require = function()
			return result
		end,
	}
	return (loader :: any) :: ModuleLoader
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

describe("caching loaders", function()
	test("loading the same module twice prefixes the group once", function()
		local storybookModule = Instance.new("ModuleScript")
		storybookModule.Name = "Foo.storybook"
		local loader = createCachingLoader({
			group = "Group",
			storyRoots = {},
		})

		loadStorybookModule(storybookModule, loader)
		local storybook = loadStorybookModule(storybookModule, loader)

		expect(storybook.name).toBe("Group / Foo")
	end)

	test("leave the table the module returned unchanged", function()
		local storybookModule = Instance.new("ModuleScript")
		storybookModule.Name = "Foo.storybook"
		local storyRoot = Instance.new("Folder")
		local result = {
			group = "Group",
			storyRoot = storyRoot,
		}

		loadStorybookModule(storybookModule, createCachingLoader(result))

		expect(result).toEqual({
			group = "Group",
			storyRoot = storyRoot,
		})
	end)
end)
