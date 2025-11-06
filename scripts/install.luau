local run = require("./lib/run")

local project = require("@repo/project")

local LUAU_PACKAGES_PATH = "LuauPackages"

local function installWallyPackages()
	run("wally", { "install" })
	run("rojo", { "sourcemap", project.ROJO_BUILD_PROJECT, "-o", "sourcemap.json" })
	run("wally-package-types", { "--sourcemap", "sourcemap.json", "Packages" })
end

local function installLuteBatteries()
	local commit = "7b4e269"
	local batteries = {
		"cli.luau",
		"toml.luau",
	}

	local dest = `{LUAU_PACKAGES_PATH}/batteries`
	run("mkdir", { "-p", dest })
	for _, battery in batteries do
		run("curl", { "-LO", `https://raw.githubusercontent.com/luau-lang/lute/{commit}/batteries/{battery}` }, {
			cwd = dest,
		})
	end
end

installWallyPackages()
installLuteBatteries()
