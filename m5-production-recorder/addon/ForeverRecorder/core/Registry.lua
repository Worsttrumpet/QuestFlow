-- ForeverRecorder.Registry: simplified from the Observation Lab's
-- Registry.lua. M5 is the first production release and ships NO
-- experimental-tier modules at all (per the M5 design's explicit
-- decision) -- so this version drops the Lab's ActiveExperimental /
-- EnableExperimental / DisableExperimental / case-insensitive-lookup
-- machinery entirely, rather than keeping unused code. Registration
-- itself HARD-REQUIRES status="proven" -- there is no code path in this
-- addon that can register anything else, enforced by an assertion, not
-- just convention.

ForeverRecorder = ForeverRecorder or {}
ForeverRecorder.Registry = { modules = {}, order = {} }

function ForeverRecorder.Registry:Register(def)
	assert(type(def) == "table", "Register expects a table")
	assert(type(def.name) == "string" and def.name ~= "", "module def needs a name")
	assert(def.status == "proven",
		"M5 ships proven modules only -- '" .. tostring(def.name) .. "' declared status="
		.. tostring(def.status) .. ", which is not permitted in this build")
	assert(not self.modules[def.name], "module '" .. def.name .. "' already registered")
	def.checkpoints = def.checkpoints or {}
	def.events = def.events or {}
	self.modules[def.name] = def
	table.insert(self.order, def.name)
end

function ForeverRecorder.Registry:Get(name)
	return self.modules[name]
end

-- No "IsActive" check needed -- every registered module is proven and
-- therefore always active. Kept as a function (not inlined at call sites)
-- so Dispatcher.lua's code is identical in shape to the Lab's, easing
-- future comparison.
function ForeverRecorder.Registry:IsActive(name)
	return self.modules[name] ~= nil
end

function ForeverRecorder.Registry:ModulesForCheckpoint(checkpoint)
	local out = {}
	for _, name in ipairs(self.order) do
		local def = self.modules[name]
		for _, cp in ipairs(def.checkpoints) do
			if cp == checkpoint then
				table.insert(out, def)
				break
			end
		end
	end
	return out
end

function ForeverRecorder.Registry:ModulesForEvent(eventName)
	local out = {}
	for _, name in ipairs(self.order) do
		local def = self.modules[name]
		for _, ev in ipairs(def.events) do
			if ev == eventName then
				table.insert(out, def)
				break
			end
		end
	end
	return out
end

function ForeverRecorder.Registry:List()
	local out = {}
	for _, name in ipairs(self.order) do
		table.insert(out, { name = name, status = self.modules[name].status })
	end
	return out
end
