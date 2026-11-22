local JestGlobals = require("@pkg/JestGlobals")
local React = require("@pkg/React")
local Roact = require("@pkg/Roact")

local isComponentClass = require("./isComponentClass")

local expect = JestGlobals.expect
local test = JestGlobals.test

test("React and Roact classes are component classes", function()
	expect(isComponentClass(React.Component:extend("ReactClass"))).toBe(true)
	expect(isComponentClass(React.PureComponent:extend("ReactPure"))).toBe(true)
	expect(isComponentClass(Roact.Component:extend("RoactClass"))).toBe(true)
	expect(isComponentClass(Roact.PureComponent:extend("RoactPure"))).toBe(true)
end)

test("Story tables, functions and elements are not component classes", function()
	expect(isComponentClass({ story = function() end })).toBe(false)
	expect(isComponentClass(function() end)).toBe(false)
	expect(isComponentClass(React.createElement("Frame"))).toBe(false)
	expect(isComponentClass(Roact.createElement("Frame"))).toBe(false)
	expect(isComponentClass(nil)).toBe(false)
end)
