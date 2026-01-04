local JestGlobals = require("@pkg/JestGlobals")

local ControlType = require("@root/controls/enums/ControlType")
local types = require("./types")

local migrateStorytellerControlsSchema = require("./migrateStorytellerControlsSchema")

type StoryControlsSchema = types.StoryControlsSchema

local expect = JestGlobals.expect
local test = JestGlobals.test

test("migrates a complex Storyteller controls schema", function()
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
		toggle = {
			type = ControlType.Boolean,
			default = true,
		},
		text = {
			type = ControlType.String,
			default = "Hello, World!",
		},
		number = {
			type = ControlType.Number,
			default = 100,
		},
		font = {
			type = ControlType.Select,
			options = {
				["Enum.Font.BuilderSans"] = Enum.Font.BuilderSans,
				["Enum.Font.BuilderSansBold"] = Enum.Font.BuilderSansBold,
				["Enum.Font.BuilderSansExtraBold"] = Enum.Font.BuilderSansExtraBold,
			},
			default = "Enum.Font.BuilderSans",
		},
	})
end)
