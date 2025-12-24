local FlipbookBatteries = require("@luaupkg/flipbook-batteries")
local cli = require("@luaupkg/batteries/cli")
local fs = require("@lute/fs")
local process = require("@lute/process")

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
	if fs.exists(project.BUILD_PATH) and fs.type(project.BUILD_PATH) == "dir" then
		rmdir(project.BUILD_PATH)
	end
	mkdir(project.BUILD_PATH)

	copyInto(project.ROBLOX_PACKAGES_PATH, `{project.BUILD_PATH}/{project.ROBLOX_PACKAGES_PATH}`)

	run("rojo", {
		"sourcemap",
		project.ROJO_BUILD_PROJECT,
		"-o",
		project.DARKLUA_SOURCEMAP_PATH,
	})

	run("darklua", {
		"process",
		project.SOURCE_PATH,
		project.BUILD_PATH,
	})

	if channel == "prod" then
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
end

build()

if args:has("watch") then
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
