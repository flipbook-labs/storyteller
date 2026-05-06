local fs = require("@std/fs")
local json = require("@std/json")
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
local function getDescendants(dirPath: path.pathlike): { path.path }
	if fs.type(dirPath) ~= "dir" then
		return {}
	end

	local function reduce(rootPath: path.path, accumulator: { path.path }): { path.path }
		for _, child in fs.listdirectory(rootPath) do
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

-- Install flipbook-batteries first because it has a lot of the useful functions
-- we need when installing the rest of our packages
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
	installLuteBatteries()
	patchStringRequires()
end
