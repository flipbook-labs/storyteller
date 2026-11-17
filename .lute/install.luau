local fs = require("@std/fs")
local json = require("@std/json")
local luau = require("@std/luau")
local path = require("@std/path")
local process = require("@std/process")

local project = require("@repo/project")

local function getDescendants(dirPath: path.Pathlike): { path.Path }
	if fs.type(dirPath) ~= "dir" then
		return {}
	end

	local function reduce(rootPath: path.Path, accumulator: { path.Path }): { path.Path }
		for _, child in fs.listDirectory(rootPath) do
			local childPath = path.join(rootPath, child.name)
			table.insert(accumulator, childPath)

			if child.type == "dir" then
				reduce(childPath, accumulator)
			end
		end
		return accumulator
	end

	return reduce(path.resolve(dirPath), {})
end

local LOCKFILE_PATH = "pkg.lock.luau"
local VENDOR_PATH = "LuauPackages"

-- `lute pkg install` puts each dependency in the Loom store, `~/.loom/store`,
-- under a folder whose name includes hashes of its source and rev. Requires
-- resolve only through aliases in `.config.luau`, which can't name a dependency
-- from the lockfile. So after installing, this copies each dependency into
-- `LuauPackages/<name>`, using its name from `pkg.luau`, and `.config.luau`
-- aliases those folders. https://github.com/flipbook-labs/flipbook/issues/689
-- tracks removing this once Lute resolves dependencies by name.
--
-- A vendored package's own `.config.luau` aliases its dependencies the same
-- way, as `./LuauPackages/<name>` inside its folder. So each package's
-- dependencies are copied into its own `LuauPackages/`, all the way down.
--
-- The folder isn't `Packages/` because Wally installs the Roblox runtime
-- dependencies there.

type Lockfile = {
	dependencies: { [string]: string },
	devDependencies: { [string]: string }?,
	packages: { [string]: { installPath: string, dependencies: { [string]: string } } },
}

-- The lockfile writes `@pkg/` for the store, and the path of a dependency
-- without a `target` ends in `/.`.
local function getStorePath(lockfile: Lockfile, key: string): path.Path
	local installPath = lockfile.packages[key].installPath
	local relative = installPath:gsub("^@pkg/", ""):gsub("/%.$", "")
	return path.join(process.homedir(), ".loom", "store", relative)
end

local function copyDirectory(src: path.Path, dest: path.Path)
	fs.createDirectory(dest, { makeParents = true })
	for _, entry in fs.listDirectory(src) do
		local from = path.join(src, entry.name)
		local to = path.join(dest, entry.name)
		if entry.type == "dir" then
			copyDirectory(from, to)
		else
			fs.copy(from, to)
		end
	end
end

local function vendor(lockfile: Lockfile, key: string, dest: path.Path)
	copyDirectory(getStorePath(lockfile, key), dest)
	for name, dependencyKey in lockfile.packages[key].dependencies do
		vendor(lockfile, dependencyKey, path.join(dest, VENDOR_PATH, name))
	end
end

-- The Wally steps below use helpers from FlipbookBatteries, which they require
-- through its vendored alias. So the Loom dependencies are vendored first.
do
	local result = process.run({ "lute", "pkg", "install" }, { stdio = "inherit" })
	assert(result.ok, "lute pkg install failed")

	local lockfile: Lockfile = luau.loadModule(LOCKFILE_PATH)

	-- Clearing the folder first drops dependencies that `pkg.luau` no longer lists.
	if fs.exists(VENDOR_PATH) then
		fs.removeDirectory(VENDOR_PATH, { recursive = true })
	end

	for _, dependencies in { lockfile.dependencies, lockfile.devDependencies or {} } do
		for name, key in dependencies do
			vendor(lockfile, key, path.join(VENDOR_PATH, name))
		end
	end

	print(`Vendored dependencies into {VENDOR_PATH}`)
end

do
	local FlipbookBatteries = require("@flipbook-batteries")

	local run = FlipbookBatteries.run
	local find = FlipbookBatteries.find
	local findAndReplace = FlipbookBatteries.findAndReplace

	local function installWallyPackages()
		run("wally", { "install" })
		run("rojo", { "sourcemap", project.ROJO_BUILD_PROJECT, "-o", "sourcemap.json" })
		run("wally-package-types", { "--sourcemap", "sourcemap.json", "Packages" })
	end

	-- Some of our Wally packages are written with string requires which are not
	-- yet supported by ModuleLoader or Jest. To allow us to still use these
	-- packages, this function patches them using darklua to resolve the string
	-- requires to Roblox ones
	local function patchStringRequires()
		local packages = {
			"^charm$",
			"^react%-charm$",
			"^vide$",
		}

		for _, package in packages do
			local packageRoot = find(`{project.PACKAGES_PATH}/_Index`, package)[1]

			assert(packageRoot, `no package found matching "{package}"`)

			print(`patching {packageRoot}`)

			local darkluaConfig = {
				process = {
					{
						rule = "convert_require",
						current = {
							name = "luau",
						},
						target = {
							name = "roblox",
							indexing_style = "property",
						},
					},
				},
			}

			local handle = fs.open(`{packageRoot}/.darklua.json`, "w+")
			fs.write(handle, json.serialize(darkluaConfig, true))
			fs.close(handle)

			run("darklua", { "process", "src", "src" }, {
				cwd = packageRoot,
			})

			-- Darklua doesn't seem to handle `./Foo` paths without a sourcemap,
			-- and getting the sourcemap working is proving difficult. So the
			-- following just does a quick pass to convert `"./Foo"` into
			-- `script.Parent.Foo`
			for _, descendant in getDescendants(packageRoot) do
				if path.extname(descendant) == ".luau" then
					findAndReplace(descendant, `require%("%./(%w+)"%)`, "require(script.Parent.%1)")
				end
			end
		end
	end

	installWallyPackages()
	patchStringRequires()
end
