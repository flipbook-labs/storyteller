local JestGlobals = require("@pkg/JestGlobals")
local UILabs = require("@pkg/UILabs")

local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")
local UILabsTypes = require("@root/controls/migrations/ui-labs-v2.4.2/UILabsTypes")

local migrateUILabsControlsSchema = require("./migrateUILabsControlsSchema")

type StoryControlsSchema = ControlTypes.StoryControlsSchema

local expect = JestGlobals.expect
local test = JestGlobals.test

test("migrates a complex UI Labs schema to Flipbook's schema", function()
	local schema: UILabsTypes.StoryControlsSchema = {
		message = UILabs.String("Hello, World!") :: any,

		group = UILabs.ControlGroup({
			toggle = UILabs.Boolean(false),

			choice = UILabs.Choose({
				"Option 1",
				"Option 2",
				"Option 3",
			}),
		}) :: any,
	}

	expect(migrateUILabsControlsSchema(schema)).toMatchObject({
		message = {
			type = ControlType.String,
			default = "Hello, World!",
		},
		toggle = {
			type = ControlType.Boolean,
			default = false,
		},
		choice = {
			type = ControlType.Select,
			items = {
				"Option 1",
				"Option 2",
				"Option 3",
			},
		},
	})
end)
