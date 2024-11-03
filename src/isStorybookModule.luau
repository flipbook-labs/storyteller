local CoreGui = game:GetService("CoreGui")

local constants = require("@root/constants")

--[=[
	Validates a given [Instance] is a Storybook module.

	No validation is performed on the internals of the module. Only name and class are checked.

	See [Storyteller.loadStorybookModule] for validation of the module source.

	@within Storyteller
	@tag Validation
	@tag Storybook
	@since 1.0.0
]=]
local function isStorybookModule(instance: Instance): boolean
	return instance:IsA("ModuleScript")
		and instance.Name:match(constants.STORYBOOK_NAME_PATTERN) ~= nil
		and not instance:IsDescendantOf(CoreGui)
end

return isStorybookModule
