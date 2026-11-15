--[[
	This function is used to differentiate between React and legacy Roact only
	for the consumption of Roblox Internal storybooks.
]]
local function isReact(maybeModule: unknown): boolean
	if typeof(maybeModule) ~= "table" then
		return false
	end

	local maybeReact = maybeModule :: { [string]: unknown }
	if maybeReact.Ref == "ref" and maybeReact.Children == "children" then
		return true
	-- Legacy Roact is a strict table, and indexing it directly throws an error
	-- if a member doesn't exist. To get around this we use rawget to check if
	-- it's React
	elseif rawget(maybeReact, "useState") ~= nil then
		return true
	else
		return false
	end
end

return isReact
