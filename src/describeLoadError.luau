local ModuleLoader = require("@pkg/ModuleLoader")

type ModuleLoader = ModuleLoader.ModuleLoader

--[[
	Turns an error from `loader.require` into text: the error's message on the
	first line, then the stack from where it was raised, which runs back
	through each module that required the failing one.

	When a module fails, ModuleLoader raises its error without the stack. The
	loader's `getLastError` returns the most recent failure as `{ err,
	traceback }`, and the traceback is that stack. A loader can hold a record
	from an earlier failure, so the traceback is added only when the record's
	`err` matches `err` here. Any other error, such as one raised outside the
	loader, comes back as its message alone.
]]
local function describeLoadError(loader: ModuleLoader, err: unknown): string
	local message = tostring(err)
	local lastError = loader.getLastError()
	if lastError and rawequal(lastError.err, err) then
		return `{message}\n{lastError.traceback}`
	end
	return message
end

return describeLoadError
