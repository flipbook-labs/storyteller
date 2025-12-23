local FlipbookBatteries = require("@luaupkg/flipbook-batteries")
local cli = require("@luaupkg/batteries/cli")
local fs = require("@lute/fs")
local process = require("@lute/process")

local compile = require("./lib/compile")
local project = require("@repo/project")

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
	compile()

	local prunedFilePatterns = {
		"%.spec%.luau",
		"%.story%.luau",
		"%.storybook%.luau",
		"jest%.config%.luau",
	}

	if channel == "prod" then
		rmdir(`{project.BUILD_PATH}/test-utils`)
		rmdir(`{project.BUILD_PATH}/e2e`)

		for _, prunedFilePattern in prunedFilePatterns do
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
