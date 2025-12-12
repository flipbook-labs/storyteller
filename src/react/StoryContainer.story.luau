local React = require("@pkg/React")

local loadStorybookModule = require("@root/loadStorybookModule")

local StoryContainer = require("./StoryContainer")

local storyModule = Instance.new("ModuleScript")
storyModule.Name = "Foo.story"
storyModule.Source = [[
	print("story")
	return {
		story = function()
			local frame = Instance.new("Frame")
			frame.Size = UDim2.fromOffset(100, 100)
			frame.BackgroundColor3 = Color3.fromRGB(255, 0, 255)

			return frame
		end
	}
]]

return {
	story = function()
		local storybook = loadStorybookModule(script.Parent["Storyteller.storybook"])

		return React.createElement(StoryContainer, {
			storyModule = storyModule,
			storybook = storybook,
			onError = function()
				print("err")
			end,
		})
	end,
}
