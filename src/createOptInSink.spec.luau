local Archivist = require("@pkg/Archivist")
local JestGlobals = require("@pkg/JestGlobals")

local createOptInSink = require("./createOptInSink")

local expect = JestGlobals.expect
local test = JestGlobals.test

local function createRecord(message: string): Archivist.LogRecord
	return {
		timestamp = 0,
		level = "Info",
		name = "Test",
		args = table.pack(message),
	}
end

test("forwards records only while enabled, checking on every write", function()
	local received: { string } = {}
	local inner = Archivist.createCallbackSink(function(record)
		table.insert(received, record.args[1])
	end)

	local isEnabled = false
	local sink = createOptInSink(inner, function()
		return isEnabled
	end)

	sink.write({ createRecord("before") })
	isEnabled = true
	sink.write({ createRecord("during") })
	isEnabled = false
	sink.write({ createRecord("after") })

	expect(received).toEqual({ "during" })
end)
