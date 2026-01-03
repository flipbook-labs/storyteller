local Sift = require("@pkg/Sift")

local ControlTypes = require("@root/controls/ControlTypes")

type ControlOptions = ControlTypes.ControlOptions

local function getPossibleControlOptions(controlOptions: ControlOptions): { string }
	local options: { string }?

	if ControlTypes.SimpleControlOptions:matches(controlOptions) then
		options = table.clone(controlOptions)
	elseif ControlTypes.MappedControlOptions:matches(controlOptions) then
		options = (Sift.Dictionary.keys(controlOptions))
	end

	if options then
		return Sift.List.sort(options)
	else
		return {}
	end
end

return getPossibleControlOptions
