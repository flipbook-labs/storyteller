local JestGlobals = require("@pkg/JestGlobals")
local UILabs = require("@pkg/UILabs")

local ControlType = require("@root/controls/enums/ControlType")

local migrateUILabsControlGroup = require("./migrateUILabsControlGroup")

local expect = JestGlobals.expect
local test = JestGlobals.test

test("migrates the individual controls and returns a migrated array", function()
	local group = UILabs.ControlGroup({
		Message = UILabs.String("Testing!"),
		Toggle = UILabs.Boolean(false),
	})

	expect(migrateUILabsControlGroup(group)).toMatchObject({
		Message = {
			type = ControlType.String,
			default = "Testing!",
		},
		Toggle = {
			type = ControlType.Boolean,
			default = false,
		},
	})
end)

test("returns nil if there are no controls in the group", function()
	local group = UILabs.ControlGroup({})

	expect(migrateUILabsControlGroup(group)).toBeUndefined()
end)
