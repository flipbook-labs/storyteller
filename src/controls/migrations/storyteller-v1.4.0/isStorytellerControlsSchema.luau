local t = require("@pkg/t")

local Primitive = t.union(t.number, t.string, t.boolean, t.EnumItem)
local isStorytellerControlsSchema = t.map(t.string, t.union(Primitive, t.array(Primitive)))

return isStorytellerControlsSchema
