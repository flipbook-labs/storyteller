--[[
	Developer Storybook accepts an element anywhere a Story component goes.
	React and RoactCompat elements carry `$$typeof`, legacy Roact elements carry
	`component`, and both carry `props`. Legacy Roact tables can be strict, so
	this only uses rawget.
]]
local function isElement(value: unknown): boolean
	if typeof(value) ~= "table" then
		return false
	end
	local fields = value :: { [any]: unknown }
	return rawget(fields, "props") ~= nil and (rawget(fields, "$$typeof") ~= nil or rawget(fields, "component") ~= nil)
end

return isElement
