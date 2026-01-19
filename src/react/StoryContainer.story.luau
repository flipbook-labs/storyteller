local React = require("@pkg/React")

local createStory = require("@root/test-utils/createStory")

local StoryContainer = require("./StoryContainer")

local story = createStory({
	controls = {
		text = "Hello, World!",
	},
	props = {
		static = "Static prop",
	},
	story = function(props)
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromOffset(100, 100)
		label.BackgroundColor3 = Color3.fromRGB(255, 0, 255)
		label.Text = props.controls.text

		return label
	end,
})

return {
	controls = {
		text = "Hello, World!",
	},
	story = function(props)
		return React.createElement(StoryContainer, {
			story = story,
			controls = props.controls,
			extraProps = {
				theme = "Light",
				locale = "en-us",
				script = script,
			},
			onError = function(message)
				print("onError", message)
			end,
		})
	end,
}
