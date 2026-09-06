--[[
	This script is solely for taking our dev build of Storyteller and overlaying
	it on Flipbook's install. This is only needed because Wally doesn't support
	path/git dependencies, so we have to make our own shim.
]]

local FlipbookBatteries = require("@luaupkg/FlipbookBatteries@v0.12.0")
local cli = require("@batteries/cli")
local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local process = require("@std/process")

local run = FlipbookBatteries.run
local copyInto = FlipbookBatteries.copyInto
local find = FlipbookBatteries.find

local WALLY_PACKAGE_NAME_PATTERN = "^storyteller$"
local BUNDLE_DIR_NAME = "dist"
local PACKAGES_DIR_NAME = "Packages"
local SOURCEMAP_FILE_NAME = "sourcemap.json"
local SOURCEMAP_PROJECT_FILE_NAME = "sourcemap.project.json"
local TYPE_LINK_BUILD_DIR_NAME = "storyteller-package-types"

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
end

local function refreshFlipbookPackageTypes(flipbookRoot: path.Path, packageInstallation: path.Path)
	local packageVersionRoot = path.dirname(packageInstallation)
	local packageVersionDirName = path.basename(packageVersionRoot) :: string
	local packageInstallationDirName = path.basename(packageInstallation) :: string
	local typeLinkBuildRoot = path.join(flipbookRoot, "build", TYPE_LINK_BUILD_DIR_NAME)
	local typeLinkPackagesRoot = path.join(typeLinkBuildRoot, PACKAGES_DIR_NAME)
	local typeLinkPackageInstallation =
		path.join(typeLinkPackagesRoot, "_Index", packageVersionDirName, packageInstallationDirName)

	if fs.exists(typeLinkBuildRoot) then
		fs.removeDirectory(typeLinkBuildRoot, {
			recursive = true,
		})
	end

	copyInto(packageInstallation, typeLinkPackageInstallation)
	fs.writeStringToFile(
		path.join(typeLinkPackagesRoot, "Storyteller.lua"),
		`return require(script.Parent._Index["{packageVersionDirName}"]["{packageInstallationDirName}"])`
	)
	fs.writeStringToFile(
		path.join(typeLinkBuildRoot, SOURCEMAP_PROJECT_FILE_NAME),
		json.serialize({
			name = "StorytellerPackageTypes",
			tree = {
				["$path"] = PACKAGES_DIR_NAME,
			},
		}, true)
	)

	run("rojo", { "sourcemap", SOURCEMAP_PROJECT_FILE_NAME, "-o", SOURCEMAP_FILE_NAME }, {
		cwd = typeLinkBuildRoot,
	})
	run("wally-package-types", { "--sourcemap", SOURCEMAP_FILE_NAME, PACKAGES_DIR_NAME }, {
		cwd = typeLinkBuildRoot,
	})
	fs.copy(
		path.join(typeLinkPackagesRoot, "Storyteller.lua"),
		path.join(flipbookRoot, PACKAGES_DIR_NAME, "Storyteller.lua")
	)
	fs.removeDirectory(typeLinkBuildRoot, {
		recursive = true,
	})
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
	print(`using Flipbook at {flipbookRoot}`)
else
	error(`could not find Flipbook at {tostring(flipbookRoot)}. Pass an explicit checkout with --flipbook <path>`)
end
flipbookRoot = path.resolve(flipbookRoot :: path.Path)

local flipbookPackageIndex = path.join(flipbookRoot, PACKAGES_DIR_NAME, "_Index")
local packageInstallation = find(flipbookPackageIndex, WALLY_PACKAGE_NAME_PATTERN)[1]

if not packageInstallation or not fs.exists(packageInstallation) then
	error("could not find an installation of this package in Flipbook's package index")
end

local dest = path.join(packageInstallation, BUNDLE_DIR_NAME)

fs.removeDirectory(dest, {
	recursive = true,
})

run("lute", { "run", "build", "--channel", "dev" })
copyInto(src, dest)
prepareFlipbookPackageInstallation(repoRoot, flipbookRoot, packageInstallation)
refreshFlipbookPackageTypes(flipbookRoot, packageInstallation)

print(`successfully installed to {dest}`)
