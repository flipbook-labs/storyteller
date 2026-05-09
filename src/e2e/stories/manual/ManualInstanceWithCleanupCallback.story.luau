type Props = {
	container: Instance,
}

return {
	story = function(props: Props)
		local label = Instance.new("TextLabel")
		label.AutomaticSize = Enum.AutomaticSize.XY
		label.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		label.Font = Enum.Font.BuilderSans
		label.Text = "Hello World"
		label.TextColor3 = Color3.fromRGB(15, 15, 15)
		label.TextSize = 16
		label.Parent = props.container

		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 8)
		padding.PaddingRight = UDim.new(0, 8)
		padding.PaddingBottom = UDim.new(0, 8)
		padding.PaddingLeft = UDim.new(0, 8)
		padding.Parent = label

		return function()
			label:Destroy()
		end
	end,
}
