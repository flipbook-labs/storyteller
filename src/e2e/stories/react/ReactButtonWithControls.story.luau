local React = require("@pkg/React")

local function ReactButton(props)
	return React.createElement("TextButton", {
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.BuilderSans,
		Text = if props.isDisabled then "Disabled" else "Enabled",
		TextColor3 = Color3.fromRGB(15, 15, 15),
		TextSize = 16,
	}, {
		Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 8),
		}),
	})
end

local controls = {
	isDisabled = false,
}

type Props = {
	controls: typeof(controls),
}

return {
	controls = controls,
	story = function(props: Props)
		return React.createElement(ReactButton, {
			isDisabled = props.controls.isDisabled,
		})
	end,
}
