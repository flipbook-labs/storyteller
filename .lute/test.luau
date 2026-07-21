local FlipbookBatteries = require("@luaupkg/FlipbookBatteries@v0.12.0")
local cli = require("@batteries/cli")
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

args:parse({ ... })

local apiKey = process.env.ROBLOX_API_KEY or args:get("apiKey")
if not apiKey then
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

logger.info("building the dev channel for testing")
run("lute", { "run", "build", "--channel", "dev" })

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
		"--load.project",
		project.ROJO_TESTS_PROJECT,
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
