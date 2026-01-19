local React = require("@pkg/React")

export type Props = {
	isDisabled: boolean,
}

local function ReactButton(props: Props)
	return React.createElement("TextButton", {
		Text = if props.isDisabled then "Disabled" else "Enabled",
	})
end

return ReactButton
