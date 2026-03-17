--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Jest = (require :: any)(ReplicatedStorage.Packages.Jest)
local Charm = (require :: any)(ReplicatedStorage.Packages.Charm)

local root = ReplicatedStorage.Packages.Storyteller

-- selene: allow(global_usage)
_G.__DEV__ = true
-- selene: allow(global_usage)
_G.__ROACT_17_MOCK_SCHEDULER__ = true

Charm.flags.frozen = true
Charm.flags.strict = true

local status, result = Jest.runCLI(root, {
	verbose = false,
	ci = false,
	-- selene: allow(global_usage)
	testPathPattern = _G.__JEST_TEST_PATH_PATTERN__,
	-- selene: allow(global_usage)
	testMatch = if _G.RUN_BENCHMARKS then { "**/*.bench" } else nil,
}, { root }):awaitStatus()

if status == "Rejected" then
	print(result)
end

if status ~= "Resolved" or result.results.numFailedTestSuites > 0 or result.results.numFailedTests > 0 then
	error(1)
end

return nil
