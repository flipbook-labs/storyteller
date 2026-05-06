local JestGlobals = require("@pkg/JestGlobals")

local debounce = require("./debounce")

local jest = JestGlobals.jest
local expect = JestGlobals.expect
local test = JestGlobals.test

jest.useFakeTimers()

test("the callback is run immediately on the first execution", function()
	local callback = jest.fn()
	local debouncedCallback = debounce(callback)

	expect(callback).never.toHaveBeenCalled()

	debouncedCallback()

	expect(callback).toHaveBeenCalledTimes(1)
end)

test("attempts to run the callback are discarded when debounced", function()
	local callback = jest.fn()
	local debouncedCallback = debounce(callback)

	for _ = 1, 1000 do
		debouncedCallback()
	end

	expect(callback).toHaveBeenCalledTimes(1)
end)

test("the last debounced callback is run immediately once the cooldown ends", function()
	local callback = jest.fn()
	local debouncedCallback = debounce(callback)

	debouncedCallback()
	expect(callback).toHaveBeenCalledTimes(1)

	jest.advanceTimersByTime(100)

	for _ = 1, 1000 do
		debouncedCallback()
	end

	expect(callback).toHaveBeenCalledTimes(1)

	jest.advanceTimersToNextTimer()

	expect(callback).toHaveBeenCalledTimes(2)
end)

test("debounce delay is configurable", function()
	local debounceMs = 1000

	local callback = jest.fn()
	local debouncedCallback = debounce(callback, debounceMs)

	debouncedCallback()
	jest.advanceTimersByTime(debounceMs / 4)
	expect(callback).toHaveBeenCalledTimes(1)

	debouncedCallback()
	jest.advanceTimersByTime(debounceMs / 4)
	expect(callback).toHaveBeenCalledTimes(1)

	debouncedCallback()
	jest.advanceTimersByTime(debounceMs / 4)
	expect(callback).toHaveBeenCalledTimes(1)

	debouncedCallback()
	jest.advanceTimersByTime(debounceMs / 4)
	expect(callback).toHaveBeenCalledTimes(2)
end)
