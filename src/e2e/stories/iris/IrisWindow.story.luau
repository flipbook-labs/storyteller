local Iris = require("@pkg/Iris")

-- Iris is immediate-mode, so controls are intentionally omitted: the shared
-- conformance tests expect a top-level TextButton which Iris cannot produce.
-- Control/update behaviour is covered by createIrisRenderer.spec.luau instead.
return {
	story = function()
		Iris.Window({ "My Window" })
		Iris.Text({ "Hello, World" })
		Iris.Button({ "Save" })
		Iris.End()
	end,
}
