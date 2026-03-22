--!strict

export type MemoryResult = {
	beforeKB: number,
	afterKB: number,
	deltaKB: number,
}

--[[
	Measures the Luau VM heap delta (via `gcinfo()`) produced by `callback`.

	Notes:
	- `gcinfo()` only covers the Luau VM heap. Roblox Instance allocations live
	  in the C++ heap and are invisible here. Table, string, closure, and other
	  Lua-side allocations will be reflected.
	- Roblox's GC is incremental, so results can occasionally be negative when
	  the collector runs during the callback. Treat deltas as approximate.
	- `collectgarbage("collect")` is attempted before sampling so that prior
	  garbage doesn't inflate the before-baseline. This is a no-op in standard
	  Roblox (the global is absent), but is effective in plain Luau environments
	  such as Open Cloud's Luau Execution sandbox.
]]
local function measureMemory(callback: () -> ()): MemoryResult
	pcall(function()
		collectgarbage("collect")
	end)

	local before = gcinfo()
	callback()
	local after = gcinfo()

	return {
		beforeKB = before,
		afterKB = after,
		deltaKB = after - before,
	}
end

return measureMemory
