local React = require("@pkg/React")

local createStory = require("@root/test-utils/createStory")

local StoryContainer = require("./StoryContainer")

local story = createStory({
	story = function(props)
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromOffset(100, 100)
		frame.BackgroundColor3 = Color3.fromRGB(255, 0, 255)

		print("story props", props)

		return frame
	end,
})

return {
	story = function()
		return React.createElement(StoryContainer, {
			story = story,
			controls = {
				foo = true,
			},
			extraProps = {
				theme = "Light",
				locale = "en-us",
				script = script,
			},
			onError = function()
				print("err")
			end,
		})
	end,
}
