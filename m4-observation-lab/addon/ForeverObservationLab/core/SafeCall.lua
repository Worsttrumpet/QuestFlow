-- ForeverLab.SafeCall: the ONLY call helper used anywhere in this addon.
--
-- This is a promotion of the fix found during the M4 reputation follow-up,
-- not a new invention. The old pattern used across M3/M4-pre/M4-retry/
-- M4-reputation was:
--
--     local results = { pcall(fn, ...) }
--     local ok = table.remove(results, 1)
--     return true, unpack(results)
--
-- Lua 5.1's "#" length operator is undefined on a table with holes (nil
-- values in the middle of the sequence). GetFactionInfoByID's real return
-- shape (name, nil, nil, nil, nil, nil, nil, nil, isHeader, nil, hasRep)
-- exposed this concretely: unpack() silently dropped isHeader/hasRep,
-- which sat past several nils. Confirmed directly in isolation during that
-- follow-up (see M4_REPUTATION_FOLLOWUP_NOTES.md).
--
-- The fix: never use unpack() on a table that might have holes. Read
-- values back by explicit numeric index instead -- direct table indexing
-- is always correct in Lua regardless of holes; only unpack()/ipairs() are
-- affected. This file is the ONE place that logic lives now, so no future
-- module in this lab can reintroduce the old bug by copy-pasting it.
--
-- Signature: ok, errorOrNil, values = ForeverLab.SafeCall(fn, maxN, ...)
--   ok           -- true if fn existed and didn't error
--   errorOrNil   -- error message string if not ok, else nil
--   values       -- a table with values[1]..values[maxN] set explicitly
--                   (nil entries are real nils from fn, not "unset")
--
-- maxN is required, not defaulted: callers must say how many return
-- values they actually care about, which keeps every call site explicit
-- about the API shape it's testing -- consistent with this project's
-- "record positionally, don't assume" principle from every prior probe.

ForeverLab = ForeverLab or {}

function ForeverLab.SafeCall(fn, maxN, ...)
	if type(maxN) ~= "number" or maxN < 0 then
		error("ForeverLab.SafeCall: maxN must be a non-negative number, got " .. tostring(maxN), 2)
	end
	if type(fn) ~= "function" then
		return false, "not a function (type=" .. type(fn) .. ")", {}
	end
	local results = { pcall(fn, ...) }
	local ok = table.remove(results, 1)
	if not ok then
		return false, tostring(results[1]), {}
	end
	local values = {}
	for i = 1, maxN do
		values[i] = results[i] -- explicit indexing: correct regardless of holes
	end
	return true, nil, values
end
