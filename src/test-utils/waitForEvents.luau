local RunService = game:GetService("RunService")

local function waitForEvents()
	print("waitForEvents")
	RunService.Heartbeat:Wait()
end

return waitForEvents
