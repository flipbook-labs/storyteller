local CodeQuality = require("@lpm/code-quality@v0.8.0")
local FlipbookBatteries = require("@lpm/flipbook-batteries@v0.13.1")
local cli = require("@lpm/batteries@v1.0.1-nightly.20261115/cli")
local fs = require("@std/fs")
local process = require("@std/process")

local logger = require("@repo/.lute/lib/logger")
local project = require("@repo/project")

local copyInto = FlipbookBatteries.copyInto
local dotenv = FlipbookBatteries.dotenv
local find = FlipbookBatteries.find
local mkdir = FlipbookBatteries.mkdir
local rmdir = FlipbookBatteries.rmdir
local run = FlipbookBatteries.run
local watch = FlipbookBatteries.watch

dotenv()

local args = cli.parser()

args:add("channel", "option", {
	help = "channel to build for",
	aliases = { "c" },
	default = "prod",
})
args:add("output", "option", {
	help = "Full path to the rbxm file to build",
	aliases = { "o" },
	default = "Storyteller.rbxm",
})
args:add("watch", "flag", {
	help = "Watch for changes and recompile automatically",
	aliases = { "w" },
})

args:parse({ ... })

local channel = args:get("channel")
assert(channel == "dev" or channel == "prod", `bad value for channel (must be one of "dev" or "prod", got "{channel}")`)

local output = args:get("output")
assert(typeof(output) == "string", `bad value for output (string expected, got {typeof(output)})`)

local WALLY_BUILD_DIR = ".build/wally"

local PRUNED_FILE_PATTERNS = {
	"%.spec%.luau",
	"%.story%.luau",
	"%.storybook%.luau",
	"jest%.config%.luau",
}

local function buildWallyPackage()
	logger.debug("packaging for Wally")
	rmdir(WALLY_BUILD_DIR)
	mkdir(WALLY_BUILD_DIR)

	local archivePath = `{WALLY_BUILD_DIR}/package.zip`

	run("wally", { "package", "--output", archivePath })
	run("unzip", { archivePath, "-d", WALLY_BUILD_DIR }, {
		stdio = "default",
	})

	fs.remove(archivePath)
end

local function build()
	logger.info(`building for the {channel} channel`)

	logger.debug("resetting the build directory")
	if fs.exists(project.BUILD_PATH) and fs.type(project.BUILD_PATH) == "dir" then
		rmdir(project.BUILD_PATH)
	end
	copyInto(project.SOURCE_PATH, project.BUILD_PATH)

	--[[
		CodeQuality's build, below, turns the copy in `dist/` into code Roblox
		can run. To turn a string require into a `require(script...)` path, it
		has to know which Roblox instance each file becomes. It reads that from
		this Rojo sourcemap of `build.project.json`, which mounts `src/` as
		`Storyteller` inside `Packages`. The sourcemap names files in `src/`, so
		`sourceFolder` and `buildFolder` tell the build to look up each file in
		`dist/` by its path in `src/`.
	]]
	run("rojo", {
		"sourcemap",
		project.ROJO_BUILD_PROJECT,
		"-o",
		project.BUILD_SOURCEMAP_PATH,
	})

	CodeQuality.build({
		sourceFolder = project.SOURCE_PATH,
		buildFolder = project.BUILD_PATH,
		sourcemap = project.BUILD_SOURCEMAP_PATH,
	})

	if channel == "prod" then
		logger.debug("pruning test and story files from the prod build")
		rmdir(`{project.BUILD_PATH}/test-utils`)
		rmdir(`{project.BUILD_PATH}/e2e`)

		for _, prunedFilePattern in PRUNED_FILE_PATTERNS do
			local prunedFiles = find(project.BUILD_PATH, prunedFilePattern)
			for _, specFile in prunedFiles do
				fs.remove(specFile)
			end
		end
	end

	run("rojo", { "build", "-o", output })

	buildWallyPackage()

	logger.info(`built {output}`)
end

build()

if args:has("watch") then
	logger.info("watching for changes")
	watch({
		roots = {
			`{process.cwd()}/src`,
			`{process.cwd()}/workspace`,
		},
		excludedFilePatterns = {
			".*Packages",
			"build",
		},
		onChanged = build,
	})
end
