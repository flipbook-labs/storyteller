local RoactCompat = require("@pkg/RoactCompat")

return {
	roact = RoactCompat,
	storyRoots = {
		script.Parent.stories.react,
	},
	mapStory = function(story)
		return function(storyProps)
			return RoactCompat.createElement("Frame", {
				BackgroundColor3 = Color3.fromRGB(255, 0, 0),
			}, RoactCompat.createElement(story, storyProps))
		end
	end,
}
