-- ForeverCodex.Relevance (0.7.8): "is this Codex feature relevant to THIS character?" in ONE place. A feature that is not relevant is simply absent from the window (no card, no "not applicable"
-- text), and the cards around it reflow. A feature declares its rule once here; the Presenter asks, so a new feature does not invent its own show-or-hide logic.
--
-- A rule is a class list (class tokens such as "HUNTER") and/or a test(ctx) function. Relevance is only the FIRST gate: a relevant feature still shows nothing when it has nothing useful to say
-- (each feature's own Card returns nil then). Features whose visibility is purely "does the data exist" (a timed quest, dungeon quests) need no entry here.

local addonName, ns = ...

local R = {}
ns.Relevance = R

local features = {}

--- def = { classes = { "HUNTER", ... } | nil (every class), test = function(ctx) -> boolean | nil, why = text for the report }.
function R.Register(key, def)
	local set
	if def.classes then set = {} for _, c in ipairs(def.classes) do set[c] = true end end
	features[key] = { key = key, classes = set, classList = def.classes, test = def.test, why = def.why }
end

--- True when the feature is relevant to the character in `ctx`. An unknown feature is not relevant. A class rule with no known class is NOT relevant (unknown stays unknown: nothing is shown on a guess).
function R.Applies(key, ctx)
	local f = features[key]
	if not f then return false end
	if f.classes then
		local token = ctx and ctx.char and ctx.char.classToken
		if not (token and f.classes[token]) then return false end
	end
	if f.test then
		local ok, res = pcall(f.test, ctx)
		if not ok or not res then return false end
	end
	return true
end

--- The rule of a feature as text (for /codex report): "classes HUNTER, WARLOCK" or "every class".
function R.Describe(key)
	local f = features[key]
	if not f then return "unknown feature" end
	return f.classList and ("classes " .. table.concat(f.classList, ", ")) or "every class"
end

-- The features that use the gate today.
-- Pet-capable classes: a Hunter's pet and a Warlock's demon are the two in Classic. Only the ELIGIBILITY is stated here; whether Codex can report anything for a Warlock is a separate
-- question (see PetTraining.lua): there is no pet source yet, so no class sees a Pet Training card today.
R.Register("petTraining", { classes = { "HUNTER", "WARLOCK" }, why = "pet and demon abilities" })
R.Register("spellTraining", { why = "every class has a class trainer" })
R.Register("professions", { why = "every character can learn professions" })
