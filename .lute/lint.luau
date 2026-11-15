local FlipbookBatteries = require("@luaupkg/FlipbookBatteries@v0.12.0")
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")

local project = require("@repo/project")

local run = FlipbookBatteries.run

-- CodeQuality is the org's shared package of Luau lint rules, which `lute lint`
-- runs alongside its own. `lute run install` puts Loom packages in a store under
-- the home folder rather than in this repo, so the rules are read from there.
-- The version in this path has to match the CodeQuality `rev` in
-- loom.config.luau.
local CODE_QUALITY_RULES_PATH = path.join(
	process.homedir(),
	".loom",
	"store",
	"CodeQuality@abafa51fdac79cda09bb2e54c6b21af628840b33",
	"src",
	"rules"
)

local function findLuaFiles()
	local matches = {}

	local function search(dirPath: string)
		for _, file in fs.listDirectory(dirPath) do
			local filePath = `{dirPath}/{file.name}`

			if file.type == "dir" then
				search(filePath)
			else
				if file.name:match(".lua$") then
					table.insert(matches, filePath)
				end
			end
		end
	end

	for _, folder in project.FOLDERS_TO_LINT do
		search(folder)
	end

	return matches
end

run("selene", { table.unpack(project.FOLDERS_TO_LINT) })

run("stylua", {
	"--check",
	table.unpack(project.FOLDERS_TO_LINT),
})

if not fs.exists(CODE_QUALITY_RULES_PATH) then
	print(
		`[err] CodeQuality rules not found at {path.format(CODE_QUALITY_RULES_PATH)}. Run 'lute run install' and try again`
	)
	process.exit(1)
end

-- Lute's parallel linting can crash at random, which fails lint for no reason,
-- so files are linted one at a time.
run("lute", {
	"lint",
	"--sequential",
	"--rules",
	path.format(CODE_QUALITY_RULES_PATH),
	table.unpack(project.FOLDERS_TO_LINT),
})

local files = findLuaFiles()
if #files > 0 then
	print("[err] the following file(s) are using the '.lua' extension. Please change to '.luau' and try again")
	print(`{table.concat(files, "\n")}`)
	process.exit(1)
end
