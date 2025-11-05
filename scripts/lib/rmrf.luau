local fs = require("@lute/fs")

local function rmrf(path: string)
	if fs.type(path) == "dir" then
		for _, file in fs.listdir(path) do
			rmrf(`{path}/{file.name}`)
		end
		fs.rmdir(path)
	else
		fs.remove(path)
	end
end

return rmrf
