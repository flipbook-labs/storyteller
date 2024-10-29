return function(target: Instance)
	local label = Instance.new("TextLabel")
	label.Text = "Hoarcekat Story"
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	label.Size = UDim2.fromOffset(300, 100)
	label.Parent = target

	return function()
		label:Destroy()
	end
end
