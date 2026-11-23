local Archivist = require("@pkg/Archivist")

--[[
	Wraps an Archivist sink, an output target for log records, so records reach it
	only while `isEnabled` returns true. `isEnabled` runs on every write rather
	than once, so output can be switched on or off partway through a session.
	`flush` and `close` pass straight through, since they produce no new output.
]]
local function createOptInSink(sink: Archivist.Sink, isEnabled: () -> boolean): Archivist.Sink
	return {
		write = function(records)
			if isEnabled() then
				sink.write(records)
			end
		end,
		flush = sink.flush,
		close = sink.close,
	}
end

return createOptInSink
