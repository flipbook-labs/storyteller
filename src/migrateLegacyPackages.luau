local isReact = require("@root/roblox-internal/isReact")
local types = require("@root/types")

type StoryPackages = types.StoryPackages

local function migrateLegacyPackages(storyOrStorybook: { [string]: any }): StoryPackages?
	if storyOrStorybook.roact or storyOrStorybook.react or storyOrStorybook.reactRoblox then
		print("storyOrStorybook", storyOrStorybook)

		-- Developer Storybook
		if storyOrStorybook.roact and storyOrStorybook.reactRoblox and isReact(storyOrStorybook.roact) then
			return {
				React = storyOrStorybook.roact,
				ReactRoblox = storyOrStorybook.reactRoblox,
			}
		end

		return {
			Roact = storyOrStorybook.roact,
			React = storyOrStorybook.react,
			ReactRoblox = storyOrStorybook.reactRoblox,
		}
	end
	return nil
end

return migrateLegacyPackages
