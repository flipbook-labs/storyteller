local Vide = require("@pkg/Vide")

local controls = {
	text = "Label",
}

type Controls = typeof(controls)
type Props = { controls: Controls }

return {
	controls = controls,
	story = function(props: Props)
		return {
			Vide.create("UIListLayout")({
				Name = "ListLayout",
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			Vide.create("TextLabel")({
				AutomaticSize = Enum.AutomaticSize.XY,
				LayoutOrder = 1,
				Name = "DisplayText",
				Text = props.controls.text,
				TextSize = 24,
			}),

			Vide.create("TextLabel")({
				AutomaticSize = Enum.AutomaticSize.XY,
				LayoutOrder = 2,
				Name = "DisplayTextModified",
				Text = function()
					return `Modified: {props.controls.text()}`
				end,
				TextSize = 24,
			}),
		}
	end,
}
