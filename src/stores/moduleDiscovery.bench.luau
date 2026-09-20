local JestGlobals = require("@pkg/JestGlobals")

local observeModuleCollection = require("./observeModuleCollection")

local expect = JestGlobals.expect
local test = JestGlobals.test
local testEach = test.each :: ({ number }) -> (string, (number) -> (), number) -> ()

testEach({ 1000, 10000, 100000 })("measures game-root discovery with %s distractors", function(count: number)
	local root = Instance.new("Folder")
	root.Name = "DiscoveryBenchmark"
	root.Parent = game:GetService("Workspace")

	for index = 1, count do
		local instance = Instance.new("Folder")
		instance.Parent = root
		if index % 1000 == 0 then
			task.wait()
		end
	end

	for index = 1, 40 do
		local module = Instance.new("ModuleScript")
		module.Name = if index % 2 == 0 then `Example{index}.story` else `Example{index}.storybook`
		module.Parent = root
	end

	local cleanup: (() -> ())?
	local success, problem = pcall(function()
		local samples = {}
		local expectedCount = 0
		for _ = 1, 30 do
			local started = os.clock()
			expectedCount = #game:QueryDescendants("ModuleScript")
			table.insert(samples, (os.clock() - started) * 1000)
			task.wait()
		end
		table.sort(samples)
		print(
			`QueryDescendants game root, {count} distractors: medianMs={samples[15]}, maxMs={samples[30]}, modules={expectedCount}`
		)

		local started = os.clock()
		local isAvailable, result = pcall(function()
			return game:GetService("CollectionService"):CreateCollection("ModuleScript", game)
		end)
		local creationMs = (os.clock() - started) * 1000
		if not isAvailable then
			print(`Collections unavailable: {result}`)
			return nil
		end

		local collection = (result :: unknown) :: observeModuleCollection.ModuleCollection
		cleanup = function()
			collection:Destroy()
		end

		local actualCount = 0
		started = os.clock()
		collection:ForEach(function()
			actualCount += 1
		end)
		local iterationMs = (os.clock() - started) * 1000
		print(
			`Collection game root, {count} distractors: creationMs={creationMs}, iterationMs={iterationMs}, modules={actualCount}`
		)
		expect(actualCount).toBe(expectedCount)
		return nil
	end)

	if cleanup then
		cleanup()
	end
	root:Destroy()
	assert(success, problem)
end, 120000)
