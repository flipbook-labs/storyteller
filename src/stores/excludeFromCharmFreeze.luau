-- Charm deep-freezes signal values in Studio, but skips tables with metatables.
-- Loaded package graphs contain mutable module state, so they must stop the
-- recursive freeze at the boundary where they enter Charm state.
local EXCLUDED_VALUE_METATABLE = {}

local function excludeFromCharmFreeze(value: { [unknown]: unknown })
	setmetatable(value, EXCLUDED_VALUE_METATABLE)
end

return excludeFromCharmFreeze
