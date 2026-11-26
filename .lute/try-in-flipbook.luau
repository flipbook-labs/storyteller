--[[
	This script is solely for taking our dev build of Storyteller and overlaying
	it on Flipbook's install. This is only needed because Wally doesn't support
	path/git dependencies, so we have to make our own shim.
]]

local FlipbookBatteries = require("@lpm/flipbook-batteries@v0.13.1")
local cli = require("@lpm/batteries@v1.0.1-nightly.20261115/cli")
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")

local logger = require("@repo/.lute/lib/logger")

local run = FlipbookBatteries.run
local copyInto = FlipbookBatteries.copyInto
local find = FlipbookBatteries.find

local WALLY_PACKAGE_NAME_PATTERN = "^storyteller$"
local BUNDLE_DIR_NAME = "dist"

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

local function prepareFlipbookPackageInstallation(
	repoRoot: path.Path,
	flipbookRoot: path.Path,
	packageInstallation: path.Path
)
	local packageVersionRoot = path.dirname(packageInstallation)
	local sourceModuleLoaderLink = path.join(flipbookRoot, "Packages/ModuleLoader.lua")
	local targetModuleLoaderLink = path.join(packageVersionRoot, "ModuleLoader.lua")
	local moduleLoaderLink = fs.readFileToString(sourceModuleLoaderLink)
		:gsub("script%.Parent%._Index", "script.Parent.Parent")
	fs.writeStringToFile(targetModuleLoaderLink, moduleLoaderLink)
	fs.copy(path.join(repoRoot, ".build/wally/wally.toml"), path.join(packageInstallation, "wally.toml"))

	local packageLink = path.join(flipbookRoot, "Packages/Storyteller.lua")
	if not fs.exists(packageLink) then
		return
	end

	local typeExports = {}
	for line in fs.readFileToString(path.join(repoRoot, "src/init.luau")):gmatch("[^\n]+") do
		local typeName, generics = line:match("^export type ([%w_]+)(%b<>)")
		typeName = typeName or line:match("^export type ([%w_]+)")
		if typeName then
			local params = if generics then generics:gsub("%s*=[^,>]*", "") else ""
			table.insert(typeExports, `export type {typeName}{params} = REQUIRED_MODULE.{typeName}{params}`)
		end
	end

	local packageRequire = fs.readFileToString(packageLink):match("require%b()")
	assert(packageRequire, `expected a require in {packageLink}`)
	fs.writeStringToFile(
		packageLink,
		`local REQUIRED_MODULE = {packageRequire}\n{table.concat(typeExports, "\n")}\nreturn REQUIRED_MODULE\n`
	)
end

local args = cli.parser()
args:add("flipbook", "option", {
	help = "path to the Flipbook checkout to receive the development build",
})
args:parse({ ... })

local repoRoot = path.resolve(process.cwd())
local src = path.resolve(path.join("./", BUNDLE_DIR_NAME))
local requestedFlipbookRoot = args:get("flipbook")
local flipbookRoot = if requestedFlipbookRoot
	then path.resolve(requestedFlipbookRoot)
	else findFlipbookRoot(path.dirname(repoRoot))

if flipbookRoot and fs.exists(flipbookRoot) then
	logger.info(`using Flipbook at {flipbookRoot}`)
else
	error(`could not find Flipbook at {flipbookRoot}. Pass an explicit checkout with --flipbook <path>`)
end
flipbookRoot = path.resolve(flipbookRoot :: path.Path)

local flipbookPackageIndex = path.join(flipbookRoot, "Packages/_Index")
local packageInstallation = find(flipbookPackageIndex, WALLY_PACKAGE_NAME_PATTERN)[1]

if not packageInstallation or not fs.exists(packageInstallation) then
	error("could not find an installation of this package in Flipbook's package index")
end

local dest = path.join(packageInstallation, BUNDLE_DIR_NAME)

logger.debug(`removing the existing install at {dest}`)
fs.removeDirectory(dest, {
	recursive = true,
})

logger.info("building Storyteller")
run("lute", {
	"run",
	"build",
	"--channel",
	"dev",
})
copyInto(src, dest)
prepareFlipbookPackageInstallation(repoRoot, flipbookRoot, packageInstallation)

logger.info(`successfully installed to {dest}`)
