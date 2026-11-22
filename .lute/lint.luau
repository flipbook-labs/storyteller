local CodeQuality = require("@lpm/code-quality@v0.7.0")
local FlipbookBatteries = require("@lpm/flipbook-batteries@v0.13.1")
local fs = require("@std/fs")
local process = require("@std/process")

local logger = require("@repo/.lute/lib/logger")
local project = require("@repo/project")

local run = FlipbookBatteries.run

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

logger.info("checking formatting with stylua")
run("stylua", {
	"--check",
	table.unpack(project.FOLDERS_TO_LINT),
})

logger.info("linting with CodeQuality")
CodeQuality.lint(project.FOLDERS_TO_LINT)

logger.debug("checking for files using the '.lua' extension")
local files = findLuaFiles()
if #files > 0 then
	logger.err("the following file(s) are using the '.lua' extension. Please change to '.luau' and try again")
	logger.err(table.concat(files, "\n"))
	process.exit(1)
end

logger.info("lint passed")
