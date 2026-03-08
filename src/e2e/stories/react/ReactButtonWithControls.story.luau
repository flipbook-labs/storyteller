local React = require("@pkg/React")

local function ReactButton(props)
	return React.createElement("TextButton", {
		Text = if props.isDisabled then "Disabled" else "Enabled",
	})
end

local controls = {
	isDisabled = false,
}

type Props = {
	controls: typeof(controls),
}

print(script, "LOADED")

return {
	controls = controls,
	story = function(props: Props)
		print("props")
		for k, v in props do
			print(k, v)
		end
		return React.createElement(ReactButton, {
			isDisabled = props.controls.isDisabled,
		})
	end,
}
