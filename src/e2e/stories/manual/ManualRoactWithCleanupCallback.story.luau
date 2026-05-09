local Roact = require("@pkg/Roact")

type Props = {
	container: Instance,
}

return {
	story = function(props: Props)
		local root = Roact.createElement("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			Font = Enum.Font.BuilderSans,
			Text = "Hello World",
			TextColor3 = Color3.fromRGB(15, 15, 15),
			TextSize = 16,
		}, {
			Padding = Roact.createElement("UIPadding", {
				PaddingTop = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 8),
			}),
		})

		local tree = Roact.mount(root, props.container)

		return function()
			Roact.unmount(tree)
		end
	end,
}
