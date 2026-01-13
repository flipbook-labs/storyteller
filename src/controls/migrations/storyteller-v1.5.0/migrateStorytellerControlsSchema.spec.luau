local JestGlobals = require("@pkg/JestGlobals")

local ControlType = require("@root/controls/enums/ControlType")
local types = require("./types")

local migrateStorytellerControlsSchema = require("./migrateStorytellerControlsSchema")

type StoryControlsSchema = types.StoryControlsSchema

local expect = JestGlobals.expect
local test = JestGlobals.test

test("migrates a Storyteller v1.5.0 controls schema", function()
	local schema: StoryControlsSchema = {
		toggle = true,
		text = "Hello, World!",
		number = 100,
		font = {
			Enum.Font.BuilderSans,
			Enum.Font.BuilderSansBold,
			Enum.Font.BuilderSansExtraBold,
		} :: { EnumItem },
	}

	local migrated = migrateStorytellerControlsSchema(schema)

	expect(migrated).toMatchObject({
		toggle = true,
		text = "Hello, World!",
		number = 100,
		font = {
			type = ControlType.Select,
			items = {
				Enum.Font.BuilderSans,
				Enum.Font.BuilderSansBold,
				Enum.Font.BuilderSansExtraBold,
			},
			default = Enum.Font.BuilderSans,
		},
	})
end)
