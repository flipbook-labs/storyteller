--[[
	This script is solely for taking our dev build of Storyteller and overlaying
	it on Flipbook's install. This is only needed because Wally doesn't support
	path/git dependencies, so we have to make our own shim.
]]

local FlipbookBatteries = require("@luaupkg/flipbook-batteries")
local fs = require("@std/fs")
local path = require("@std/path")

local run = FlipbookBatteries.run

local BUNDLE_DIR_NAME = "dist"

local args = { ... }

local repoRoot = path.dirname(path.dirname(path.resolve(args[1])))
local src = path.resolve(path.join("./", BUNDLE_DIR_NAME))
local flipbookRoot = path.resolve(path.join(repoRoot, "../flipbook"))

if not fs.exists(flipbookRoot) then
	error(
		`could not find Flipbook at {flipbookRoot}. Make sure your checkout is parented to the same directory as Storyteller`
	)
end

local flipbookPackageIndex = path.join(flipbookRoot, "Packages/_Index")
local storytellerInstallation = FlipbookBatteries.find(flipbookPackageIndex, "^storyteller$")[1]

if not fs.exists(storytellerInstallation) then
	error("could not find an installation of Storyteller in Flipbook's package index")
end

local dest = path.join(storytellerInstallation, BUNDLE_DIR_NAME)

fs.removedirectory(dest, {
	recursive = true,
})

run("cp", { "-R", src, dest })

print(`successfully installed to {dest}`)
