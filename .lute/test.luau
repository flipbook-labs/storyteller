local FlipbookBatteries = require("@lpm/flipbook-batteries@v0.14.0")
local cli = require("@lpm/batteries@v1.0.1-nightly.20261115/cli")
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")

local logger = require("@repo/.lute/lib/logger")
local project = require("@repo/project")

local dotenv = FlipbookBatteries.dotenv
local findAndReplace = FlipbookBatteries.findAndReplace
local run = FlipbookBatteries.run
local copyInto = FlipbookBatteries.copyInto

dotenv()

local args = cli.parser()

args:add("apiKey", "option", {
	help = "Open Cloud API key",
	aliases = { "k" },
})

args:add("filter", "option", {
	help = "Specify a filepath pattern to match for when running tests",
})

args:add("benchmarks", "flag", {
	help = "Run longrunning benchmark tests",
})

args:add("place", "option", {
	help = "Path to the test place file to build or run",
	default = tostring(path.join(system.tmpdir(), "tests-place.rbxl")),
})

args:add("build-only", "flag", {
	help = "Build the test place without running cloud tests",
})

args:add("run-only", "flag", {
	help = "Run cloud tests from an existing test place",
})

args:parse({ ... })

local isBuildOnly = args:has("build-only")
local isRunOnly = args:has("run-only")
if isBuildOnly and isRunOnly then
	logger.err("--build-only and --run-only cannot be used together")
	process.exit(1)
end

local placePath = args:get("place")
assert(typeof(placePath) == "string", `bad value for place (string expected, got {typeof(placePath)})`)

if not isRunOnly then
	logger.info("building the dev channel for testing")
	run("lute", {
		"run",
		"build",
		"--channel",
		"dev",
	})
	run("rojo", {
		"build",
		project.ROJO_TESTS_PROJECT,
		"--output",
		placePath,
	})
	logger.info(`built test place: {placePath}`)
end

if isBuildOnly then
	process.exit(0)
end

-- In the Strict workflow, pull request code builds this place. A missing path or
-- a directory there means the build didn't produce a place file, so the run
-- stops here instead of handing that path to Rocale.
if not fs.exists(placePath) or fs.type(placePath) ~= "file" then
	logger.err(`the test place must be a regular file: {placePath}`)
	process.exit(1)
end

local apiKey = process.env.ROBLOX_API_KEY or args:get("apiKey")
if not apiKey or apiKey == "" then
	logger.err(
		"A valid Open Cloud API key must be supplied with either the --apiKey flag or the ROBLOX_API_KEY environment variable"
	)
	process.exit(1)
end

local filter = args:get("filter")
if filter then
	logger.debug(`filtering tests by "{filter}"`)
end
if args:has("benchmarks") then
	logger.warn("running benchmarks; this run will take longer than usual")
end

local function createTestRunnerScript()
	local testRunnerPath = path.join(system.tmpdir(), "run-tests.luau")

	copyInto(".lute/tasks/run-tests.luau", testRunnerPath)

	if filter then
		findAndReplace(testRunnerPath, "_G.__JEST_TEST_PATH_PATTERN__", `"{filter}"`)
	end
	if args:has("benchmarks") then
		findAndReplace(testRunnerPath, "_G.RUN_BENCHMARKS", "true")
	end

	return testRunnerPath
end

logger.info("running tests")
local success, err = pcall(function()
	local testRunnerPath = createTestRunnerScript()

	return run("rocale", {
		"run",
		"--script",
		testRunnerPath,
		"--load.place",
		placePath,
		"--universeId",
		project.ROBLOX_UNIT_TESTING_UNIVERSE_ID,
		"--placeId",
		project.ROBLOX_UNIT_TESTING_PLACE_ID,
		"--output",
		`{system.tmpdir()}/tests.rbxl`,
	}, {
		env = {
			ROBLOX_API_KEY = tostring(apiKey),
		},
	})
end)

if not success then
	logger.err(err)
	process.exit(1)
end

logger.info("tests passed")
