type Options = {
	timeout: number?,
	interval: number?,
}

local DEFAULT_TIMEOUT = 1
local DEFAULT_INTERVAL = 0.05

local function waitFor(callback: () -> (), options: Options?)
	local timeout = if options and options.timeout then options.timeout else DEFAULT_TIMEOUT
	local interval = if options and options.interval then options.interval else DEFAULT_INTERVAL
	local intervalStep = if interval > 0 then interval else DEFAULT_INTERVAL

	local lastError
	local elapsed = 0

	while true do
		local ok, err = pcall(function()
			callback()
			return nil
		end)

		if ok then
			return
		end

		lastError = err

		if elapsed >= timeout then
			error(lastError, 2)
		end

		task.wait(interval)
		elapsed += intervalStep
	end
end

return waitFor
