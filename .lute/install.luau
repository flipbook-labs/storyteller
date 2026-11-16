local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local process = require("@std/process")

local project = require("@repo/project")

local getStoreFolder = require("./lib/getStoreFolder")

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

-- `lute check`, editors, and the requires in these scripts find Loom packages
-- through aliases in `.config.luau`. After `lute pkg install`, this points each
-- alias at its dependency's folder in the store. Keys are aliases in
-- `.config.luau`, and values are dependency names in `pkg.luau`.
local DEPENDENCY_ALIASES: { [string]: string } = {
	batteries = "Lute",
	["flipbook-batteries"] = "FlipbookBatteries",
}

-- The Wally steps below use helpers from FlipbookBatteries, which they require
-- through its alias. So the Loom dependencies are installed and the aliases
-- written first.
do
	local res = process.run({ "lute", "pkg", "install" }, {
		stdio = "inherit",
	})
	assert(res.ok, res.stderr)

	local config = fs.readFileToString(CONFIG_PATH)

	for alias, name in DEPENDENCY_ALIASES do
		local storePath = `~/.loom/store/{getStoreFolder(name)}`
		-- Matches both `alias = "..."` and `["alias"] = "..."`. The frontier
		-- keeps `batteries` from matching the end of `flipbook-batteries`.
		local escapedAlias = alias:gsub("%-", "%%-")
		local pattern = `(%f[%w%-]{escapedAlias}"?%]?%s*=%s*")[^"]*(")`
		local updated, count = config:gsub(pattern, `%1{storePath}%2`)
		assert(count == 1, `Expected one "{alias}" alias in {CONFIG_PATH}, found {count}`)
		config = updated
	end

	fs.writeStringToFile(CONFIG_PATH, config)
	print(`wrote dependency aliases to {CONFIG_PATH}`)
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
