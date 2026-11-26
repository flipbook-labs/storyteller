local SOURCE_ERROR = "The current thread cannot read 'Source' (lacking capability PluginOrOpenCloud)"

--[[
	A script in a playtest lacks the PluginOrOpenCloud capability, so it can't
	read or write a ModuleScript's `Source`, or call
	`GetPropertyChangedSignal("Source")`. Specs run through Open Cloud, which has
	that capability. So code that does any of those passes every spec and then
	throws when Flipbook is embedded in a game.

	This returns a stand-in for `moduleScript` that throws in those three cases.
	Every other member comes from the real ModuleScript, including its `Changed`
	signal. The stand-in is a table, so a spec can't require it or load it as a
	story.
]]
local function createPlaytestModuleScript(moduleScript: ModuleScript): ModuleScript
	local members = (moduleScript :: unknown) :: { [string]: unknown }

	local standIn = setmetatable({}, {
		__index = function(_self: unknown, key: string): unknown
			if key == "Source" then
				error(SOURCE_ERROR, 2)
			end

			local member = members[key]
			if type(member) ~= "function" then
				return member
			end

			local method = member :: (...unknown) -> ...unknown
			return function(_standIn: unknown, ...: unknown): ...unknown
				if key == "GetPropertyChangedSignal" and (...) == "Source" then
					error(SOURCE_ERROR, 2)
				end
				return method(moduleScript, ...)
			end
		end,

		__newindex = function(_self: unknown, key: string, value: unknown)
			if key == "Source" then
				error(SOURCE_ERROR, 2)
			end
			members[key] = value
		end,
	})

	return (standIn :: unknown) :: ModuleScript
end

return createPlaytestModuleScript
