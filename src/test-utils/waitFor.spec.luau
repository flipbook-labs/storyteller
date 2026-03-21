local JestGlobals = require("@pkg/JestGlobals")

local waitFor = require("./waitFor")

local expect = JestGlobals.expect
local jest = JestGlobals.jest
local test = JestGlobals.test

jest.useFakeTimers()

type WaitForState = {
	done: boolean,
	success: boolean?,
	error: any,
}

local function startWaitFor(callback: () -> (), options: { timeout: number?, interval: number? }?): WaitForState
	local state: WaitForState = {
		done = false,
		success = nil,
		error = nil,
	}

	task.spawn(function()
		local success, result = pcall(function()
			waitFor(callback, options)
		end)

		state.done = true
		state.success = success
		state.error = result
	end)

	return state
end

test("uses the default interval and timeout", function()
	local attempts = 0

	local state = startWaitFor(function()
		attempts += 1

		if attempts < 2 then
			error("retry")
		end
	end)

	expect(attempts).toBe(1)
	expect(state.done).toBe(false)

	jest.advanceTimersByTime(49)
	expect(attempts).toBe(1)
	expect(state.done).toBe(false)

	jest.advanceTimersByTime(1)
	expect(attempts).toBe(2)
	expect(state.done).toBe(true)
	expect(state.success).toBe(true)
end)

test("allows custom interval and timeout values", function()
	local attempts = 0

	local state = startWaitFor(function()
		attempts += 1

		if attempts < 3 then
			error("keep waiting")
		end
	end, {
		interval = 0.2,
		timeout = 2,
	})

	expect(attempts).toBe(1)
	expect(state.done).toBe(false)

	jest.advanceTimersByTime(199)
	expect(attempts).toBe(1)
	expect(state.done).toBe(false)

	jest.advanceTimersByTime(1)
	expect(attempts).toBe(2)
	expect(state.done).toBe(false)

	jest.advanceTimersToNextTimer()
	expect(attempts).toBe(3)
	expect(state.done).toBe(true)
	expect(state.success).toBe(true)
end)

test("rethrows the last callback error when it times out", function()
	local attempts = 0

	local state = startWaitFor(function()
		attempts += 1
		error(string.format("boom %d", attempts))
	end, {
		timeout = 0.12,
		interval = 0.05,
	})

	jest.advanceTimersByTime(200)
	local errorMessage = tostring(state.error)
	local exactFinalAttempt = string.format("boom %d", attempts)
	local matchStart = string.find(errorMessage, exactFinalAttempt)

	expect(state.done).toBe(true)
	expect(state.success).toBe(false)
	expect(attempts).toBeGreaterThan(2)
	expect(matchStart).never.toBe(nil)
end)

test("supports Jest expect assertions inside the callback", function()
	local value = 0

	task.delay(0.1, function()
		value = 1
	end)

	local state = startWaitFor(function()
		expect(value).toBe(1)
	end, {
		interval = 0.02,
		timeout = 1,
	})

	for _ = 1, 10 do
		if state.done then
			break
		end

		jest.runOnlyPendingTimers()
	end

	expect(state.done).toBe(true)
	expect(state.success).toBe(true)
end)
