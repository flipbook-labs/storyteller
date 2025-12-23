local FlipbookBatteries = require("@luaupkg/flipbook-batteries")
local cli = require("@luaupkg/batteries/cli")
local process = require("@lute/process")

local project = require("@repo/project")

local dotenv = FlipbookBatteries.dotenv
local findAndReplace = FlipbookBatteries.findAndReplace
local run = FlipbookBatteries.run

dotenv()

local args = cli.parser()

args:add("apiKey", "option", {
	help = "Open Cloud API key",
	aliases = { "k" },
})

args:add("filter", "option", {
	help = "Specify a filepath pattern to match for when running tests",
})

args:parse({ ... })

local apiKey = process.env.ROBLOX_API_KEY or args:get("apiKey")
if not apiKey then
	print(
		"err: A valid Open Cloud API key must be supplied with either the --apiKey flag or the ROBLOX_API_KEY environment variable"
	)
	process.exit(1)
end

local filter = args:get("filter")

run("lute", { "scripts/build.luau", "--channel", "dev" })
run("rojo", { "build", "tests.project.json", "-o", "tests.rbxl" })

local function createTestRunnerScript()
	local testRunnerPath = ".build/tasks/run-tests.luau"

	run("mkdir", { "-p", ".build/tasks" })
	run("cp", { "-R", "scripts/tasks/run-tests.luau", testRunnerPath })
	if filter then
		findAndReplace(testRunnerPath, "_G.__JEST_TEST_PATH_PATTERN__", `"{filter}"`)
	end

	return testRunnerPath
end

local success, err = pcall(function()
	local testRunnerPath = createTestRunnerScript()

	return run("python3", {
		"scripts/open-cloud/upload_and_run_task.py",
		"tests.rbxl",
		testRunnerPath,
	}, {
		env = {
			ROBLOX_UNIVERSE_ID = project.ROBLOX_UNIT_TESTING_UNIVERSE_ID,
			ROBLOX_PLACE_ID = project.ROBLOX_UNIT_TESTING_PLACE_ID,
			ROBLOX_API_KEY = tostring(apiKey),
		},
	})
end)

run("rm", { "tests.rbxl" })

if not success then
	print(err)
	process.exit(1)
end
