local Archivist = require("@pkg/Archivist")

local createOptInSink = require("@root/createOptInSink")

--[[
	Storyteller runs inside a host such as Flipbook, and Archivist's console sink
	writes to Studio Output, so every creator using that host would see these
	logs. They stay silent until someone sets `_G.ENABLE_STORYTELLER_LOGS = true`.
	The flag is read on each log call, so it can be switched on partway through a
	session. The minimum level is fixed sooner: Archivist reads `_G.LOG_LEVEL`
	once, when this module first loads, and defaults to "info".
]]
local sink = createOptInSink(Archivist.createConsoleSink(), function()
	-- lute-lint-ignore(global_usage)
	return (_G :: { [string]: unknown }).ENABLE_STORYTELLER_LOGS == true
end)

return Archivist.createLogger("Storyteller", {
	sinks = { sink },
})
