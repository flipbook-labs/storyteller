local FlipbookBatteries = require("@luaupkg/FlipbookBatteries@v0.12.0")

local logger = require("@repo/.lute/lib/logger")

local run = FlipbookBatteries.run

-- Moonwave cannot be installed by Rokit just yet, so we install from Cargo for
-- now. This adds `moonwave-extractor` to the path which is what the Docusaurus
-- plugin looks for to generate our API docs
logger.warn("installing moonwave from Cargo until Rokit can manage it")
run("cargo", { "install", "moonwave" })

logger.info("installing docs dependencies")
run("npm", { "install" }, {
	cwd = "docs",
})

logger.info("starting the docs server")
run("npm", { "start" }, {
	cwd = "docs",
})
