local project = require("@repo/project")
local run = require("./lib/run")

local globalDefsPath = "globalTypes.d.luau"

run("curl", {
	"-s",
	"-o",
	globalDefsPath,
	"-O",
	"https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/master/scripts/globalTypes.d.lua",
})

local function analyzeLuauSource()
	run("luau-lsp", {
		"analyze",
		`--defs={globalDefsPath}`,
		"--settings=./.vscode/settings.json",
		"--platform=standard",
		"--flag:LuauSolverV2=true",
		project.SCRIPTS_PATH,
	})
end

local function analyzeRobloxSource()
	run("rojo", {
		"sourcemap",
		project.ROJO_BUILD_PROJECT,
		"-o",
		project.SOURCEMAP_PATH,
	})

	run("luau-lsp", {
		"analyze",
		`--sourcemap={project.SOURCEMAP_PATH}`,
		`--defs={globalDefsPath}`,
		"--settings=./.vscode/settings.json",
		project.SOURCE_PATH,
	})
end

analyzeLuauSource()
analyzeRobloxSource()
