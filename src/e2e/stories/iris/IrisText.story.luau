local Iris = require("@pkg/Iris")

return {
	story = function()
		Iris.Window({ "Text Window" })
		Iris.Text({ "Some text content" })
		Iris.End()
	end,
}
