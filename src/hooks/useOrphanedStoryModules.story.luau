local React = require("@pkg/React")

local useStorybooks = require("@root/hooks/useStorybooks")

local useOrphanedStoryModules = require("./useOrphanedStoryModules")

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

		local orphanedStoryModules = useOrphanedStoryModules()

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
			LayoutOrder = nextLayoutOrder(),
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
