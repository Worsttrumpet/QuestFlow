-- feedback_tests.lua: REPORT A PROBLEM (Feedback.lua, UI/Feedback.lua). Stub-client tests of what Codex captures, stores and says. They prove Codex's own logic; they do NOT show that a
-- report reaches anyone: Codex cannot send anything out of the game (docs/CODEX_FEEDBACK.md), and no network, webhook or file call exists to test.

local H = ...
local check, section, boot = H.check, H.section, H.boot

local function rec(id, name, x, y, o)
	local q = { id = id, name = name, map = 9001, x = x, y = y, req = 1 }
	for k, v in pairs(o or {}) do q[k] = v end
	return q
end
local function world(quests, log, char)
	local c = { level = 10, name = "Thrall", class = "Rogue", classToken = "ROGUE" }
	for k, v in pairs(char or {}) do c[k] = v end
	local ns = boot({ char = c, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "Fixture Valley", subzone = "The Hub" } })
	H.attPack(ns, quests or {}, { { key = "zone-a", label = "Zone A", map = 9001, quests = #(quests or {}) } })
	local W = H.world()
	W.log, W.objectives = {}, {}
	for id, e in pairs(log or {}) do
		W.log[#W.log + 1] = { questID = id, title = e.title or ("quest " .. id), complete = e.complete == true }
		if e.objectives then
			W.objectives[id] = {}
			for i, ob in ipairs(e.objectives) do W.objectives[id][i] = { text = ob.text, type = "monster", finished = false, numFulfilled = ob.have or 0, numRequired = ob.need or 1 } end
		end
	end
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	return ns
end
local function click(b) b.__scripts.OnClick(b) end
local function create(ns, opts) return ns.Feedback.Create(opts) end

section("feedback: the window opens from the tracker's button, from a slash command, and from the NOW card's Report button")
do
	local ns = world({ rec(1, "Near Pickup", 0.6, 0.5, { giverNpc = 70, giverName = "Valennia Stormfist" }) })
	ns.UI.Open("codex")
	local UI = ns.UI
	check(UI.main.feedbackButton and UI.main.feedbackButton.text.__text == "Feedback", "the tracker has a Feedback button")
	click(UI.main.feedbackButton)
	local FB = UI.feedback
	check(FB.frame and FB.frame.__shown == true, "clicking it opens the report window")
	check(FB.from == "WINDOW" and FB.category == "other", "opened from the window: about what Codex shows, category 'other' until chosen")
	FB.frame.__shown = false
	H.slash("feedback")
	check(FB.frame.__shown == true, "/codex feedback opens it too")
	FB.frame.__shown = false
	local c = UI.main.codex
	check(c.nowReport.__shown ~= false and c.nowReport.text.__text == "Report", "the NOW card has a Report button")
	click(c.nowReport)
	check(FB.frame.__shown == true and FB.category == "wrong" and FB.from == "NOW" and FB.about.__text:find("Accept Near Pickup", 1, true), "Report opens the form with 'wrong recommendation' chosen and the recommendation named")
	check(#ns.errors == 0, "no errors")
end

section("feedback: category selection, the player's sentence, and creating a report")
do
	local ns = world({ rec(1, "Near Pickup", 0.6, 0.5, { giverNpc = 70, giverName = "Valennia Stormfist" }) })
	ns.UI.OpenFeedback({ from = "WINDOW" })
	local FB = ns.UI.feedback
	check(#FB.rows == 7, "seven categories (no thirty)")
	for _, r in ipairs(FB.rows) do if r.key == "nav" then click(r.button) end end
	check(FB.category == "nav" and FB.rows[3].text.__text:find("^%(x%)") and FB.rows[1].text.__text:find("^%( %)"), "choosing a category marks it")
	check(FB.Submit() == nil and #ns.Feedback.Stored() == 0 and FB.status.__text:find("write a sentence", 1, true), "nothing written: no report is made, the player is asked for a sentence")
	FB.box:SetText("The arrow points at a cliff.")
	local res = FB.Submit()
	check(res and res.report.category == "nav" and res.report.text == "The arrow points at a cliff.", "category and the player's description are captured")
	check(res.sent == false and res.delivery == "SAVED_LOCAL" and #ns.Feedback.Stored() == 1, "it is saved locally and NOT marked sent")
	check(FB.status.__text:find("created and saved locally", 1, true) and not FB.status.__text:lower():find("feedback sent") and not FB.status.__text:find("Thank you", 1, true), "the player is told it was saved, never that it was sent")
	check(FB.out.__text == res.export and FB.scroll.__shown == true and FB.select.__shown == true, "the one block to copy is shown")
end

section("feedback: the current NOW recommendation is attached automatically, with the planner's own reasons")
do
	local ns = world({ rec(1, "Near Pickup", 0.6, 0.5, { giverNpc = 70, giverName = "Valennia Stormfist" }) })
	local r = create(ns, { category = "wrong", text = "She doesn't have the quest.", from = "NOW" }).report
	local a = r.window.nowAction
	check(r.from == "NOW" and r.window.now.title == "Accept Near Pickup", "the card text is captured")
	check(a.quest == 1 and a.id == "Q:1:ACCEPT" and a.kind == "ACCEPT" and a.name == "Near Pickup" and a.npc == "Valennia Stormfist", "quest id, name, action type and the NPC are captured without the player naming anything")
	check(a.yards == 100 and a.offerState == "UNKNOWN" and a.actionability == "UNKNOWN" and a.where.status == "known" and a.where.map == 9001, "distance, availability state and location (kind and status) are captured")
	check(type(a.codes) == "table" and #a.codes >= 1, "the planner's reason codes are included (the same ones /codex report uses)")
	check(r.plan.reason == nil or type(r.plan.reason) == "string", "planner state is included")
	check(r.nav and r.nav.status ~= nil, "navigation state is included")
end

section("feedback: READY TO TURN IN context is attached")
do
	local ns = world({}, { [7] = { title = "The Fate of Zephras", complete = true } })
	local r = create(ns, { category = "wrong", text = "This is already done.", from = "WINDOW" }).report
	local found
	for _, rd in ipairs(r.window.ready or {}) do if rd.quest == 7 then found = rd end end
	local guided = r.window.now and r.window.now.title == "Turn in The Fate of Zephras"
	check((found and found.title == "The Fate of Zephras") or guided, "the finished quest the window listed is in the report (READY or guidance)")
	check(r.log[1].id == 7 and r.log[1].title == "The Fate of Zephras" and r.log[1].done == true, "and the quest log row (id, title, done)")
end

section("feedback: with no recommendation the report still works")
do
	local ns = world({})
	local res = create(ns, { category = "suggestion", text = "Show me where the trainer is.", from = "WINDOW" })
	check(res.report.window.empty == "Nothing to recommend right now" and res.report.window.now == nil and res.report.text ~= "", "an empty card is reported as empty")
	check(res.id:match("^FC%-%x+%-%d+$") ~= nil, "report id format  [" .. res.id .. "]")
	local ns2 = boot({ char = { level = 5 }, synthetic = true, login = false })
	local res2 = ns2.Feedback.Create({ category = "other", text = "before login" })
	check(res2.report.note == "Codex had not computed a plan yet" and res2.id ~= nil, "even before any plan exists a report is made")
end

section("feedback: build, version, interface and session are captured; reports get distinct ids and never overwrite each other")
do
	local ns = world({ rec(1, "Near Pickup", 0.6, 0.5) })
	local r1 = create(ns, { category = "wrong", text = "first", from = "NOW" })
	local r2 = create(ns, { category = "wrong", text = "second", from = "NOW" })
	check(r1.report.version == ForeverCodex.VERSION and r1.report.client.build == "70124" and r1.report.client.interface == 16001, "Codex version, Forever build and interface version")
	check(r1.report.session == ns.Feedback.Session() and r1.report.session ~= "", "the session id")
	check(r1.id ~= r2.id and #ns.Feedback.Stored() == 2 and ns.Feedback.Stored()[1].id == r1.id and ns.Feedback.Stored()[2].id == r2.id, "two reports: two ids, both stored, neither overwritten")
	local again = create(ns, { category = "wrong", text = "second", from = "NOW" })
	check(again.duplicate == true and again.id == r2.id and #ns.Feedback.Stored() == 2, "pressing Create twice for the same report does not store a duplicate")
	H.world().wall = H.world().wall + 60
	local later = create(ns, { category = "wrong", text = "second", from = "NOW" })
	check(not later.duplicate and later.id ~= r2.id and #ns.Feedback.Stored() == 3, "the same words a minute later are a new report")
	for i = 1, 25 do H.world().wall = H.world().wall + 60; create(ns, { category = "other", text = "n" .. i }) end
	check(#ns.Feedback.Stored() == ns.Feedback.MAX_STORED, "storage is capped (the oldest reports are dropped)")
	-- a new session gets a new session id; ids stay unique because the sequence is persisted
	local old = ns.Feedback.Session()
	local db = _G.ForeverCodexDB
	local ns2 = boot({ char = { level = 10 }, synthetic = true, savedVars = db })
	local seq1 = #ns2.Feedback.Stored()
	local r3 = ns2.Feedback.Create({ category = "other", text = "after reload" })
	check(seq1 == ns.Feedback.MAX_STORED and r3.id ~= r1.id and tonumber(r3.id:match("(%d+)$")) > 28, "after a reload the reports survive and the id sequence continues")
end

section("feedback: character and session boundaries")
do
	local a = world({ rec(1, "Alpha Quest", 0.6, 0.5) }, nil, { name = "Alpha", class = "Warrior", classToken = "WARRIOR", level = 12 })
	local ra = create(a, { category = "other", text = "alpha" }).report
	local b = world({ rec(2, "Bravo Quest", 0.6, 0.5) }, nil, { name = "Bravo", class = "Mage", classToken = "MAGE", level = 30 })
	local rb = create(b, { category = "other", text = "bravo" }).report
	check(ra.char.class == "WARRIOR" and ra.char.level == 12 and rb.char.class == "MAGE" and rb.char.level == 30, "each report describes its own character")
	local blob = ForeverCodex and b.Feedback.ToJson(rb)
	check(not blob:find("Alpha Quest", 1, true) and not blob:find("WARRIOR", 1, true), "nothing of the other character is in it")
	local s1 = a.Feedback.Session()
	a.Feedback._Reset()
	check(a.Feedback.Session() ~= nil, "a session id can be regenerated")
end

section("feedback: privacy (no name, realm, account, GUID or filesystem path) and a compact size")
do
	local ns = world({ rec(1, "Near Pickup", 0.6, 0.5, { giverNpc = 70, giverName = "Valennia Stormfist" }) }, nil, { name = "Thrall" })
	ns.RecordError("planner", "C:\\Users\\bob\\Games\\World of Warcraft\\Interface\\AddOns\\ForeverCodex\\Planner.lua:12: boom /home/bob/x WTF/Account/BOB123/SavedVariables/x.lua")
	local res = create(ns, { category = "broken", text = "It broke at C:\\Users\\bob\\Desktop\\file.txt", from = "WINDOW" })
	local text = res.export
	for _, bad in ipairs({ "Thrall", "Forever-", "Creature-", "Users", "bob", "BOB123", "Interface\\AddOns", "WTF", "Battle", "token", "password" }) do
		check(not text:find(bad, 1, true), "the export does not contain '" .. bad .. "'")
	end
	check(text:find("<path>", 1, true) ~= nil, "paths are replaced, not copied")
	check(#res.json <= ns.Feedback.MAX_JSON and #res.export <= ns.Feedback.MAX_JSON + 1200, "compact: the structured block is under " .. ns.Feedback.MAX_JSON .. " bytes (" .. #res.json .. ") and the whole text is short (" .. #res.export .. ")")
	-- a big quest log is trimmed, not dumped
	local log = {}
	for i = 1, 40 do log[1000 + i] = { title = "Quest number " .. i .. " with a fairly long descriptive title", objectives = { { text = "Kill things", have = 1, need = 9 }, { text = "Collect", have = 2, need = 8 } } } end
	local ns2 = world({}, log)
	local big = create(ns2, { category = "other", text = string.rep("x", 2000) })
	check(#big.report.text <= ns2.Feedback.MAX_TEXT and #big.json <= ns2.Feedback.MAX_JSON, "a long sentence and a 40-quest log still fit (" .. #big.json .. " bytes, trimmed: " .. table.concat(big.report.trimmed or {}, ",") .. ")")
	check(#ns2.errors == 0, "no errors")
end

section("feedback: the JSON form is deterministic and escapes what it must; the spell / profession category adds its own lines")
do
	local ns = world({})
	local F = ns.Feedback
	check(F.ToJson({ b = 1, a = { 1, 2, "x" }, c = 'q"uote\nline', d = true, e = 1.5 }) == '{"a":[1,2,"x"],"b":1,"c":"q\\"uote\\nline","d":true,"e":1.5}', "sorted keys, arrays, escapes")
	check(F.ToJson({}) == "[]" and F.ToJson(nil) == "null" and F.ToJson(0 / 0) == "null", "empty, nil and NaN")
	local r = F.Build({ category = "spell", text = "x" })
	check(type(r.extra) == "table" and #r.extra >= 2, "a spell / profession report carries what those sections read from the client")
	local r2 = F.Build({ category = "wrong", text = "x" })
	check(r2.extra == nil, "other categories do not")
end

section("feedback: Codex states what the client cannot do and never calls any of it; /codex report still works")
do
	local called = 0
	_G.C_HTTP = { Post = function() called = called + 1 end }
	_G.OpenURL = function() called = called + 1 end
	local ns = world({})
	local caps = ns.Feedback.Capabilities()
	local seen = {}
	for _, c in ipairs(caps) do seen[c.name] = c.present end
	check(seen.C_HTTP == true and seen.OpenURL == true and seen.CopyToClipboard == false and seen["C_System.OpenURL"] == false, "presence is reported accurately")
	create(ns, { category = "other", text = "x" })
	ns.UI.OpenFeedback({}); ns.UI.feedback.box:SetText("y"); ns.UI.feedback.Submit()
	check(called == 0, "no such function is ever called")
	check(table.concat(ns.Feedback.ReportLines(), "\n"):find("NOT used by Codex", 1, true) ~= nil, "the diagnostic says they are present and unused")
	_G.C_HTTP, _G.OpenURL = nil, nil
	local ns2 = world({})
	local lines = ns2.Diag.PlaytestLines(ns2.Diag.Snapshot(), {})
	local text = table.concat(lines, "\n")
	check(text:find("=== FOREVER CODEX PLAYTEST REPORT", 1, true) and text:find("FEEDBACK (Report a problem", 1, true) and text:find("WHAT THE WINDOW SHOWS", 1, true), "the existing playtest report still works and now says what feedback can do")
	H.slash("feedback status")
	H.slash("feedback list")
	check(#ns2.errors == 0, "the slash commands raise no errors")
end

section("feedback: it never touches the planner, and the forbidden calls are still absent")
do
	local src = H.readFile(H.addonDir .. "/Planner.lua") .. H.readFile(H.addonDir .. "/PlanAdapter.lua") .. H.readFile(H.addonDir .. "/Engine.lua")
	check(not src:find("Feedback", 1, true), "the planner, adapter and engine do not reference Feedback")
	local fb = H.readFile(H.addonDir .. "/Feedback.lua"):gsub("%-%-[^\n]*", "")
	check(not fb:find("SendChatMessage", 1, true) and not fb:find("SendAddonMessage", 1, true) and not fb:find("%f[%w_]io%.") and not fb:find("%f[%w_]os%.execute") and not fb:find("HttpRequest", 1, true), "Feedback.lua calls no chat, addon-message, file or network function")
end
