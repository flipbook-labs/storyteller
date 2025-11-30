local React = require("@pkg/React")

local useStorybooks = require("./useStorybooks")

local function createNextLayoutOrder()
	local layoutOrder = 0
	return function()
		layoutOrder += 1
		return layoutOrder
	end
end

local renderCount = 0
return {
	story = function()
		renderCount += 1

		local nextLayoutOrder = createNextLayoutOrder()

		local storybooks = useStorybooks()

		local children: { [string]: React.Node } = {}

		children.RenderCount = React.createElement("TextLabel", {
			Text = `Renders: {renderCount}`,

			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Font = Enum.Font.BuilderSansBold,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 1,
			LayoutOrder = nextLayoutOrder(),
		})

		children.AvailableHeader = React.createElement("TextLabel", {
			Text = "Storybooks",

			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Font = Enum.Font.BuilderSansBold,
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 1,
			LayoutOrder = nextLayoutOrder(),
		})

		for _, available in storybooks.available do
			children[available.source:GetFullName()] = React.createElement("TextLabel", {
				Text = available.source.Name,

				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Font = Enum.Font.BuilderSans,
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				LayoutOrder = nextLayoutOrder(),
			})
		end

		children.UnavailableHeader = React.createElement("TextLabel", {
			Text = "Unavailable Storybooks",

			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Font = Enum.Font.BuilderSansBold,
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 1,
			LayoutOrder = nextLayoutOrder(),
		})

		for _, unavailable in storybooks.unavailable do
			children[unavailable.storybook.source:GetFullName()] = React.createElement("TextLabel", {
				Text = unavailable.storybook.source.Name,

				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Font = Enum.Font.BuilderSans,
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				LayoutOrder = nextLayoutOrder(),
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
