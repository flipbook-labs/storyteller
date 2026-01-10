local JestGlobals = require("@pkg/JestGlobals")

local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

local hydrateControls = require("./hydrateControls")

type StoryControlsSchema = ControlTypes.StoryControlsSchema
type StoryControls = ControlTypes.StoryControls
type StoryControl = ControlTypes.StoryControl

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local test = JestGlobals.test

local function assertAllControlTypesAreIncluded(schema: StoryControlsSchema)
	local missed = {}

	for _, controlType in ControlType do
		local found = false

		for _, controlSchema in schema do
			if typeof(controlSchema) == "table" and rawget(controlSchema, "type") == controlType then
				found = true
			end
		end

		if not found then
			table.insert(missed, controlType)
		end
	end

	assert(#missed == 0, `the following ControlTypes need to be included: {table.concat(missed, ", ")}`)
end

test("hydrates a schema using all control types", function()
	local schema: StoryControlsSchema = {
		-- Primitives
		greeting = {
			type = ControlType.String,
		},
		toggle = {
			type = ControlType.Boolean,
		},
		number = {
			type = ControlType.Number,
			range = NumberRange.new(1, 100),
		},
		-- Advanced
		slider = {
			type = ControlType.Slider,
			step = 1,
			range = NumberRange.new(1, 100),
		},
		color = {
			type = ControlType.Color,
		},
		date = {
			type = ControlType.Date,
		},
		-- List-based
		dropdown = {
			type = ControlType.Select,
			items = {
				"Option 1",
				"Option 2",
				"Option 3",
			},
		},
		multiSelect = {
			type = ControlType.MultiSelect,
			items = {
				"Option 1",
				"Option 2",
				"Option 3",
			},
		},
		check = {
			type = ControlType.Check,
			items = {
				"Option 1",
				"Option 2",
				"Option 3",
			},
		},
		radio = {
			type = ControlType.Radio,
			items = {
				"Option 1",
				"Option 2",
				"Option 3",
			},
		},
	}

	assertAllControlTypesAreIncluded(schema)

	local controls: StoryControls = {
		greeting = "Hello, World!",
		toggle = true,
		slider = 50,
	}

	local expected = {
		greeting = "Hello, World!",
		toggle = true,
		slider = 50,
	}

	expect(hydrateControls(schema, controls)).toMatchObject(expected)
end)

test("hydrates list-based controls", function()
	local schema: StoryControlsSchema = {
		dropdown = {
			type = ControlType.Select,
			items = {
				"Option 1",
				"Option 2",
				"Option 3",
			},
		},
		multiSelect = {
			type = ControlType.MultiSelect,
			items = {
				"Option 1",
				"Option 2",
				"Option 3",
			},
		},
		check = {
			type = ControlType.Check,
			items = {
				"Option 1",
				"Option 2",
				"Option 3",
			},
		},
		radio = {
			type = ControlType.Radio,
			items = {
				"Option 1",
				"Option 2",
				"Option 3",
			},
		},
	}

	local controls: StoryControls = {
		dropdown = "Option 1",
		radio = "Option 2",
		check = { "Option 1", "Option 2" },
		multiSelect = { "Option 3" },
	}

	local expected = {
		dropdown = "Option 1",
		multiSelect = { "Option 3" },
		check = { "Option 1", "Option 2" },
		radio = "Option 2",
	}

	expect(hydrateControls(schema, controls)).toMatchObject(expected)
end)

test("default value is used when one is not supplied", function()
	local schema: StoryControlsSchema = {
		-- Primitives
		greeting = {
			type = ControlType.String,
			default = "Hello, World!",
		},
		toggle = {
			type = ControlType.Boolean,
			default = false,
		},
		number = {
			type = ControlType.Number,
			default = 1,
			range = NumberRange.new(1, 100),
		},
		-- Advanced
		slider = {
			type = ControlType.Slider,
			default = 1,
			step = 1,
			range = NumberRange.new(1, 100),
		},
		color = {
			type = ControlType.Color,
			default = Color3.fromRGB(255, 255, 255),
		},
		date = {
			type = ControlType.Date,
			default = DateTime.now(),
		},
		-- List-based
		dropdown = {
			type = ControlType.Select,
			items = {
				"Option 1",
				"Option 2",
				"Option 3",
			},
			default = "Option 1",
		},
		multiSelect = {
			type = ControlType.MultiSelect,
			items = {
				"Option 1",
				"Option 2",
				"Option 3",
			},
			default = {
				"Option 1",
				"Option 2",
			},
		},
		check = {
			type = ControlType.Check,
			items = {
				"Option 1",
				"Option 2",
				"Option 3",
			},
			default = {
				"Option 2",
				"Option 3",
			},
		},
		radio = {
			type = ControlType.Radio,
			items = {
				"Option 1",
				"Option 2",
				"Option 3",
			},
			default = "Option 3",
		},
	}

	assertAllControlTypesAreIncluded(schema)

	-- We don't supply any controls here since we want to test the defaults
	local controls: StoryControls = {}

	local expected = {
		greeting = "Hello, World!",
		toggle = false,
		number = 1,
		slider = 1,
		color = expect.any("Color3"),
		date = expect.any("DateTime"),
		dropdown = "Option 1",
		multiSelect = {
			"Option 1",
			"Option 2",
		},
		check = {
			"Option 2",
			"Option 3",
		},
		radio = "Option 3",
	}

	expect(hydrateControls(schema, controls)).toMatchObject(expected)
end)

test("plain values in the schema get mapped to the relevant control type", function()
	local now = DateTime.now()

	local schema: StoryControlsSchema = {
		greeting = "Hello, World!",
		toggle = true,
		number = {
			type = ControlType.Number,
			range = NumberRange.new(0, 10),
		},
		color = Color3.fromRGB(255, 255, 255),
		date = {
			type = ControlType.Date,
			default = now,
		},
	}

	local controls: StoryControls = {
		toggle = false,
		number = 20,
	}

	local expected = {
		greeting = "Hello, World!",
		toggle = false,
		number = 10,
		color = Color3.fromRGB(255, 255, 255),
		date = now,
	}

	local hydrated = hydrateControls(schema, controls)

	expect(hydrated).toMatchObject(expected)
end)

describe("Boolean", function()
	test("hydrates a schema with a Boolean control", function()
		local schema: StoryControlsSchema = {
			isDisabled = {
				type = ControlType.Boolean,
				default = false,
			},
		}

		local controls: StoryControls = {
			isDisabled = true,
		}

		local hydrated = hydrateControls(schema, controls)

		expect(hydrated).toMatchObject({
			isDisabled = true,
		})
	end)
end)

describe("Number", function()
	test("hydrates a schema with a Number control", function()
		local schema: StoryControlsSchema = {
			num = {
				type = ControlType.Number,
				default = 100,
			},
		}

		local controls: StoryControls = {}

		local hydrated = hydrateControls(schema, controls)

		expect(hydrated).toMatchObject({
			num = 100,
		})
	end)

	test("constrains the control value to the range", function()
		local schema: StoryControlsSchema = {
			number = {
				type = ControlType.Number,
				default = 1,
				range = NumberRange.new(1, 100),
			},
		}

		local controls: StoryControls = {
			number = -100,
		}

		local expected = {
			number = 1,
		}

		expect(hydrateControls(schema, controls)).toMatchObject(expected)
	end)

	test("throws when schema default value is out of range", function()
		local schema: StoryControlsSchema = {
			number = {
				type = ControlType.Number,
				default = -100,
				range = NumberRange.new(1, 100),
			},
		}

		local controls: StoryControls = {}

		expect(function()
			hydrateControls(schema, controls)
		end).toThrow()
	end)
end)

describe("String", function()
	test("hydrates a schema with a String control", function()
		local schema: StoryControlsSchema = {
			text = {
				type = ControlType.String,
				default = "Hello, World!",
			},
		}

		local controls: StoryControls = {}

		local hydrated = hydrateControls(schema, controls)

		expect(hydrated).toMatchObject({
			text = "Hello, World!",
		})
	end)
end)

describe("Check", function()
	test("hydrates a schema with a Check control", function()
		local schema: StoryControlsSchema = {
			items = {
				type = ControlType.Check,
				items = {
					"Option 1",
					"Option 2",
					"Option 3",
				},
			},
		}

		local controls: StoryControls = {
			items = { "Option 2" },
		}

		local hydrated = hydrateControls(schema, controls)

		expect(hydrated).toMatchObject({
			items = { "Option 2" },
		})
	end)

	test("uses the default when no control value is set", function()
		local schema: StoryControlsSchema = {
			items = {
				type = ControlType.Check,
				items = {
					"Option 1",
					"Option 2",
					"Option 3",
				},
				default = {
					"Option 2",
				},
			},
		}

		local controls: StoryControls = {}

		local expected = {
			items = { "Option 2" },
		}

		local hydrated = hydrateControls(schema, controls)

		expect(hydrated).toMatchObject(expected)
	end)

	test("throws when passing an invalid option", function()
		local schema: StoryControlsSchema = {
			items = {
				type = ControlType.Check,
				items = {
					"Option 1",
					"Option 2",
					"Option 3",
				},
			},
		}

		local controls: StoryControls = {
			items = { "Not an option" },
		}

		expect(function()
			hydrateControls(schema, controls)
		end).toThrow()
	end)
end)

describe("Color", function()
	test("hydrates a schema with a Color control", function()
		local color = Color3.fromRGB(255, 255, 255)
		local schema: StoryControlsSchema = {
			color = {
				type = ControlType.Color,
				default = color,
			},
		}

		local controls: StoryControls = {}

		local hydrated = hydrateControls(schema, controls)

		expect(hydrated).toMatchObject({
			color = color,
		})
	end)
end)

describe("Date", function()
	test("hydrates a schema with a Date control", function()
		local date = DateTime.now()

		local schema: StoryControlsSchema = {
			date = {
				type = ControlType.Date,
				default = date,
			},
		}

		local controls: StoryControls = {}

		local hydrated = hydrateControls(schema, controls)

		expect(hydrated).toMatchObject({
			date = date,
		})
	end)
end)

describe("MultiSelect", function()
	test("hydrates a schema with a MultiSelect control", function()
		local schema: StoryControlsSchema = {
			choices = {
				type = ControlType.MultiSelect,
				items = {
					"Option 1",
					"Option 2",
					"Option 3",
				},
			},
		}

		local controls: StoryControls = {
			choices = { "Option 2" },
		}

		local hydrated = hydrateControls(schema, controls)

		expect(hydrated).toMatchObject({
			choices = { "Option 2" },
		})
	end)

	test("uses the default when no control value is set", function()
		local schema: StoryControlsSchema = {
			choices = {
				type = ControlType.MultiSelect,
				items = {
					"Option 1",
					"Option 2",
					"Option 3",
				},
				default = {
					"Option 2",
				},
			},
		}

		local controls: StoryControls = {}

		local expected = {
			choices = { "Option 2" },
		}

		local hydrated = hydrateControls(schema, controls)

		expect(hydrated).toMatchObject(expected)
	end)

	test("throws when passing an invalid option", function()
		local schema: StoryControlsSchema = {
			choices = {
				type = ControlType.MultiSelect,
				items = {
					"Option 1",
					"Option 2",
					"Option 3",
				},
			},
		}

		local controls: StoryControls = {
			choices = { "Not an option" },
		}

		expect(function()
			hydrateControls(schema, controls)
		end).toThrow()
	end)
end)

describe("Radio", function()
	test("hydrates a schema with a Radio control", function()
		local schema: StoryControlsSchema = {
			radio = {
				type = ControlType.Radio,
				items = {
					"Option 1",
					"Option 2",
					"Option 3",
				},
			},
		}

		local controls: StoryControls = {
			radio = "Option 2",
		}

		local hydrated = hydrateControls(schema, controls)

		expect(hydrated).toMatchObject({
			radio = "Option 2",
		})
	end)

	test("uses the default when no control value is set", function()
		local schema: StoryControlsSchema = {
			radio = {
				type = ControlType.Radio,
				items = {
					"Option 1",
					"Option 2",
					"Option 3",
				},
				default = "Option 2",
			},
		}

		local controls: StoryControls = {}

		local expected = {
			radio = "Option 2",
		}

		local hydrated = hydrateControls(schema, controls)

		expect(hydrated).toMatchObject(expected)
	end)

	test("throws when passing an invalid option", function()
		local schema: StoryControlsSchema = {
			radio = {
				type = ControlType.Radio,
				items = {
					"Option 1",
					"Option 2",
					"Option 3",
				},
			},
		}

		local controls: StoryControls = {
			radio = "Not an option",
		}

		expect(function()
			hydrateControls(schema, controls)
		end).toThrow()
	end)
end)

describe("Select", function()
	test("hydrates a schema with a Select control", function()
		local schema: StoryControlsSchema = {
			dropdown = {
				type = ControlType.Select,
				items = {
					"Option 1",
					"Option 2",
					"Option 3",
				},
			},
		}

		local controls: StoryControls = {
			dropdown = "Option 2",
		}

		local expected = {
			dropdown = "Option 2",
		}

		local hydrated = hydrateControls(schema, controls)

		expect(hydrated).toMatchObject(expected)
	end)

	test("uses the default when no control value is set", function()
		local schema: StoryControlsSchema = {
			dropdown = {
				type = ControlType.Select,
				items = {
					"Option 1",
					"Option 2",
					"Option 3",
				},
				default = "Option 2",
			},
		}

		local controls: StoryControls = {}

		local expected = {
			dropdown = "Option 2",
		}

		local hydrated = hydrateControls(schema, controls)

		expect(hydrated).toMatchObject(expected)
	end)

	test("throws when passing an invalid option", function()
		local schema: StoryControlsSchema = {
			dropdown = {
				type = ControlType.Select,
				items = {
					"Option 1",
					"Option 2",
					"Option 3",
				},
			},
		}

		local controls: StoryControls = {
			dropdown = "Not an option",
		}

		expect(function()
			hydrateControls(schema, controls)
		end).toThrow()
	end)
end)

describe("Slider", function()
	test("hydrates a schema with a Slider control", function()
		local schema: StoryControlsSchema = {
			number = {
				type = ControlType.Slider,
				default = 1,
				range = NumberRange.new(1, 100),
			},
		}

		local controls: StoryControls = {
			number = 50,
		}

		local expected = {
			number = 50,
		}

		local hydrated = hydrateControls(schema, controls)

		expect(hydrated).toMatchObject(expected)
	end)

	test("constrains the control value to the range", function()
		local schema: StoryControlsSchema = {
			number = {
				type = ControlType.Slider,
				default = 1,
				range = NumberRange.new(1, 100),
			},
		}

		local controls: StoryControls = {
			number = -100,
		}

		local expected = {
			number = 1,
		}

		expect(hydrateControls(schema, controls)).toMatchObject(expected)
	end)

	test("throws when schema default value is out of range", function()
		local schema: StoryControlsSchema = {
			slider = {
				type = ControlType.Slider,
				default = -100,
				range = NumberRange.new(1, 100),
			},
		}

		local controls: StoryControls = {}

		expect(function()
			hydrateControls(schema, controls)
		end).toThrow()
	end)
end)
