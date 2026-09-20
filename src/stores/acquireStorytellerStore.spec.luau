local JestGlobals = require("@pkg/JestGlobals")

local acquireStorytellerStore = require("./acquireStorytellerStore")

local expect = JestGlobals.expect
local test = JestGlobals.test

test("runs the store until the last consumer releases it", function()
	local startCount = 0
	local stopCount = 0
	local store = {
		start = function()
			startCount += 1
		end,
		stop = function()
			stopCount += 1
		end,
	}

	local releaseFirst = acquireStorytellerStore(store)
	local releaseSecond = acquireStorytellerStore(store)

	expect(startCount).toBe(1)
	releaseFirst()
	expect(stopCount).toBe(0)
	releaseSecond()
	expect(stopCount).toBe(1)
end)

test("ignores repeated releases from the same consumer", function()
	local stopCount = 0
	local store = {
		start = function() end,
		stop = function()
			stopCount += 1
		end,
	}

	local release = acquireStorytellerStore(store)
	release()
	release()

	expect(stopCount).toBe(1)
end)
