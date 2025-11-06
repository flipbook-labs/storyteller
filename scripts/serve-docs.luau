local run = require("./lib/run")

-- Moonwave cannot be installed by Rokit just yet, so we install from Cargo for
-- now. This adds `moonwave-extractor` to the path which is what the Docusaurus
-- plugin looks for to generate our API docs
run("cargo", { "install", "moonwave" })

run("npm", { "install" }, {
	cwd = "docs",
})

run("npm", { "start" }, {
	cwd = "docs",
})
