local compile = require("./lib/compile")
local parseArgs = require("./lib/parseArgs")
local process = require("@lune/process")
local project = require("../project")
local run = require("./lib/run")
local watch = require("./lib/watcher/watch")

local args = parseArgs(process.args)

local target = if args.target then args.target else "prod"
assert(target == "dev" or target == "prod", `bad value for target (must be one of "dev" or "prod", got "{target}")`)

local output = if args.output then args.output else project.MODEL_FILENAME
assert(typeof(output) == "string", `bad value for output (string expected, got {typeof(output)})`)

local WALLY_BUILD_DIR = ".build/wally"

local function buildWallyPackage()
	run("rm", { "-rf", WALLY_BUILD_DIR })

	run("mkdir", { "-p", WALLY_BUILD_DIR })

	local archivePath = `{WALLY_BUILD_DIR}/package.tar.gz`
	run("wally", { "package", "--output", archivePath })

	run("ls", { "-al", WALLY_BUILD_DIR })

	run("tar", { "-xvf", archivePath, "-C", WALLY_BUILD_DIR })

	run("ls", { "-al", WALLY_BUILD_DIR })

	run("rm", { archivePath })
end

local function build()
	run("rm", { "-rf", project.BUILD_PATH })
	compile(target)

	if target == "prod" then
		run("find", { project.BUILD_PATH, "-name", "*.spec.luau", "-type", "f", "-delete" })
		run("rm", { "-rf", `{project.BUILD_PATH}/test-utils` })
	end

	run("rojo", { "build", "-o", output })

	buildWallyPackage()
end

build()

if args.watch then
	watch({
		filePatterns = {
			"src/.*%.luau",
			"example/.*%.luau",
		},
		onChanged = build,
	})
end
