local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")

local loomConfig = require("@repo/loom.config")
local project = require("@repo/project")

local LUAU_PACKAGES_PATH = "LuauPackages"

local function move(src: path.pathlike, dest: path.pathlike)
	local res = process.run({ "mv", tostring(src), tostring(dest) }, {
		stdio = "inherit",
	})
	assert(res.ok, res.stderr)
end

-- Install Loom dependencies first since the rest of the script depends on them
do
	local res = process.run({ "lute", "pkg", "install" }, {
		stdio = "inherit",
	})
	assert(res.ok, res.stderr)

	fs.removedirectory(LUAU_PACKAGES_PATH, {
		recursive = true,
	})
	fs.createdirectory(LUAU_PACKAGES_PATH)

	-- Since Wally and Loom both write to the Packages dir, we disambiguate our
	-- packages by moving all the Loom dependencies into LuauPackages
	for dependencyName in loomConfig.package.dependencies :: { [string]: unknown } do
		move(path.join(project.PACKAGES_PATH, dependencyName), path.join(LUAU_PACKAGES_PATH, dependencyName))
	end
end

do
	local FlipbookBatteries = require("@luaupkg/flipbook-batteries")

	local run = FlipbookBatteries.run
	local find = FlipbookBatteries.find
	local findAndReplace = FlipbookBatteries.findAndReplace

	local function installWallyPackages()
		run("wally", { "install" })
		run("rojo", { "sourcemap", project.ROJO_BUILD_PROJECT, "-o", "sourcemap.json" })
		run("wally-package-types", { "--sourcemap", "sourcemap.json", "Packages" })
	end

	local function installRobloxPackages()
		run("roblox-packages", {
			"install",
			"RobloxPackagesTmp",
			"--version",
			"0.700.0.7000935",

			"-d",
			"Signals",
			"-d",
			"SignalsReact",
		})

		local dest = project.ROBLOX_PACKAGES_PATH
		if fs.exists(dest) and fs.type(dest) == "dir" then
			run("rm", { "-rf", dest })
		end
		run("mv", { "RobloxPackagesTmp/Packages", dest })
		run("rm", { "-rf", "RobloxPackagesTmp" })

		-- Patch React and RoactCompat dependencies to use ours
		for _, name in { "React", "RoactCompat", "Roact" } do
			local linkers = find(dest, `^{name}%..*`)

			for _, linker in linkers do
				-- All Roact linkers in RobloxPackages point to Roblox's
				-- RoactCompat, so we need to update them to point to ours instead.
				if name == "Roact" then
					name = "RoactCompat"
				end

				findAndReplace(
					linker,
					"local PackageIndex = .*_Index",
					'local Root = script:FindFirstAncestor("RobloxPackages")'
				)
				findAndReplace(
					linker,
					"local Package = require%(.*%)",
					`local Package = require(Root.Parent.Parent.{name})`
				)
			end
		end
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

	installRobloxPackages()
	installWallyPackages()
	installLuteBatteries()
end
