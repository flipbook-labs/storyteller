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
			-- TODO: Having to do `options` and `mapping` like this is a bit
			-- silly. Could we support EnumItems directly? Maybe a general
			-- approach of: if this option is not a string, implicitly setup a
			-- mapping to it? with the ability to specify the tostring function?
			--
			-- By default we would just use tostring, but that could be subbed
			-- out to, for example, have an option as
			-- `Enum.Font.BuilderSans.Name` would would then have the option as
			-- just the enum name, and the value as an EnumItem
			--
			-- As another alternative, why not type `options` as `{ string } | {
			-- [string]: T }`? Look into why Storybook wouldn't be doing that
			-- for its list-based controls
			options = {
				tostring(Enum.Font.BuilderSans),
				tostring(Enum.Font.BuilderSansBold),
				tostring(Enum.Font.BuilderSansExtraBold),
			},
			mapping = {
				[tostring(Enum.Font.BuilderSans)] = Enum.Font.BuilderSans,
				[tostring(Enum.Font.BuilderSansBold)] = Enum.Font.BuilderSansBold,
				[tostring(Enum.Font.BuilderSansExtraBold)] = Enum.Font.BuilderSansExtraBold,
			},
			default = tostring(Enum.Font.BuilderSans),
		},
	})
end)
