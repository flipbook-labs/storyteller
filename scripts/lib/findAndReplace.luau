local fs = require("@lute/fs")

local function findAndReplace(filePath: string, match: string, replacement: string)
	local content = fs.readfiletostring(filePath)
	content = content:gsub(match, replacement)
	fs.writestringtofile(filePath, content)
end

return findAndReplace
