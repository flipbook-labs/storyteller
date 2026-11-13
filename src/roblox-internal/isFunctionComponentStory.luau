local types = require("@root/types")

type StoryPackages = types.StoryPackages

--[[
	Developer Storybook treats a Story module that returns a bare function as a
	component, unless calling the function with a host returns a cleanup
	callback, which marks a Hoarcekat-style Story. The only way to tell the two
	apart is to call the function, so this probes it with a throwaway host.

	A component fails the probe by erroring (it indexes the host as if it were
	props, or calls hooks outside a render) or by returning an element. Any
	other result keeps the Hoarcekat behavior.
]]
local function isFunctionComponentStory(callback: (...any) -> ...any, packages: StoryPackages?): boolean
	local hasComponentRenderer = packages ~= nil
		and (packages.Roact ~= nil or (packages.React ~= nil and packages.ReactRoblox ~= nil))
	if not hasComponentRenderer then
		return false
	end

	local host = Instance.new("Frame")
	local success, result = pcall(callback, host)
	if success and typeof(result) == "function" then
		pcall(result)
	end
	host:Destroy()

	return not success or typeof(result) == "table"
end

return isFunctionComponentStory
