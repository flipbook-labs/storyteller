local process = require("@lune/process")

local run = require("./lib/run")

local function installPackageFromDisk(packageName: string, packagePath: string)
	local homePath = process.env.HOME
	assert(homePath, "no $HOME env var")

	local absPackagePath = run("realpath", { packagePath })

	run("rm", { `Packages/{packageName}.lua` })
	run("ln", { "-s", `{absPackagePath}/dist`, `Packages/{packageName}` })
end

run("wally", { "install" })

installPackageFromDisk("ModuleLoader", "../module-loader")

run("rojo", { "sourcemap", "build.project.json", "-o", "sourcemap.json" })
run("wally-package-types", { "--sourcemap", "sourcemap.json", "Packages" })
