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

local CONFIG_PATH = ".config.luau"
local LOCKFILE_PATH = "pkg.lock.luau"

-- `lute pkg install` puts each dependency in the Loom store, `~/.loom/store`,
-- under a folder whose name includes hashes of its source and rev. A dependency
-- with a `target` in `pkg.luau` installs only that subfolder, like Lute's
-- `batteries`. Requires resolve only through aliases in `.config.luau`, which
-- can't name a dependency from the lockfile. So after installing, this copies
-- each dependency's store path from the lockfile into its alias.
-- https://github.com/flipbook-labs/flipbook/issues/689 tracks removing this.
--
-- The hashes depend only on the source and rev, so the paths are the same on
-- every machine, and `.config.luau` commits them. A consumer that installs this
-- package from the store resolves its aliases through those committed paths,
-- without running this script.
--
-- Keys are aliases in `.config.luau`, and values are dependency names in
-- `pkg.luau`. `agent-skills` points agents at the shared skills library, and
-- `lute run lint` reads the CodeQuality rules through `code-quality`.
local DEPENDENCY_ALIASES: { [string]: string } = {
	batteries = "Batteries",
	["flipbook-batteries"] = "FlipbookBatteries",
	["agent-skills"] = "AgentSkills",
	["code-quality"] = "CodeQuality",
}

type Lockfile = {
	dependencies: { [string]: string },
	devDependencies: { [string]: string }?,
	packages: { [string]: { installPath: string } },
}

-- The lockfile writes `@pkg/` for the store, and the path of a dependency
-- without a target ends in `/.`.
local function getStorePath(lockfile: Lockfile, name: string): string
	local key = lockfile.dependencies[name] or (lockfile.devDependencies and lockfile.devDependencies[name])
	assert(key, `{name} is not a dependency in {LOCKFILE_PATH}`)

	local installPath = lockfile.packages[key].installPath
	local storePath = installPath:gsub("^@pkg/", "~/.loom/store/"):gsub("/%.$", "")
	return storePath
end

-- The Wally steps below use helpers from FlipbookBatteries, which they require
-- through its alias. So the Loom dependencies are installed and the aliases
-- written first.
do
	local result = process.run({ "lute", "pkg", "install" }, { stdio = "inherit" })
	assert(result.ok, "lute pkg install failed")

	local lockfile: Lockfile = luau.loadModule(LOCKFILE_PATH)
	local config = fs.readFileToString(CONFIG_PATH)

	for alias, name in DEPENDENCY_ALIASES do
		local storePath = getStorePath(lockfile, name)

		-- An alias that isn't a plain identifier, like `agent-skills`, is written
		-- as a quoted key, `["agent-skills"]`. Each alias sits on its own line, so
		-- the match starts at a line break.
		local key = if alias:match("^[%a_][%w_]*$") then alias else `["{alias}"]`
		local keyPattern = key:gsub("%p", "%%%0")
		local updated, count = config:gsub(`(\n%s*{keyPattern}%s*=%s*")[^"]*(")`, `%1{storePath}%2`)
		assert(count == 1, `Expected one "{alias}" alias in {CONFIG_PATH}, found {count}`)
		config = updated
	end

	fs.writeStringToFile(CONFIG_PATH, config)
	print(`Wrote dependency aliases to {CONFIG_PATH}`)
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
