local FlipbookBatteries = require("@luaupkg/flipbook-batteries")
local fs = require("@lute/fs")

local project = require("@repo/project")

local copyInto = FlipbookBatteries.copyInto
local mkdir = FlipbookBatteries.mkdir
local rmdir = FlipbookBatteries.rmdir
local run = FlipbookBatteries.run

local function compile()
	if fs.exists(project.BUILD_PATH) and fs.type(project.BUILD_PATH) == "dir" then
		rmdir(project.BUILD_PATH)
	end
	mkdir(project.BUILD_PATH)

	copyInto(project.ROBLOX_PACKAGES_PATH, `{project.BUILD_PATH}/{project.ROBLOX_PACKAGES_PATH}`)

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
