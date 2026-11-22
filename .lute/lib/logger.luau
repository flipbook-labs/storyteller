local Archivist = require("@lpm/archivist@v0.3.1")
local FlipbookBatteries = require("@lpm/flipbook-batteries@v0.13.1")

-- Archivist reads `LOG_LEVEL` once, when a logger is created. Scripts require
-- this module before they load `.env` themselves, so it loads `.env` first.
-- That way a `LOG_LEVEL` set there still applies.
FlipbookBatteries.dotenv()

return Archivist.createLogger("Storyteller")
