type Options = {
	timeout: number?,
	interval: number?,
}

local DEFAULT_TIMEOUT = 1
local DEFAULT_INTERVAL = 0.05

local function waitFor(callback: () -> (), options: Options?)
	local timeout = if options and options.timeout then options.timeout else DEFAULT_TIMEOUT
	local interval = if options and options.interval then options.interval else DEFAULT_INTERVAL
	local intervalStep = if interval > 0 then interval else 0

	local lastError
	local startedAt = os.clock()

	while true do
		local ok, err = pcall(function()
			callback()
			return nil
		end)

		if ok then
			return
		end

		lastError = err

		if os.clock() - startedAt >= timeout then
			error(lastError, 2)
		end

		if intervalStep > 0 then
			task.wait(intervalStep)
		else
			task.wait()
		end
	end
end

return waitFor
