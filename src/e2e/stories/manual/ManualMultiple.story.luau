local controls = {
	isDisabled = false,
}

type Props = {
	container: Instance,
	controls: typeof(controls),
}

local function createButton(props: Props): TextButton
	local button = Instance.new("TextButton")
	button.Text = if props.controls.isDisabled then "Disabled" else "Enabled"
	return button
end

return {
	name = "Multiple manual stories",
	controls = controls,
	stories = {
		{
			id = "primary",
			name = "Primary",
			story = function(props: Props)
				return createButton(props)
			end,
		},
		{
			id = "secondary",
			name = "Secondary",
			story = function(props: Props)
				return createButton(props)
			end,
		},
	},
}
