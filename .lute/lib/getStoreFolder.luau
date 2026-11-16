local luau = require("@std/luau")

local LOCKFILE_PATH = "pkg.lock.luau"

type Lockfile = {
	dependencies: { [string]: string },
	devDependencies: { [string]: string }?,
	packages: { [string]: { installPath: string } },
}

-- `lute pkg install` puts each dependency in the Loom store, `~/.loom/store`,
-- under a folder with generated hashes in its name, and records that folder in
-- `pkg.lock.luau`. This returns it for a dependency or dev dependency named in
-- `pkg.luau`, relative to the store. A dependency with a `target`, like Lute's
-- `batteries`, installs only that subfolder, so its path ends in the target.
local function getStoreFolder(name: string): string
	local lockfile: Lockfile = luau.loadModule(LOCKFILE_PATH)

	local key = lockfile.dependencies[name] or (lockfile.devDependencies and lockfile.devDependencies[name])
	assert(key, `{name} is not a dependency in {LOCKFILE_PATH}. Run 'lute run install' and try again`)

	-- The lockfile writes `@pkg/` for the store. That's Lute's own prefix, not
	-- the `pkg` alias in `.config.luau`. The path of a dependency without a
	-- target ends in `/.`.
	local installPath = lockfile.packages[key].installPath
	local storeFolder = installPath:gsub("^@pkg/", ""):gsub("/%.$", "")
	return storeFolder
end

return getStoreFolder
