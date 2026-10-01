-- ForeverRecorder.SafeCall: ported unchanged from the Observation Lab's
-- core/SafeCall.lua (M4). This is the fix for a real, confirmed bug class
-- (the M4 reputation follow-up's unpack()-on-holes failure, where
-- GetFactionInfoByID's real return shape silently dropped trailing real
-- values behind several nils). Only the namespace name changes
-- (ForeverLab -> ForeverRecorder); the logic is byte-for-byte the same
-- fix, since it already passed real-client testing and there is no reason
-- to touch working, tested code.
--
-- Signature: ok, errorOrNil, values = ForeverRecorder.SafeCall(fn, maxN, ...)

ForeverRecorder = ForeverRecorder or {}

function ForeverRecorder.SafeCall(fn, maxN, ...)
	if type(maxN) ~= "number" or maxN < 0 then
		error("ForeverRecorder.SafeCall: maxN must be a non-negative number, got " .. tostring(maxN), 2)
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
