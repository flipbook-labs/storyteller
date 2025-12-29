local fs = require("@lute/fs")
local process = require("@lute/process")

type APIExport = {
	name: string,
	kind: "function" | "type" | "enum" | "value",
	signature: string?,
}

type APISurface = {
	exports: { [string]: APIExport },
	types: { [string]: APIExport },
}

type ChangeKind = "Added" | "Removed" | "Modified"

local ChangeKind = {
	Added = "Added" :: "Added",
	Removed = "Removed" :: "Removed",
	Modified = "Modified" :: "Modified",
}

type APIChange = {
	kind: ChangeKind,
	name: string,
	before: APIExport?,
	after: APIExport?,
}

type ChangeReport = {
	breaking: { APIChange },
	additions: { APIChange },
	modifications: { APIChange },
}

local function parseInitLuau(content: string): APISurface
	local api: APISurface = {
		exports = {},
		types = {},
	}

	for name in content:gmatch("export%s+type%s+([%w_]+)%s*=") do
		api.types[name] = {
			name = name,
			kind = "type",
		}
	end

	local returnBlock = content:match("return%s*{(.-)}")
	if returnBlock then
		for key in returnBlock:gmatch("([%w_]+)%s*=") do
			api.exports[key] = {
				name = key,
				kind = "function",
			}
		end
	end

	return api
end

local function getFileAtRef(ref: string, filePath: string): string?
	-- Handle working directory (uncommitted changes)
	if ref == "WORKING" or ref == "." then
		if not fs.exists(filePath) then
			return nil
		end
		local handle = fs.open(filePath, "r")
		local content = fs.read(handle)
		fs.close(handle)
		return content
	end

	-- Try git first
	local result = process.run({
		"git",
		"show",
		`{ref}:{filePath}`,
	})

	if not result.ok then
		return nil
	end

	return result.stdout
end

local function getAPISurface(ref: string): APISurface
	print(`📖 Reading API surface for {ref}...`)

	local content = getFileAtRef(ref, "src/init.luau")

	if not content then
		error(`Could not find src/init.luau for ref {ref}`)
	end

	return parseInitLuau(content)
end

local function compareAPIs(baseline: APISurface, current: APISurface): ChangeReport
	local report: ChangeReport = {
		breaking = {},
		additions = {},
		modifications = {},
	}

	for name, export in baseline.exports do
		if not current.exports[name] then
			local change: APIChange = {
				kind = ChangeKind.Removed,
				name = name,
				before = export,
			}

			table.insert(report.breaking, change)
		end
	end

	for name, export in baseline.types do
		if not current.types[name] then
			table.insert(
				report.breaking,
				{
					kind = ChangeKind.Removed,
					name = name,
					before = export,
				} :: APIChange
			)
		end
	end

	for name, export in current.exports do
		if not baseline.exports[name] then
			local change: APIChange = {
				kind = ChangeKind.Added,
				name = name,
				after = export,
			}
			table.insert(report.additions, change)
		end
	end

	for name, export in current.types do
		if not baseline.types[name] then
			local change: APIChange = {
				kind = ChangeKind.Added,
				name = name,
				after = export,
			}
			table.insert(report.additions, change)
		end
	end

	return report
end

local function getVersionBump(report: ChangeReport): "major" | "minor" | "patch" | "none"
	if #report.breaking > 0 then
		return "major"
	elseif #report.additions > 0 then
		return "minor"
	elseif #report.modifications > 0 then
		return "patch"
	end
	return "none"
end

local function printReport(baseline: string, current: string, report: ChangeReport)
	print("\n" .. string.rep("=", 60))
	print(`API Diff: {baseline} → {current}`)
	print(string.rep("=", 60))

	if #report.breaking > 0 then
		print("\n🔴 BREAKING CHANGES:")
		for _, change in report.breaking do
			print(`  - Removed {if change.before then change.before.kind else "export"}: Storyteller.{change.name}`)
		end
	end

	if #report.additions > 0 then
		print("\n✅ ADDITIONS:")
		for _, change in report.additions do
			print(`  + Added {if change.after then change.after.kind else "export"}: Storyteller.{change.name}`)
		end
	end

	if #report.modifications > 0 then
		print("\n⚠️  MODIFICATIONS:")
		for _, change in report.modifications do
			print(`  ~ Modified {change.name}`)
		end
	end

	if #report.breaking == 0 and #report.additions == 0 and #report.modifications == 0 then
		print("\nNo API changes detected.")
	end

	local bump = getVersionBump(report)
	print("\n📊 Recommendation:")
	if bump == "major" then
		print(`  Version bump: MAJOR (breaking changes)`)
	elseif bump == "minor" then
		print(`  Version bump: MINOR (new features)`)
	elseif bump == "patch" then
		print(`  Version bump: PATCH (modifications)`)
	else
		print(`  Version bump: NONE (no API changes)`)
	end

	print("\n" .. string.rep("=", 60) .. "\n")
end

local function main(args: { any })
	if #args < 3 then
		print("Usage: lute scripts/tasks/api-diff.luau <baseline-ref> <current-ref>")
		print("Examples:")
		print("  lute scripts/api-diff.luau v1.0.0 HEAD")
		print("  lute scripts/api-diff.luau HEAD WORKING    # uncommitted changes")
		process.exit(1)
	end

	local _script = args[1]
	local baseline = args[2]
	local current = args[3]

	local gitCheck = process.run({ "git", "rev-parse", "--git-dir" })
	if not gitCheck.ok then
		error("Not in a git repository")
	end

	local baselineAPI = getAPISurface(baseline)
	local currentAPI = getAPISurface(current)

	local report = compareAPIs(baselineAPI, currentAPI)
	printReport(baseline, current, report)

	if #report.breaking > 0 then
		process.exit(1)
	end
end

main({ ... })
