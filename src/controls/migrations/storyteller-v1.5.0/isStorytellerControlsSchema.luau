local gt = require("@pkg/GreenTea")

local Primitive = gt.union(gt.number(), gt.string(), gt.boolean(), gt.EnumItem())
local StorytellerControlsSchema = gt.dictionary(gt.string(), gt.union(Primitive, gt.array(Primitive)))

local function isStorytellerControlsSchema(...)
	return gt.build(StorytellerControlsSchema):matches(...)
end

return isStorytellerControlsSchema
