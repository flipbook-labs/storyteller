--[[
	Builds Storyteller and copies the build over the Storyteller that a
	Flipbook checkout installs, so Flipbook can try unreleased changes. Wally
	can't install path or git dependencies, so this stands in for one. The
	next `lute run install` in Flipbook puts the released packages back.
]]

local FlipbookBatteries = require("@lpm/flipbook-batteries@v0.14.0")
local cli = require("@lpm/batteries@v1.0.1-nightly.20261115/cli")
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")

local logger = require("@repo/.lute/lib/logger")

local overlayWallyPackage = FlipbookBatteries.overlayWallyPackage
local run = FlipbookBatteries.run

-- Without --flipbook, this looks for a `flipbook` folder beside this
-- checkout or beside one of its parent folders.
local function findFlipbookRoot(startDir: path.Pathlike): path.Path?
	local dir = startDir
	while true do
		local candidate = path.join(dir, "flipbook")
		if fs.exists(candidate) then
			return candidate
		end
		local parent = path.dirname(dir)
		if tostring(parent) == tostring(dir) then
			return nil
		end
		dir = parent
	end
end

local args = cli.parser()
args:add("flipbook", "option", {
	help = "path to the Flipbook checkout to receive the development build",
})
args:parse({ ... })

local repoRoot = path.resolve(process.cwd())
local requestedFlipbookRoot = args:get("flipbook")
local flipbookRoot = if requestedFlipbookRoot
	then path.resolve(requestedFlipbookRoot)
	else findFlipbookRoot(path.dirname(repoRoot))

if not flipbookRoot then
	error(`could not find a flipbook folder beside {repoRoot} or its parents. Pass a checkout with --flipbook <path>`)
elseif not fs.exists(flipbookRoot) then
	error(`could not find Flipbook at {flipbookRoot}. Pass a checkout with --flipbook <path>`)
end
logger.info(`using Flipbook at {flipbookRoot}`)

logger.info("building Storyteller")
run("lute", {
	"run",
	"build",
	"--channel",
	"dev",
})

overlayWallyPackage({
	package = "flipbook-labs/storyteller",
	build = path.join(repoRoot, "dist"),
	manifest = path.join(repoRoot, "wally.toml"),
	target = flipbookRoot,
})
