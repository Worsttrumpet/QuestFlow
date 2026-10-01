-- ForeverLab.Describe: bounded, human-readable stringification for CHAT/STATUS
-- OUTPUT ONLY. Never use this to build a value that gets stored into
-- ForeverObservationLabDB -- it caps table summaries at a few arbitrary
-- keys, which is exactly what silently dropped the "title" field during
-- the M3/M4-pre-experiment title-capture bug. Stored data must always use
-- explicit named fields (see SafeCall.lua's values table, or a module's
-- own explicit field extraction) -- never this function.

ForeverLab = ForeverLab or {}

function ForeverLab.Describe(value, depth)
	depth = depth or 0
	local t = type(value)
	if t == "table" then
		if depth >= 2 then
			return "{...}"
		end
		local n = 0
		for _ in pairs(value) do
			n = n + 1
		end
		if n == 0 then
			return "{} (empty table)"
		end
		local parts = {}
		local shown = 0
		for k, v in pairs(value) do
			if shown >= 6 then
				table.insert(parts, "...")
				break
			end
			table.insert(parts, tostring(k) .. "=" .. ForeverLab.Describe(v, depth + 1))
			shown = shown + 1
		end
		return "{" .. table.concat(parts, ", ") .. "} (" .. n .. " keys)"
	elseif t == "string" then
		if #value > 80 then
			return string.format("%q", value:sub(1, 80) .. "...") .. " (" .. #value .. " chars)"
		end
		return string.format("%q", value)
	else
		return tostring(value) .. " (" .. t .. ")"
	end
end
