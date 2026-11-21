local CodeQuality = require("@lpm/code-quality@v0.6.0")
local FlipbookBatteries = require("@lpm/flipbook-batteries@v0.13.1")
local cli = require("@lpm/batteries@v1.0.1-nightly.20261115/cli")
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")

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

-- The build turns a copy of `src/` in `dist/` into code Roblox can run, using
-- CodeQuality's code mods. `lute transform` runs one mod over every file and
-- rewrites them in place. `convertRequire` turns string requires into
-- `require(script...)` paths. The rest fold constant expressions and remove the
-- code that can never run. They go in the order CodeQuality's README lists,
-- since a later mod cleans up what an earlier one leaves behind, such as the
-- empty `do ... end` blocks `removeEmptyDo` removes.
local function transform(mod: string, ...: string)
	run("lute", {
		"transform",
		path.format(path.join(CodeQuality.MODS_PATH, `{mod}.luau`)),
		project.BUILD_PATH,
		"--",
		...,
	})
end

local function build()
	if fs.exists(project.BUILD_PATH) and fs.type(project.BUILD_PATH) == "dir" then
		rmdir(project.BUILD_PATH)
	end
	copyInto(project.SOURCE_PATH, project.BUILD_PATH)

	-- `convertRequire` reads which instance each file becomes from a Rojo
	-- sourcemap of `build.project.json`, which mounts `src/` as `Storyteller` inside `Packages`.
	-- The sourcemap names files in `src/`, so `--sourceFolder` and
	-- `--buildFolder` tell the mod to look up each file in `dist/` by its path
	-- in `src/`.
	run("rojo", {
		"sourcemap",
		project.ROJO_BUILD_PROJECT,
		"-o",
		project.BUILD_SOURCEMAP_PATH,
	})

	transform(
		"convertRequire",
		"--sourcemap",
		project.BUILD_SOURCEMAP_PATH,
		"--sourceFolder",
		project.SOURCE_PATH,
		"--buildFolder",
		project.BUILD_PATH
	)
	transform("computeExpression")
	transform("removeUnusedIfBranch")
	transform("removeUnusedWhile")
	transform("filterAfterEarlyReturn")
	transform("removeNilDeclaration")
	transform("removeEmptyDo")

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
