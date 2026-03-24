local ReactRoblox = require("@pkg/ReactRoblox")

local waitFor = require("@root/test-utils/waitFor")

local act = ReactRoblox.act

local function waitForAct(callback: () -> (), options: { timeout: number?, interval: number? }?)
	waitFor(function()
		act(function()
			callback()
		end)
	end, options)
end

return waitForAct
