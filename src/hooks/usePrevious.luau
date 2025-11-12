local React = require("@pkg/React")

local function usePrevious<T>(value: T?): T?
	local previous = React.useRef(nil :: T?)

	React.useEffect(function()
		previous.current = value
	end, { value })

	return previous.current
end

return usePrevious
