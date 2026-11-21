local JestGlobals = require("@pkg/JestGlobals")

local ControlTypes = require("@root/controls/ControlTypes")
local findStoryModulesForStorybook = require("@root/findStoryModulesForStorybook")
local findStorybookModules = require("@root/findStorybookModules")
local loadStoriesFromModule = require("@root/loadStoriesFromModule")
local loadStorybookModule = require("@root/loadStorybookModule")
local render = require("@root/render")
local types = require("@root/types")

local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
-- JestGlobals types `describe.each` as a union that can't be called, so it's
-- cast to the form used here: a list of cases, then a name and a callback that
-- runs once per case.
type DescribeEach = <T>(cases: { T }) -> (name: string, fn: (case: T) -> ()) -> ()
local describeEach = (describe.each :: unknown) :: DescribeEach
local expect = JestGlobals.expect
local test = JestGlobals.test

type StoryControls = ControlTypes.StoryControls

local storybookModules = findStorybookModules(script.Parent.storybooks)

local EXCLUDED_FROM_CONFORMANCE = {
	script.Parent.storybooks["Hoarcekat.storybook"],
	-- Iris is immediate-mode and cannot produce the top-level TextButton the
	-- conformance tests expect, so its stories are exempt.
	script.Parent.storybooks["Iris.storybook"],
}

test("pin number of storybooks", function()
	expect(#storybookModules).toBe(6)
end)

describeEach(storybookModules)("e2e %s", function(storybookModule)
	local storybook = loadStorybookModule(storybookModule)
	local storyModules = findStoryModulesForStorybook(storybook)
	local container: Folder

	beforeEach(function()
		container = Instance.new("Folder")
	end)

	local function afterRender<T>(story: types.Story<T>)
		local packages = if story then story.packages else storybook.packages

		if packages and packages.React and packages.ReactRoblox then
			local reactRoblox = packages.ReactRoblox :: { act: (callback: () -> ()) -> () }
			reactRoblox.act(function()
				task.wait()
			end)
		elseif packages and (packages.Fusion or packages.Vide or packages.Iris) then
			task.wait()
		end
	end

	test("storybook has necessary stories for conformance tests", function()
		if table.find(EXCLUDED_FROM_CONFORMANCE, storybookModule) then
			return
		end

		local numStories = 0
		local numStoriesWithControls = 0

		assert(#storyModules >= 2, "storybook must have at least 2 stories")

		for _, storyModule in storyModules do
			for _, story in loadStoriesFromModule(storyModule, storybook) do
				numStories += 1
				if story.controls then
					numStoriesWithControls += 1
				end
			end
		end

		assert(numStoriesWithControls >= 1, "storybook must have at least one story with controls")
		assert(numStories - numStoriesWithControls >= 1, "storybook must have at least one story without controls")
	end)

	describeEach(storyModules)("%s", function(storyModule)
		test("basic mount/unmount lifecycle", function()
			for _, story in loadStoriesFromModule(storyModule, storybook) do
				local lifecycle = render(container, story)

				afterRender(story)

				expect(#container:GetChildren()).toBe(1)

				lifecycle.unmount()

				expect(#container:GetChildren()).toBe(0)
			end
		end)

		test("rerenders on control changes", function()
			for _, story in loadStoriesFromModule(storyModule, storybook) do
				if story.controls then
					local lifecycle = render(container, story)

					afterRender(story)

					expect(#container:GetChildren()).toBe(1)

					local button = container:FindFirstChildWhichIsA("TextButton")
					assert(button, "for conformance, each story with controls must include a TextButton")

					expect(button.Text).toBe("Enabled")

					local controls: StoryControls = {
						isDisabled = true,
					}
					lifecycle.update(controls)

					afterRender(story)

					expect(#container:GetChildren()).toBe(1)

					button = container:FindFirstChildWhichIsA("TextButton")
					assert(button, "after updating, the story no longer has a TextButton")
					expect(button.Text).toBe("Disabled")

					lifecycle.unmount()

					expect(#container:GetChildren()).toBe(0)
				end
			end
		end)
	end)
end)
