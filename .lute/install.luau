local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local process = require("@std/process")

local project = require("@repo/project")

-- Install Loom dependencies first since the rest of the script depends on them
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

-- Install FlipbookBatteries first because it has a lot of the useful functions
-- we need when installing the rest of our packages
do
	local res = process.run({ "lute", "pkg", "install" }, {
		stdio = "inherit",
	})
	assert(res.ok, res.stderr)
end

do
	local FlipbookBatteries = require("@luaupkg/FlipbookBatteries@v0.12.0")

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
