--[[
	This script is solely for taking our dev build of Storyteller and overlaying
	it on Flipbook's install. This is only needed because Wally doesn't support
	path/git dependencies, so we have to make our own shim.
]]

local FlipbookBatteries = require("@luaupkg/FlipbookBatteries@v0.12.0")
local cli = require("@batteries/cli")
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")

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

local flipbookPackageIndex = path.join(flipbookRoot, "Packages/_Index")
local packageInstallation = find(flipbookPackageIndex, WALLY_PACKAGE_NAME_PATTERN)[1]

if not packageInstallation or not fs.exists(packageInstallation) then
	error("could not find an installation of this package in Flipbook's package index")
end

local dest = path.join(packageInstallation, BUNDLE_DIR_NAME)
local packageLink = path.join(flipbookRoot, "Packages/Storyteller.lua")

fs.removeDirectory(dest, {
	recursive = true,
})

run("lute", { "run", "build", "--channel", "dev" })
copyInto(src, dest)

local packageVersionRoot = path.dirname(packageInstallation)
local sourceDependencies = path.join(repoRoot, "Packages")
copyInto(path.join(sourceDependencies, "_Index"), flipbookPackageIndex)
for _, targetLink in find(packageVersionRoot, "%.lua$") do
	local sourceLink = path.join(sourceDependencies, path.basename(targetLink))
	if not fs.exists(sourceLink) then
		continue
	end

	local handle = fs.open(sourceLink)
	local contents = fs.read(handle)
	fs.close(handle)
	contents = contents:gsub("script%.Parent%._Index", "script.Parent.Parent")

	handle = fs.open(targetLink, "w+")
	fs.write(handle, contents)
	fs.close(handle)
end
fs.copy(path.join(repoRoot, ".build/wally/wally.toml"), path.join(packageInstallation, "wally.toml"))

if fs.exists(packageLink) then
	local handle = fs.open(packageLink)
	local contents = fs.read(handle)
	fs.close(handle)

	local missingExports = {}
	for _, exportName in
		{
			"StoryEntry<T>",
			"StoryGroup<T>",
			"StoryModule<T>",
			"StoryRequest",
			"StoryModuleRecord",
			"StoryModuleRecords",
		}
	do
		local typeName = exportName:match("^[^<]+") :: string
		if not contents:find(`export type {typeName}`, 1, true) then
			table.insert(missingExports, `export type {exportName} = REQUIRED_MODULE.{exportName}`)
		end
	end

	if #missingExports > 0 then
		contents =
			contents:gsub("return REQUIRED_MODULE", `{table.concat(missingExports, "\n")}\nreturn REQUIRED_MODULE`, 1)
		handle = fs.open(packageLink, "w+")
		fs.write(handle, contents)
		fs.close(handle)
	end
end

print(`successfully installed to {dest}`)
