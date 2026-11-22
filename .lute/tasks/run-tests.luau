--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Jest = require(ReplicatedStorage.Packages.Jest)
-- Lute's unused_variable lint doesn't count writing a property as a use.
-- #178 tracks removing this ignore.
-- lute-lint-ignore(unused_variable)
local Charm = require(ReplicatedStorage.Packages.Charm)
-- Lute's unused_variable lint doesn't count writing a property as a use.
-- #179 tracks removing this ignore.
-- lute-lint-ignore(unused_variable)
local Vide = require(ReplicatedStorage.Packages.Vide)

local root = ReplicatedStorage.Packages.Storyteller

-- lute-lint-ignore(global_usage)
_G.__DEV__ = true
-- lute-lint-ignore(global_usage)
_G.__ROACT_17_MOCK_SCHEDULER__ = true

Charm.flags.frozen = true
Charm.flags.strict = true

Vide.strict = true

-- lute-lint-ignore(global_usage)
local status, result = Jest.runCLI(root, {
	verbose = false,
	ci = false,
	testPathPattern = _G.__JEST_TEST_PATH_PATTERN__,
	testMatch = if _G.RUN_BENCHMARKS then { "**/*.bench" } else nil,
}, { root }):awaitStatus()

if status == "Rejected" then
	print(result)
end

if status ~= "Resolved" or result.results.numFailedTestSuites > 0 or result.results.numFailedTests > 0 then
	error(1)
end

return nil
