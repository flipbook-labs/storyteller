--[[
	This function is primarily used for rate limiting hot paths in our DataModel
	querying logic.

	The way this debounce function works is:

	1. The callback is always run on the first execution
	2. A timer is started that prevents any new invokations during that time
	   period
	3. Once the timer is elapsed, immediately run the last debounced callback,
	   skipping all the others that came before
	4. Go to 2
]]
local function debounce(callback: (...any) -> (), debounceMs: number?)
	local waitTimeMs = if debounceMs then debounceMs else 500
	local isReady = true
	local hasPendingCall = false
	local thread: thread?

	local function execute()
		isReady = false
		callback()
	end

	return function()
		if isReady then
			execute()
		else
			hasPendingCall = true
		end

		if not thread then
			thread = task.spawn(function()
				task.wait(waitTimeMs / 1000)
				isReady = true
				thread = nil

				if hasPendingCall then
					hasPendingCall = false
					execute()
				end
			end)
		end
	end
end

return debounce
