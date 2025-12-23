local React = require("@pkg/React")

local loadStorybookModule = require("@root/loadStorybookModule")

local StoryContainer = require("./StoryContainer")

local storyModule = Instance.new("ModuleScript")
storyModule.Name = "Foo.story"
storyModule.Source = [[
	return {
		story = function(props)
			local frame = Instance.new("Frame")
			frame.Size = UDim2.fromOffset(100, 100)
			frame.BackgroundColor3 = Color3.fromRGB(255, 0, 255)

			print("story props", props)

			return frame
		end
	}
]]

local storybook = loadStorybookModule(script.Parent["Storyteller.storybook"])

return {
	story = function()
		return React.createElement(StoryContainer, {
			storyModule = storyModule,
			storybook = storybook,
			extraProps = {
				theme = "Light",
				locale = "en-us",
				controls = {
					foo = true,
				},
				script = script,
			},
			onError = function()
				print("err")
			end,
		})
	end,
}
