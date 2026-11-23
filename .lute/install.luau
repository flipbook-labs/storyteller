local path = require("@std/path")
local process = require("@std/process")

local project = require("@repo/project")

--[[
	`--vendor` copies each dependency and dev dependency in `pkg.luau` into a
	`.lpm/<key>@<rev>` folder, and the `lpm` alias in `.config.luau` points at
	`.lpm`. Scripts require a dependency through its folder, so a rev bump in
	`pkg.luau` also changes their require paths. When a vendored package
	requires through `@lpm`, the require uses the `lpm` alias of the project that
	vendored it, not one of its own. So any project that vendors such a package
	has to define the same alias.
	The following issue tracks removing that requirement:
	https://github.com/flipbook-labs/flipbook/issues/694

	The Wally steps below use helpers from flipbook-batteries, so the
	dependencies in `pkg.luau` are installed first.
]]
do
	local result = process.run({
		"lute",
		"pkg",
		"install",
		"--vendor",
	}, { stdio = "inherit" })
	assert(result.ok, "lute pkg install failed")
end

do
	local CodeQuality = require("@lpm/code-quality@v0.8.0")
	local FlipbookBatteries = require("@lpm/flipbook-batteries@v0.13.1")

	local run = FlipbookBatteries.run
	local find = FlipbookBatteries.find

	local function installWallyPackages()
		run("wally", { "install" })
		run("rojo", {
			"sourcemap",
			project.ROJO_BUILD_PROJECT,
			"-o",
			"sourcemap.json",
		})
		run("wally-package-types", { "--sourcemap", "sourcemap.json", "Packages" })
	end

	--[[
		Some of our Wally packages are written with string requires, which
		ModuleLoader and Jest can't load yet (flipbook-labs/module-loader#70).
		CodeQuality's `convertRequire` code mod rewrites them in place into
		instance requires. It looks each module up in the sourcemap that
		`installWallyPackages` writes, which covers `Packages/_Index`. vide loads
		a mock from `../test/mock` only outside Roblox and doesn't ship it, so
		that require stays as it is.
	]]
	local function patchStringRequires()
		local packages = {
			"^charm$",
			"^react%-charm$",
			"^vide$",
		}

		local sourceFolders: { string } = {}
		for _, package in packages do
			local packageRoot = find(`{project.PACKAGES_PATH}/_Index`, package)[1]
			assert(packageRoot, `no package found matching "{package}"`)
			print(`patching {packageRoot}`)
			table.insert(sourceFolders, path.format(path.join(packageRoot, "src")))
		end

		CodeQuality.transform(CodeQuality.Mod.ConvertRequire, sourceFolders, {
			sourcemap = "sourcemap.json",
			ignore = "../test/mock",
		})
	end

	installWallyPackages()
	patchStringRequires()
end
