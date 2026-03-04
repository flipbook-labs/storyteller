local fs = require("@lute/fs")
local process = require("@lute/process")

local project = require("@repo/project")

local LUAU_PACKAGES_PATH = "LuauPackages"

-- Install flipbook-batteries first because it has a lot of the useful functions
-- we need when installing the rest of our packages
do
	local function installFlipbookBatteries()
		local res = process.run({
			"curl",
			"-LO",
			"https://github.com/flipbook-labs/flipbook-batteries/releases/download/v0.4.1/flipbook-batteries.zip",
		}, {
			cwd = LUAU_PACKAGES_PATH,
		})
		assert(res.ok, res.stderr)

		res = process.run({
			"unzip",
			"flipbook-batteries.zip",
		}, {
			cwd = LUAU_PACKAGES_PATH,
		})
		assert(res.ok, res.stderr)

		res = process.run({ "rm", "-rf", `{LUAU_PACKAGES_PATH}/flipbook-batteries.zip` }, {
			stdio = "inherit",
		})
		assert(res.ok, res.stderr)
	end

	local res = process.run({ "rm", "-rf", LUAU_PACKAGES_PATH }, {
		stdio = "inherit",
	})
	assert(res.ok, res.stderr)

	res = process.run({ "mkdir", LUAU_PACKAGES_PATH })
	assert(res.ok, res.stderr)

	installFlipbookBatteries()
end

do
	local FlipbookBatteries = require("@luaupkg/flipbook-batteries")

	local run = FlipbookBatteries.run

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
end
