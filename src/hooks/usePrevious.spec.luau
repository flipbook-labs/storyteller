local JestGlobals = require("@pkg/JestGlobals")
local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")

local usePrevious = require("./usePrevious")

local expect = JestGlobals.expect
local test = JestGlobals.test
local afterEach = JestGlobals.afterEach

local useEffect = React.useEffect

local act = ReactRoblox.act

local container = Instance.new("ScreenGui")
local root = ReactRoblox.createRoot(container)
local toggleState = Instance.new("BindableEvent")

local function HookTester()
	local state, setState = React.useState(false)
	local prev = usePrevious(state)

	useEffect(function()
		local conn = toggleState.Event:Connect(function()
			setState(function(prevState)
				return not prevState
			end)
		end)

		return function()
			conn:Disconnect()
		end
	end, {})

	return React.createElement("TextLabel", {
		Text = tostring(prev),
	})
end

afterEach(function()
	act(function()
		root:unmount()
	end)
end)

test("use the last value", function()
	local element = React.createElement(HookTester)

	act(function()
		root:render(element)
	end)

	local result = container:FindFirstChildWhichIsA("TextLabel") :: TextLabel

	expect(result.Text).toBe("nil")

	act(function()
		toggleState:Fire()
	end)

	act(function()
		task.wait()
	end)

	expect(result.Text).toBe("false")

	act(function()
		toggleState:Fire()
	end)

	act(function()
		task.wait()
	end)

	expect(result.Text).toBe("true")
end)
