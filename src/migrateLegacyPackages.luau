local isReact = require("@root/roblox-internal/isReact")
local types = require("@root/types")

type StoryPackages = types.StoryPackages

local function migrateLegacyPackages(storyOrStorybook: { [string]: any }): StoryPackages?
	if storyOrStorybook.roact or storyOrStorybook.react or storyOrStorybook.reactRoblox then
		return {
			Roact = storyOrStorybook.roact,
			React = if storyOrStorybook.react
				then storyOrStorybook.react
				else if isReact(storyOrStorybook.roact) then storyOrStorybook.roact else nil,
			ReactRoblox = storyOrStorybook.reactRoblox,
		}
	end
	return nil
end

return migrateLegacyPackages
