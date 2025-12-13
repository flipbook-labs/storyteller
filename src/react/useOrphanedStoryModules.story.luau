local React = require("@pkg/React")

local useOrphanedStoryModules = require("./useOrphanedStoryModules")

local function createNextOrder()
	local layoutOrder = 0
	return function()
		layoutOrder += 1
		return layoutOrder
	end
end

return {
	story = function()
		local renderCount = React.useRef(0)
		renderCount.current += 1

		local getNextOrder = createNextOrder()
		local orphanedStoryModules = useOrphanedStoryModules()

		local children: { [string]: React.Node } = {}

		children.RenderCount = React.createElement("TextLabel", {
			Text = `Renders: {renderCount.current}`,

			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Font = Enum.Font.BuilderSansBold,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 1,
			LayoutOrder = getNextOrder(),
		})

		children.Header = React.createElement("TextLabel", {
			Text = "Orphaned Stories",

			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Font = Enum.Font.BuilderSansBold,
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 1,
			LayoutOrder = getNextOrder(),
		})

		for _, orphanedStoryModule in orphanedStoryModules do
			children[orphanedStoryModule.Name] = React.createElement("TextLabel", {
				Text = orphanedStoryModule.Name,

				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Font = Enum.Font.BuilderSans,
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				LayoutOrder = getNextOrder(),
			})
		end

		return React.createElement("Frame", {
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			Size = UDim2.fromScale(1, 1),
		}, {
			Layout = React.createElement("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),

			Padding = React.createElement("UIPadding", {
				PaddingTop = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 8),
			}),
		}, children)
	end,
}
