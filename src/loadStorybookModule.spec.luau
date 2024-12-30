local JestGlobals = require("@pkg/JestGlobals")
local ModuleLoader = require("@pkg/ModuleLoader")

local loadStorybookModule = require("./loadStorybookModule")

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
end)
