local FlipbookBatteries = require("@luaupkg/FlipbookBatteries@v0.12.0")
local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")

local project = require("@repo/project")

local run = FlipbookBatteries.run

-- CodeQuality is the org's shared package of Luau lint rules, which `lute lint`
-- runs alongside its own. `lute run install` puts Loom packages in a store under
-- the home folder rather than in this repo, so the rules are read from there.
-- The version in this path has to match the CodeQuality `rev` in
-- loom.config.luau.
local CODE_QUALITY_RULES_PATH = path.join(process.homedir(), ".loom", "store", "CodeQuality@v0.2.0", "src", "rules")

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

type LintReport = {
	items: {
		{
			uri: string,
			items: {
				{
					code: string?,
					message: string,
					range: { start: { line: number, character: number } },
				}
			},
		}
	},
}

-- `lute lint` exits cleanly even when a rule throws or a file can't be parsed.
-- It only prints an error and moves on. So the findings go to a JSON file
-- instead of the terminal, and anything `lute lint` still prints counts as a
-- failure. It lints one file at a time because Lute's parallel linting can
-- crash at random (flipbook-labs/code-quality#27).
local reportPath = path.join(system.tmpdir(), "storyteller-lint.json")
local lintResult = process.run({
	"lute",
	"lint",
	"--sequential",
	"--json",
	"--output",
	path.format(reportPath),
	"--rules",
	path.format(CODE_QUALITY_RULES_PATH),
	table.unpack(project.FOLDERS_TO_LINT),
})

local lintOutput = lintResult.stdout .. lintResult.stderr
if not lintResult.ok or lintOutput:find("%S") then
	print("[err] lute lint failed")
	print(lintOutput)
	process.exit(1)
end

local report = json.deserialize(fs.readFileToString(reportPath)) :: LintReport
local findingCount = 0
for _, file in report.items do
	for _, finding in file.items do
		findingCount += 1
		local start = finding.range.start
		print(`{file.uri}:{start.line + 1}:{start.character + 1}: [{finding.code or "lint"}] {finding.message}`)
	end
end

if findingCount > 0 then
	print(`[err] lute lint reported {findingCount} finding(s)`)
	process.exit(1)
end

local files = findLuaFiles()
if #files > 0 then
	print("[err] the following file(s) are using the '.lua' extension. Please change to '.luau' and try again")
	print(`{table.concat(files, "\n")}`)
	process.exit(1)
end
