-- ForeverLab.Registry: explicit module registration.
--
-- A module calls ForeverLab.Registry:Register(def) once, at file load time.
-- def = {
--   name = "RewardsItems",                          -- unique string
--   status = "proven" | "experimental",              -- see note below
--   checkpoints = {"quest_detail", ...},              -- optional
--   events = {"GET_ITEM_INFO_RECEIVED"},              -- optional, raw-event hook
--   capture = function(ctx) return record end,        -- optional, checkpoint-driven
--   on_event = function(ctx, eventName, ...) end,     -- optional, raw-event-driven
-- }
--
-- IMPORTANT (per the approved corrections): `status` describes the
-- MODULE's maturity, not the evidence status of any individual
-- observation. A "proven" module can still produce an observation with
-- ok=false (an API that failed this time); an "experimental" module's
-- successful call does NOT become [V] evidence just because it ran
-- without a Lua error. Every observation record keeps its own `ok`,
-- error, and source-module-status fields (see Dispatcher.lua) so a reader
-- never has to guess which one applies.
--
-- Experimental modules are NOT active by default. Enabling one is a
-- session-only, in-memory action (/flab enable <ModuleName>), never
-- persisted -- so a forgotten enable from a prior login can never cause
-- an experimental module to run unnoticed.

ForeverLab = ForeverLab or {}
ForeverLab.Registry = { modules = {}, order = {} }
ForeverLab.ActiveExperimental = ForeverLab.ActiveExperimental or {} -- session-only, not saved

local VALID_STATUS = { proven = true, experimental = true }

function ForeverLab.Registry:Register(def)
	assert(type(def) == "string" or type(def) == "table", "Register expects a table")
	assert(type(def.name) == "string" and def.name ~= "", "module def needs a name")
	assert(VALID_STATUS[def.status], "module '" .. tostring(def.name) .. "' has invalid status: " .. tostring(def.status))
	assert(not self.modules[def.name], "module '" .. def.name .. "' already registered")
	def.checkpoints = def.checkpoints or {}
	def.events = def.events or {}
	self.modules[def.name] = def
	table.insert(self.order, def.name)
end

function ForeverLab.Registry:Get(name)
	return self.modules[name]
end

function ForeverLab.Registry:IsActive(name)
	local def = self.modules[name]
	if not def then
		return false
	end
	if def.status == "proven" then
		return true
	end
	return ForeverLab.ActiveExperimental[name] == true
end

function ForeverLab.Registry:EnableExperimental(name)
	local def = self.modules[name]
	if not def then
		return false, "no such module: " .. tostring(name)
	end
	if def.status ~= "experimental" then
		return false, "'" .. name .. "' is a proven module; it is already always active"
	end
	ForeverLab.ActiveExperimental[name] = true
	return true
end

function ForeverLab.Registry:DisableExperimental(name)
	ForeverLab.ActiveExperimental[name] = nil
	return true
end

-- Modules registered against a given checkpoint, filtered to those
-- currently active (proven: always; experimental: only if enabled).
function ForeverLab.Registry:ActiveModulesForCheckpoint(checkpoint)
	local out = {}
	for _, name in ipairs(self.order) do
		local def = self.modules[name]
		if self:IsActive(name) then
			for _, cp in ipairs(def.checkpoints) do
				if cp == checkpoint then
					table.insert(out, def)
					break
				end
			end
		end
	end
	return out
end

function ForeverLab.Registry:ActiveModulesForEvent(eventName)
	local out = {}
	for _, name in ipairs(self.order) do
		local def = self.modules[name]
		if self:IsActive(name) then
			for _, ev in ipairs(def.events) do
				if ev == eventName then
					table.insert(out, def)
					break
				end
			end
		end
	end
	return out
end

-- Convenience for slash commands: users will type lowercase. Returns the
-- exact registered name if a case-insensitive match is found, else the
-- original input unchanged (so an unknown name still produces a clear
-- "no such module" error rather than being silently swallowed).
function ForeverLab.ResolveModuleNameCaseInsensitive(input)
	if type(input) ~= "string" or input == "" then
		return input
	end
	local lowered = input:lower()
	for _, name in ipairs(ForeverLab.Registry.order) do
		if name:lower() == lowered then
			return name
		end
	end
	return input
end

function ForeverLab.Registry:List()
	local out = {}
	for _, name in ipairs(self.order) do
		local def = self.modules[name]
		table.insert(out, { name = name, status = def.status, active = self:IsActive(name) })
	end
	return out
end
