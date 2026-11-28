local Archivist = require("@lpm/archivist@v0.3.1")
local FlipbookBatteries = require("@lpm/flipbook-batteries@v0.14.0")

--[[
	This module creates the scripts' logger as soon as a script requires it, and
	Archivist reads `LOG_LEVEL` at that moment. Scripts require this module
	before they call `dotenv()`, so it loads `.env` here first. That way a
	`LOG_LEVEL` set in `.env` takes effect.
]]
FlipbookBatteries.dotenv()

return Archivist.createLogger("Storyteller")
