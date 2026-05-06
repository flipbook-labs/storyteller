local controls = {
	isDisabled = false,
}

type Props = {
	container: Instance,
	controls: typeof(controls),
}

return {
	controls = controls,
	story = function(props: Props)
		local button = Instance.new("TextButton")
		button.AutomaticSize = Enum.AutomaticSize.XY
		button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		button.Font = Enum.Font.BuilderSans
		button.Text = if props.controls.isDisabled then "Disabled" else "Enabled"
		button.TextColor3 = Color3.fromRGB(15, 15, 15)
		button.TextSize = 16

		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 8)
		padding.PaddingRight = UDim.new(0, 8)
		padding.PaddingBottom = UDim.new(0, 8)
		padding.PaddingLeft = UDim.new(0, 8)
		padding.Parent = button

		return button
	end,
}
