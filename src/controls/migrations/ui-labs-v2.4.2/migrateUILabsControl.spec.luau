local JestGlobals = require("@pkg/JestGlobals")
local UILabs = require("@pkg/UILabs")

local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")
local UILabsTypes = require("@root/controls/migrations/ui-labs-v2.4.2/UILabsTypes")

type UILabsControl = UILabsTypes.Control
type ColorControl = ControlTypes.ColorControl

local migrateUILabsControl = require("./migrateUILabsControl")

-- UI Labs returns controls typed by its own package, and those types don't
-- match the ones in UILabsTypes, so specs convert them here.
local function toUILabsControl(control: unknown): UILabsControl
	return control :: UILabsControl
end

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

describe("UILabs.Boolean", function()
	test("maps to ControlType.Boolean", function()
		local control = toUILabsControl(UILabs.Boolean(true))

		expect(migrateUILabsControl(control)).toMatchObject({
			type = ControlType.Boolean,
			default = true,
		})
	end)
end)

describe("UILabs.Number", function()
	test("maps to ControlType.Number", function()
		local control = toUILabsControl(UILabs.Number(100))

		expect(migrateUILabsControl(control)).toMatchObject({
			type = ControlType.Number,
			default = 100,
		})
	end)

	test("copies range (min/max) and step", function()
		local control = toUILabsControl(UILabs.Number(100, 0, 100, 1))

		expect(migrateUILabsControl(control)).toMatchObject({
			type = ControlType.Number,
			default = 100,
			range = NumberRange.new(0, 100),
			step = 1,
		})
	end)
end)

describe("UILabs.String", function()
	-- TODO: Should we support the "Filters" key?

	test("maps to ControlType.String", function()
		local control = toUILabsControl(UILabs.String("Hello, World!"))

		expect(migrateUILabsControl(control)).toMatchObject({
			type = ControlType.String,
			default = "Hello, World!",
		})
	end)
end)

describe("UILabs.Choose", function()
	test("maps to ControlType.Select", function()
		local control = toUILabsControl(UILabs.Choose({
			"Option 1",
			"Option 2",
			"Option 3",
		}))

		expect(migrateUILabsControl(control)).toMatchObject({
			type = ControlType.Select,
			items = {
				"Option 1",
				"Option 2",
				"Option 3",
			},
		})
	end)

	test("includes the default choice", function()
		local control = toUILabsControl(UILabs.Choose({
			"Option 1",
			"Option 2",
			"Option 3",
		}, 2))

		expect(migrateUILabsControl(control)).toMatchObject({
			type = ControlType.Select,
			items = {
				"Option 1",
				"Option 2",
				"Option 3",
			},
			default = "Option 2",
		})
	end)

	test("preserves non-string item types", function()
		local control = UILabs.Choose({ 10, 20, 30 })

		expect(migrateUILabsControl(toUILabsControl(control))).toMatchObject({
			type = ControlType.Select,
			items = { 10, 20, 30 },
			default = 10,
		})
	end)
end)

describe("UILabs.EnumList", function()
	test("uses keys as items and the default key as default", function()
		local control = toUILabsControl(UILabs.EnumList({
			Option1 = "Option 1",
			Option2 = "Option 2",
			Option3 = "Option 3",
		}, "Option1"))

		expect(migrateUILabsControl(control)).toMatchObject({
			type = ControlType.Select,
			items = {
				"Option1",
				"Option2",
				"Option3",
			},
			default = "Option1",
		})
	end)

	test("works when values are non-string types", function()
		local control = toUILabsControl(UILabs.EnumList({
			Mobile = 500,
			Tablet = 1000,
			Desktop = 1500,
		}, "Mobile"))

		expect(migrateUILabsControl(control)).toMatchObject({
			type = ControlType.Select,
			items = {
				"Desktop",
				"Mobile",
				"Tablet",
			},
			default = "Mobile",
		})
	end)
end)

describe("UILabs.Object", function()
	test("maps to nothing for now", function()
		local control = toUILabsControl(UILabs.Object("ModuleScript"))
		expect(migrateUILabsControl(control)).toBeUndefined()
	end)
end)

describe("UILabs.RGBA", function()
	test("maps to ControlType.Color", function()
		local control = toUILabsControl(UILabs.RGBA(Color3.fromRGB(255, 0, 200), 0.2))

		expect(migrateUILabsControl(control)).toMatchObject({
			type = ControlType.Color,
			default = (control :: UILabsTypes.RGBAControl).ControlValue.Color,
		})
	end)
end)

describe("UILabs.Slider", function()
	test("maps to ControlType.Slider", function()
		local control = toUILabsControl(UILabs.Slider(50, 0, 100, 5))

		expect(migrateUILabsControl(control)).toMatchObject({
			type = ControlType.Slider,
			range = NumberRange.new(0, 100),
			default = 50,
			step = 5,
		})
	end)
end)
