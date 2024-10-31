local JestGlobals = require("@pkg/JestGlobals")
local ModuleLoader = require("@pkg/ModuleLoader")
local ReactRoblox = require("@pkg/ReactRoblox")

local createRendererForStory = require("@root/createRendererForStory")
local findStoryModulesForStorybook = require("@root/findStoryModulesForStorybook")
local findStorybookModules = require("@root/findStorybookModules")
local loadStoryModule = require("@root/loadStoryModule")
local loadStorybookModule = require("@root/loadStorybookModule")
local render = require("@root/render")

local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local describeEach = describe.each :: any
local expect = JestGlobals.expect
local test = JestGlobals.test
local act = ReactRoblox.act

local storybookModules = findStorybookModules(script.Parent.storybooks)

local EXCLUDED_FROM_CONFORMANCE = {
	script.Parent.storybooks["Hoarcekat.storybook"],
}

test("pin number of storybooks", function()
	expect(#storybookModules).toBe(4)
end)

describeEach(storybookModules)("e2e %s", function(storybookModule)
	-- FIXME: This is needed to get around a bug with React renders. I'm hoping
	-- to keep this for now, but in the future this should really be a
	-- ModuleLoader instance
	local mockModuleLoader = (
		{
			require = function(_self, path)
				return (require :: any)(path)
			end,
		} :: any
	) :: ModuleLoader.ModuleLoader

	local storybook = loadStorybookModule(mockModuleLoader, storybookModule)
	local storyModules = findStoryModulesForStorybook(storybook)
	local container

	beforeEach(function()
		container = Instance.new("Folder")
	end)

	local function afterRender()
		if storybookModule == script.Parent.storybooks["React.storybook"] then
			act(function()
				task.wait()
			end)
		elseif storybookModule == script.Parent.storybooks["Fusion.storybook"] then
			task.wait()
		end
	end

	test("storybook has necessary stories for conformance tests", function()
		if table.find(EXCLUDED_FROM_CONFORMANCE, storybookModule) then
			return
		end

		local numStoriesWithControls = 0

		assert(#storyModules >= 2, "storybook must have at least 2 stories")

		for _, storyModule in storyModules do
			local story = loadStoryModule(mockModuleLoader, storyModule, storybook)

			if story.controls then
				numStoriesWithControls += 1
			end
		end

		assert(numStoriesWithControls >= 1, "storybook must have at least one story with controls")
		assert(#storyModules - numStoriesWithControls >= 1, "storybook must have at least one story without controls")
	end)

	describeEach(storyModules)("%s", function(storyModule)
		test("basic mount/unmount lifecycle", function()
			local story = loadStoryModule(mockModuleLoader, storyModule, storybook)
			local renderer = createRendererForStory(story)
			local lifecycle = render(renderer, container, story)

			afterRender()

			expect(#container:GetChildren()).toBe(1)

			lifecycle.unmount()

			expect(#container:GetChildren()).toBe(0)
		end)

		test("rerenders on control changes", function()
			local story = loadStoryModule(mockModuleLoader, storyModule, storybook)

			if story.controls then
				local renderer = createRendererForStory(story)
				local lifecycle = render(renderer, container, story)

				afterRender()

				expect(#container:GetChildren()).toBe(1)

				local button = container:FindFirstChildWhichIsA("TextButton")
				assert(button, "for conformance, each story with controls must include a TextButton")

				expect(button.Text).toBe("Enabled")

				lifecycle.update({
					isDisabled = true,
				})

				afterRender()

				expect(#container:GetChildren()).toBe(1)

				button = container:FindFirstChildWhichIsA("TextButton")
				assert(button, "after updating, the story no longer has a TextButton")
				expect(button.Text).toBe("Disabled")

				lifecycle.unmount()

				expect(#container:GetChildren()).toBe(0)
			end
		end)
	end)
end)
