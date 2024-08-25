local Sift = require("@pkg/Sift")
local t = require("@pkg/t")

local types = require("@root/types")

local Controls = t.map(t.string, t.union(t.string, t.number, t.boolean, t.map(t.number, t.any)))

local Roact = t.interface({
	createElement = t.callback,
	mount = t.callback,
	unmount = t.callback,
})
local React = t.interface({
	createElement = t.callback,
})
local ReactRoblox = t.interface({
	createRoot = t.callback,
})
local Storybook = t.interface({
	storyRoots = t.array(t.Instance),

	name = t.optional(t.string),
	roact = t.optional(Roact),
	react = t.optional(React),
	reactRoblox = t.optional(ReactRoblox),
})
local RoactStorybook = t.union(
	Storybook,
	t.interface({
		roact = t.optional(Roact),
	})
)
local ReactStorybook = t.union(
	Storybook,
	t.interface({
		react = t.optional(React),
		reactRoblox = t.optional(ReactRoblox),
	})
)
local StoryMeta = t.interface({
	story = t.any,
	name = t.optional(t.string),
	summary = t.optional(t.string),
	controls = t.optional(Controls),
	roact = t.optional(Roact),
	react = t.optional(React),
	reactRoblox = t.optional(ReactRoblox),
})

local Errors = {
	MalformedStory = "Story is malformed. Check the source of %q and make sure its properties are correct",
	Generic = "Failed to load story %q. Error: %s",
}

local function loadStoryModule(loader: any, module: ModuleScript, storybook: types.Storybook): (types.Story?, string?)
	if not module then
		return nil, "Did not receive a module to load"
	end

	local success, result = pcall(function()
		return loader:require(module)
	end)

	if not success then
		return nil, Errors.Generic:format(module:GetFullName(), tostring(result))
	end

	local story: types.Story
	if typeof(result) == "function" then
		story = {
			name = module.Name,
			story = result,
			storybook = storybook,
			source = module,
		}
	else
		local isValid, message = StoryMeta(result)

		if isValid then
			local extraProps = {}
			if ReactStorybook(storybook) then
				local reactStorybook = storybook :: types.ReactStorybook
				extraProps = {
					react = reactStorybook.react,
					reactRoblox = reactStorybook.reactRoblox,
				}
			elseif RoactStorybook(storybook) then
				local roactStorybook = storybook :: types.RoactStorybook
				extraProps = {
					roact = roactStorybook.roact,
				}
			end

			story = Sift.Dictionary.merge({
				name = module.Name,
				storybook = storybook,
				source = module,
			}, extraProps, result)
		else
			return nil, Errors.Generic:format(module:GetFullName(), message)
		end
	end

	if story then
		return story, nil
	else
		return nil, Errors.MalformedStory:format(module:GetFullName())
	end
end

return loadStoryModule
