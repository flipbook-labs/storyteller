type Options = {
	timeout: number?,
	interval: number?,
}

local DEFAULT_TIMEOUT = 1
local DEFAULT_INTERVAL = 0.05

local function waitFor(callback: () -> (), options: Options?)
	local timeout = if options and options.timeout then options.timeout else DEFAULT_TIMEOUT
	local interval = if options and options.interval then options.interval else DEFAULT_INTERVAL

	local lastError: string?
	local elapsed = 0

	while true do
		local ok, err = pcall(function()
			callback()
		end)

		if ok then
			return
		end

		lastError = err

		if elapsed >= timeout then
			error(lastError, 2)
		end

		elapsed += task.wait(interval)
	end
end

return waitFor
