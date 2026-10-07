-- offerprobe_secret_tests.lua (0.8.1): OfferProbe and "secret" values. Real-client failure (0.8.0, a dungeon run): `OfferProbe.lua:119: attempt to index a secret string value (execution tainted by 'ForeverCodex')`.
-- A secret value is simulated two ways: (a) a client that has issecretvalue() (a sentinel is "secret"), and (b) a client without it, where a method call on the secret string raises exactly like the real
-- error (the string metatable's __index raises for the sentinel). Stub-client tests of Codex's own handling; they say nothing about which Forever calls actually return secrets.

local H = ...
local check, section, boot = H.check, H.section, H.boot

local SECRET = "<<SECRET>>"
local SECRET_NUM = -987654321
local SECRET_LIST = {}                                   -- a table the client marks secret

local function rec(id, name, x, y, o)
	local q = { id = id, name = name, map = 9001, x = x, y = y, req = 1 }
	for k, v in pairs(o or {}) do q[k] = v end
	return q
end

local saved = {}
local function installSecrets(withApi)
	saved.sub = getmetatable("").__index
	local orig = saved.sub
	getmetatable("").__index = function(s, k)
		if s == SECRET then error("attempt to index a secret string value (execution tainted by 'ForeverCodex')", 2) end
		return orig[k]
	end
	saved.api = _G.issecretvalue
	if withApi then _G.issecretvalue = function(v) return v == SECRET or v == SECRET_NUM or v == SECRET_LIST end else _G.issecretvalue = nil end
end
local function removeSecrets()
	getmetatable("").__index = saved.sub
	_G.issecretvalue = saved.api
	for _, n in ipairs({ "C_GossipInfo", "UnitName", "UnitGUID" }) do _G[n] = nil end
end

local function world()
	local ns = boot({ char = { level = 10, class = "Rogue", classToken = "ROGUE" }, synthetic = true, production = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "F" } })
	for _, n in ipairs({ "C_GossipInfo", "GetQuestID", "GetTitleText", "UnitGUID" }) do _G[n] = nil end
	H.attPack(ns, { rec(1, "Hub Quest", 0.55, 0.5, { giverNpc = 7001, giverName = "Hub Giver" }), rec(2, "Far Quest", 0.95, 0.95, { giverNpc = 7002, giverName = "Far Giver" }) }, { { key = "zone-a", label = "A", map = 9001, quests = 2 } })
	ns.Prefs.FinishSetup()
	return ns
end
local function gossip(avail, active, options) _G.C_GossipInfo = { GetAvailableQuests = function() return avail end, GetActiveQuests = function() return active or {} end, GetOptions = function() return options or {} end } end
local function errorsOf(ns, where) local n = 0 for _, e in ipairs(ns.errors) do if e:find(where, 1, true) then n = n + 1 end end return n end

