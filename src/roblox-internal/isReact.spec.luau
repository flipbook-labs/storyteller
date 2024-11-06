local JestGlobals = require("@pkg/JestGlobals")
local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")
local Roact = require("@pkg/Roact")
local RoactCompat = require("@pkg/RoactCompat")

local isReact = require("./isReact")

local test = JestGlobals.test
local expect = JestGlobals.expect

test("React is React", function()
	expect(isReact(React)).toBeTruthy()
end)

test("RoactCompat is not React", function()
	expect(isReact(RoactCompat)).toBeTruthy()
end)

test("ReactRoblox is not React", function()
	expect(isReact(ReactRoblox)).toBeTruthy()
end)

test("legacy Roact is not React", function()
	expect(isReact(Roact)).toBeTruthy()
end)
