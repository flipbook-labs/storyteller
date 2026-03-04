local fs = require("@lute/fs")
local json = require("@std/json")
local process = require("@lute/process")

local project = require("@repo/project")

local LUAU_PACKAGES_PATH = "LuauPackages"

local function getDescendants(dirPath: string): { string }
	if fs.type(dirPath) ~= "dir" then
		return {}
	end

	local function reduce(rootPath: string, accumulator: { string }): { string }
		for _, child in fs.listdir(rootPath) do
			local childPath = `{rootPath}/{child.name}`
			table.insert(accumulator, childPath)

			if child.type == "dir" then
				reduce(childPath, accumulator)
			end
		end
		return accumulator
	end

	return reduce(dirPath, {})
end

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
				if descendant:match("%.luau$") then
					findAndReplace(descendant, `require%("%./(%w+)"%)`, "require(script.Parent.%1)")
				end
			end
		end
	end

	installWallyPackages()
	installLuteBatteries()
	patchStringRequires()
end
