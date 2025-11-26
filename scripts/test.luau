local cli = require("@batteries/cli")
local json = require("@std/json")
local process = require("@lute/process")

local compile = require("./lib/compile")
local dotenv = require("./lib/dotenv")
local run = require("./lib/run")

local project = require("@repo/project")

dotenv()

local args = cli.parser()

args:add("apiKey", "option", {
	help = "Open Cloud API key",
	aliases = { "k" },
})

args:parse({ ... })

local apiKey = process.env.ROBLOX_API_KEY or args:get("apiKey")
if not apiKey then
	print(
		"err: A valid Open Cloud API key must be supplied with either the --apiKey flag or the ROBLOX_API_KEY environment variable"
	)
	process.exit(1)
end

compile("dev")

run("rojo", { "build", "tests.project.json", "-o", "tests.rbxl" })

local env = {
	RBXCLOUD_API_KEY = tostring(apiKey),
}

run("rbxcloud", {
	"experience",
	"publish",
	"--filename",
	"tests.rbxl",
	"--version-type",
	"saved",

	"--universe-id",
	project.ROBLOX_UNIT_TESTING_UNIVERSE_ID,
	"--place-id",
	project.ROBLOX_UNIT_TESTING_PLACE_ID,
}, {
	env = env,
})

local luauExecuteOut = run("rbxcloud", {
	"luau",
	"execute",
	"--filepath",
	"scripts/tasks/run-tests.luau",

	"--universe-id",
	project.ROBLOX_UNIT_TESTING_UNIVERSE_ID,
	"--place-id",
	project.ROBLOX_UNIT_TESTING_PLACE_ID,
}, {
	env = env,
})

local json = json.deserialize(luauExecuteOut)

-- TODO: Parse command output to get the task ID to wait for tests to finish
-- TODO: Parse test output to determine if we should error or not
