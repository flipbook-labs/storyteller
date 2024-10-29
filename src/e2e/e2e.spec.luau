local JestGlobals = require("@pkg/JestGlobals")
local ModuleLoader = require("@pkg/ModuleLoader")

local createRendererForStory = require("@root/createRendererForStory")
local findStoryModulesForStorybook = require("@root/findStoryModulesForStorybook")
local findStorybookModules = require("@root/findStorybookModules")
local loadStoryModule = require("@root/loadStoryModule")
local loadStorybookModule = require("@root/loadStorybookModule")
local render = require("@root/render")

local afterEach = JestGlobals.afterEach
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local describeEach = describe.each :: any
local expect = JestGlobals.expect
local test = JestGlobals.test

local storybookModules = findStorybookModules(script.Parent.storybooks)

local EXCLUDED_FROM_CONFORMANCE = {
	script.Parent.storybooks["Hoarcekat.storybook"],
}

test("pin number of storybooks", function()
	expect(#storybookModules).toBe(4)
end)

describeEach(storybookModules)("e2e %s", function(storybookModule)
	local loader = ModuleLoader.new()
	local storybook = loadStorybookModule(loader, storybookModule)
	local storyModules = findStoryModulesForStorybook(storybook)
	local container

	beforeEach(function()
		container = Instance.new("Folder")
	end)

	afterEach(function()
		loader:clear()
	end)

	test("storybook has necessary stories for conformance tests", function()
		if table.find(EXCLUDED_FROM_CONFORMANCE, storybookModule) then
			return
		end

		local numStoriesWithControls = 0

		assert(#storyModules >= 2, "storybook must have at least 2 stories")

		for _, storyModule in storyModules do
			local story, err = loadStoryModule(loader, storyModule, storybook)
			assert(story, `bad story: {err}`)

			if story.controls then
				numStoriesWithControls += 1
			end
		end

		assert(numStoriesWithControls >= 1, "storybook must have at least one story with controls")
		assert(#storyModules - numStoriesWithControls >= 1, "storybook must have at least one story without controls")
	end)

	describeEach(storyModules)("%s", function(storyModule)
		test("basic mount/unmount lifecycle", function()
			local story, err = loadStoryModule(loader, storyModule, storybook)
			assert(story, `bad story: {err}`)

			local renderer = createRendererForStory(story)
			local lifecycle = render(renderer, container, story)

			expect(#container:GetChildren()).toBe(1)

			lifecycle.unmount()

			expect(#container:GetChildren()).toBe(0)
		end)

		test("rerenders on control changes", function()
			local story, err = loadStoryModule(loader, storyModule, storybook)
			assert(story, `bad story: {err}`)

			if story.controls then
				local renderer = createRendererForStory(story)
				local lifecycle = render(renderer, container, story)

				expect(#container:GetChildren()).toBe(1)

				local button = container:FindFirstChildWhichIsA("TextButton")
				assert(button, "for conformance, each test story with controls must include a TextButton")

				expect(button.Text).toBe("Enabled")

				lifecycle.update({
					isDisabled = false,
				})

				expect(#container:GetChildren()).toBe(1)
				expect(button.Text).toBe("Disabled")

				lifecycle.unmount()

				expect(#container:GetChildren()).toBe(0)
			end
		end)
	end)
end)
