local JestGlobals = require("@pkg/JestGlobals")

local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

local migrateStorytellerControlsSchema = require("./migrateStorytellerControlsSchema")

type StoryControlsSchema = ControlTypes.StoryControlsSchema

local expect = JestGlobals.expect
local test = JestGlobals.test

test("migrates a complex Storyteller controls schema", function()
	local schema = {
		toggle = true,
		text = "Hello, World!",
		number = 100,
		font = {
			Enum.Font.BuilderSans,
			Enum.Font.BuilderSansBold,
			Enum.Font.BuilderSansExtraBold,
		},
	}

	local migrated = migrateStorytellerControlsSchema(schema)

	expect(migrated).toMatchObject({
		toggle = {
			control = ControlType.Boolean,
			default = true,
		},
		text = {
			control = ControlType.String,
			default = "Hello, World!",
		},
		number = {
			control = ControlType.Number,
			default = 100,
		},
		font = {
			control = ControlType.Select,
			options = {
				Enum.Font.BuilderSans.Name,
				Enum.Font.BuilderSansBold.Name,
				Enum.Font.BuilderSansExtraBold.Name,
			},
			mapping = {
				[Enum.Font.BuilderSans.Name] = Enum.Font.BuilderSans,
				[Enum.Font.BuilderSansBold.Name] = Enum.Font.BuilderSansBold,
				[Enum.Font.BuilderSansExtraBold.Name] = Enum.Font.BuilderSansExtraBold,
			},
			default = Enum.Font.BuilderSans.Name,
		},
	})
end)
