--[[
	Developer Storybook accepts a class component anywhere a Story component
	goes, including as the whole Story module. React and legacy Roact both store
	`__componentName` on each class that `extend` creates, which a Story table
	never has. Legacy Roact tables can be strict, so this only uses rawget.
]]
local function isComponentClass(value: unknown): boolean
	if typeof(value) ~= "table" then
		return false
	end
	return typeof(rawget(value :: { [any]: unknown }, "__componentName")) == "string"
end

return isComponentClass