for _, withApi in ipairs({ false, true }) do
	local label = withApi and "the client has issecretvalue()" or "no issecretvalue(): the method call itself raises"
	section("offerprobe secrets (" .. label .. "): a SECRET NPC name and GUID no longer raise; the dialog is recorded without an NPC identity and supplies no per-NPC evidence")
	do
		local ns = world()
		installSecrets(withApi)
		_G.UnitName = function() return SECRET end
		_G.UnitGUID = function() return SECRET end
		gossip({}, {}, { { name = "Talk", icon = 1 } })
		ns.errors = {}
		ns.OfferProbe.OnEvent("GOSSIP_SHOW")
		check(#ns.errors == 0, "NO error is raised or recorded  [" .. tostring(ns.errors[1]) .. "]")
		local s = ForeverCodexDB.offers
		local ob = s.obs[#s.obs]
		check(ob and ob.src == "CODEX_OBSERVED" and ob.via == "GOSSIP_SHOW" and ob.npc == nil, "the dialog is still recorded as Quest Flow-observed, with NO npc identity")
		check(ob and ob.npcUnreadable == true and (s.stats.npcUnreadable or 0) >= 1, "and says why (unreadable NPC), counted for the report")
		check(next(s.npcs) == nil, "no NPC context was saved: an empty list cannot be attributed to an NPC, so there is no negative evidence")
		check(next(s.quests) == nil, "no quest offer was invented")
		local e = s.proof["UnitName"]
		check(e and e.secret and e.secret >= 1 and e.s:find("unreadable", 1, true), "the report sample says the value was unreadable (it does not contain the value)  [" .. tostring(e and e.s) .. "]")
		check(not (function() local function scan(t, d) for k, v in pairs(t) do if v == SECRET then return true end if type(v) == "table" and d < 6 and scan(v, d + 1) then return true end end return false end return scan(s, 0) end)(), "the secret value is not stored anywhere")
		ns.State.Recompute()
		check(ns.Planner.OfferState({ kind = "ACCEPT", quest = 1 }) == "UNKNOWN" and ns.State.plan.now and ns.State.plan.now.id == "Q:1:ACCEPT", "the pickup is still UNKNOWN (never AVAILABLE, never held back) and stays NOW")
		local text = table.concat(ns.OfferProbe.ReportLines(), "\n")
		check(#text > 0 and not text:find(SECRET, 1, true), "the report builds and does not contain the value")
		check(text:find("unreadable (secret) values this save: NPC names or GUIDs 1", 1, true) ~= nil, "and the report COUNTS the unreadable NPC (so a dungeon report shows it happened)")
		removeSecrets()
	end

	-- (a secret NUMBER can only be simulated through issecretvalue(): without it the sentinel is just a number)
	if withApi then section("offerprobe secrets (" .. label .. "): secret QUEST fields: unreadable entries are left out; a quest is never offered on a value Quest Flow could not read")
	do
		local ns = world()
		installSecrets(withApi)
		_G.UnitName = function() return "Hub Giver" end
		_G.UnitGUID = function() return "Creature-0-1-2-3-7001-ABCDEF" end
		gossip({ { questID = SECRET_NUM, title = SECRET }, { questID = 1, title = "Hub Quest" } })
		ns.errors = {}
		ns.OfferProbe.OnEvent("GOSSIP_SHOW")
		check(#ns.errors == 0, "no error  [" .. tostring(ns.errors[1]) .. "]")
		local ctx = ns.OfferProbe.NpcContext(7001)
		check(ctx and ctx.avail.state == "LISTED" and ctx.avail.complete ~= true, "the listing is LISTED but INCOMPLETE (one entry could not be read), so it can never be read as 'quest X is not offered'")
		check(ns.OfferProbe.QuestEvidence(1) ~= nil and ns.OfferProbe.QuestEvidence(SECRET_NUM) == nil, "the readable entry is positive evidence; the unreadable one is nothing")
		removeSecrets()
	end end
end

section("offerprobe secrets: a whole listing the client marks secret is UNREADABLE: neither empty nor listed, so no quest is held back or offered")
do
	local ns = world()
	installSecrets(true)
	_G.UnitName = function() return "Hub Giver" end
	_G.UnitGUID = function() return "Creature-0-1-2-3-7001-ABCDEF" end
	gossip(SECRET_LIST)
	ns.errors = {}
	ns.OfferProbe.OnEvent("GOSSIP_SHOW")
	ns.State.Recompute()
	local ctx = ns.OfferProbe.NpcContext(7001)
	check(#ns.errors == 0 and ctx and ctx.avail.state == "NO_DATA", "no error; the NPC's available list is recorded as NO data (nothing was learned from it)  [" .. tostring(ctx and ctx.avail.state) .. "]")
	local st, ev = ns.Planner.OfferState({ kind = "ACCEPT", quest = 1 })
	check(st == "UNKNOWN" and ns.State.plan.now and ns.State.plan.now.id == "Q:1:ACCEPT", "the pickup stays UNKNOWN and is not held back  [" .. tostring(st) .. "]")
	local ob = ForeverCodexDB.offers.obs[#ForeverCodexDB.offers.obs]
	local av
	for _, a in ipairs(ob.answers) do if a.kind == "available" then av = a end end
	check(av and av.state == "UNREADABLE", "the raw observation keeps the distinct state UNREADABLE for the report")
	check(table.concat(ns.OfferProbe.ReportLines(), "\n"):find("secret value", 1, true) ~= nil, "and the report says so in words")
	-- the control: a readable EMPTY list at the same NPC DOES hold the pickup back (the existing evidence rule is untouched)
	local ns2 = world()
	_G.UnitName = function() return "Hub Giver" end
	_G.UnitGUID = function() return "Creature-0-1-2-3-7001-ABCDEF" end
	gossip({})
	ns2.OfferProbe.OnEvent("GOSSIP_SHOW")
	ns2.State.Recompute()
	check(ns2.Planner.OfferState({ kind = "ACCEPT", quest = 1 }) == "NOT_OFFERED", "control: a readable empty list still means NOT_OFFERED (the model is unchanged)")
	removeSecrets()
end

section("offerprobe secrets: the QUEST_DETAIL / QUEST_GREETING readers survive secret titles and ids too")
do
	local ns = world()
	installSecrets(true)
	_G.UnitName = function() return "Hub Giver" end
	_G.UnitGUID = function() return "Creature-0-1-2-3-7001-ABCDEF" end
	_G.GetQuestID = function() return SECRET_NUM end
	_G.GetTitleText = function() return SECRET end
	ns.errors = {}
	ns.OfferProbe.OnEvent("QUEST_DETAIL")
	check(#ns.errors == 0 and next(ForeverCodexDB.offers.quests) == nil, "an open quest dialog whose id and title are secret records no offer and raises nothing")
	_G.GetQuestID, _G.GetTitleText = nil, nil
	removeSecrets()
end
