local JestGlobals = require("@pkg/JestGlobals")
local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")
local Roact = require("@pkg/Roact")

local migrateLegacyPackages = require("./migrateLegacyPackages")

local describe = JestGlobals.describe
local test = JestGlobals.test
local expect = JestGlobals.expect

test("map roact key", function()
	local packages = migrateLegacyPackages({
		roact = Roact,
	})

	expect(packages).toEqual({
		Roact = Roact,
	})
end)

describe("roblox internal", function()
	test("react can be passed as the roact key", function()
		local packages = migrateLegacyPackages({
			roact = React,
			reactRoblox = ReactRoblox,
		})

		expect(packages).toEqual({
			React = React,
			ReactRoblox = ReactRoblox,
		})
	end)
end)
