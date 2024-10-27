local JestGlobals = require("@pkg/JestGlobals")

local matchDescendants = require("./matchDescendants")

local test = JestGlobals.test
local expect = JestGlobals.expect

test("returns an array of instances that match the predicate", function()
	local container = Instance.new("Folder")

	local module = Instance.new("ModuleScript")
	module.Name = "Sample"
	module.Parent = container

	-- Add Folders above the container to build out a nested hierarchy
	for _ = 1, 10 do
		local folder = Instance.new("Folder")
		container.Parent = folder
		container = folder
	end

	local matches = matchDescendants(container, function(descendant)
		return descendant.Name == "Sample"
	end)

	expect(matches).toEqual({ module })

	container:Destroy()
end)
