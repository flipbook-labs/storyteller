--[[
	Specs call this with property tables like `{ Name = "Story" }`. Luau's old
	solver, which Storyteller type checks with, rejects those where
	`{ [string]: unknown }` is expected, so props stay `any`.
	#191 tracks removing this ignore.
]]
-- lute-lint-ignore(no_any)
local function new(className: string, props: { [string]: any }?, children: { [string]: Instance }?)
	local instance = Instance.new(className)

	if props then
		for key, value in props do
			-- An Instance's properties can't be set by a string key without
			-- casting the Instance to `any`.
			-- #192 tracks removing this ignore.
			-- lute-lint-ignore(no_any)
			(instance :: any)[key] = value
		end
	end

	if children then
		for name, child in children do
			child.Name = name
			child.Parent = instance
		end
	end

	return instance
end

return new
