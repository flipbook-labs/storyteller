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
		local label = Instance.new("TextButton")
		label.Text = if props.controls.isDisabled then "Disabled" else "Enabled"

		return label
	end,
}
