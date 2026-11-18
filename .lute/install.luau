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
-- can't name a dependency from the lockfile. So after installing, this writes
-- an alias for each dependency, named after its key in `pkg.luau`, pointing at
-- the store path the lockfile records for it.
-- https://github.com/flipbook-labs/flipbook/issues/689 tracks removing this.
--
-- The hashes depend only on the source and rev, so the paths are the same on
-- every machine, and `.config.luau` commits them. A consumer that installs this
-- package from the store resolves its aliases through those committed paths,
-- without running this script.
--
-- The aliases go between two marker comments in `.config.luau`. The first is
-- the line that links the issue above, and the second is `END_MARKER`. Every
-- line between them is replaced on each run, so aliases for removed
-- dependencies disappear too.
local END_MARKER = "-- End of aliases written by `lute run install`."

type Lockfile = {
	dependencies: { [string]: string },
	devDependencies: { [string]: string }?,
	packages: { [string]: { installPath: string, sourceKind: string } },
}

-- The lockfile writes `@pkg/` for the store, and the path of a dependency
-- without a target ends in `/.`.
local function getStorePath(installPath: string): string
	local storePath = installPath:gsub("^@pkg/", "~/.loom/store/"):gsub("/%.$", "")
	return storePath
end

-- Keys are lowercase kebab-case, so each one is already a valid alias name. A
-- key with a `-` has to be written as a quoted key.
local function formatAlias(name: string, storePath: string): string
	assert(name:match("^[a-z][a-z0-9-]*$"), `Dependency key "{name}" in pkg.luau must be lowercase kebab-case`)
	local key = if name:find("-") then `["{name}"]` else name
	return `{key} = "{storePath}",`
end

local function getAliasLines(lockfile: Lockfile): { string }
	local storePaths: { [string]: string } = {}
	for _, section in { lockfile.dependencies, lockfile.devDependencies or {} } do
		for name, key in section do
			local package = lockfile.packages[key]
			-- Path dependencies, such as workspace members, already live in the
			-- repository, so they don't need a store alias.
			if package.sourceKind ~= "path" then
				storePaths[name] = getStorePath(package.installPath)
			end
		end
	end

	local names: { string } = {}
	for name in storePaths do
		table.insert(names, name)
	end
	table.sort(names)

	local lines: { string } = {}
	for _, name in names do
		table.insert(lines, formatAlias(name, storePaths[name]))
	end
	return lines
end

local function writeAliases(config: string, aliasLines: { string }): string
	local lines = config:split("\n")
	local startIndex: number? = nil
	local endIndex: number? = nil
	for index, line in lines do
		if line:find("flipbook/issues/689", 1, true) then
			startIndex = index
		elseif line:find(END_MARKER, 1, true) then
			endIndex = index
		end
	end
	local missingMarkers = `{CONFIG_PATH} is missing the alias marker comments`
	local first = assert(startIndex, missingMarkers)
	local last = assert(endIndex, missingMarkers)
	assert(first < last, missingMarkers)

	local indent = lines[first]:match("^%s*") or ""
	local result = table.move(lines, 1, first, 1, {})
	for _, aliasLine in aliasLines do
		table.insert(result, indent .. aliasLine)
	end
	table.move(lines, last, #lines, #result + 1, result)
	return table.concat(result, "\n")
end

-- The Wally steps below use helpers from flipbook-batteries, which they require
-- through its alias. So the Loom dependencies are installed and the aliases
-- written first.
do
	local result = process.run({ "lute", "pkg", "install" }, { stdio = "inherit" })
	assert(result.ok, "lute pkg install failed")

	local lockfile: Lockfile = luau.loadModule(LOCKFILE_PATH)
	local config = fs.readFileToString(CONFIG_PATH)
	fs.writeStringToFile(CONFIG_PATH, writeAliases(config, getAliasLines(lockfile)))
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
