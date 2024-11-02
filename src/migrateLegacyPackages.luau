local types = require("@root/types")

type StoryPackages = types.StoryPackages

local function migrateLegacyPackages(storyOrStorybook: { [string]: any }): StoryPackages?
	if storyOrStorybook.roact or storyOrStorybook.react or storyOrStorybook.reactRoblox then
		return {
			Roact = storyOrStorybook.roact,
			React = storyOrStorybook.react,
			ReactRoblox = storyOrStorybook.reactRoblox,
		}
	end
	return nil
end

return migrateLegacyPackages
