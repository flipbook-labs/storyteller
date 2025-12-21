local FlipbookBatteries = require("@luaupkg/flipbook-batteries")
local fs = require("@lute/fs")

local project = require("@repo/project")
local rmrf = require("./rmrf")

local run = FlipbookBatteries.run

local function compile()
	if fs.exists(project.BUILD_PATH) and fs.type(project.BUILD_PATH) == "dir" then
		rmrf(project.BUILD_PATH)
	end
	fs.mkdir(project.BUILD_PATH)

	run("cp", { "-R", project.ROBLOX_PACKAGES_PATH, project.BUILD_PATH })

	run("rojo", {
		"sourcemap",
		project.ROJO_BUILD_PROJECT,
		"-o",
		project.DARKLUA_SOURCEMAP_PATH,
	})

	run("darklua", {
		"process",
		project.SOURCE_PATH,
		project.BUILD_PATH,
	})
end

return compile
