-- ForeverCodex.PetTraining (0.7.8): the PET TRAINING card, behind the relevance gate (Relevance.lua). Codex reads NO pet information on Forever today: there is no pet-ability, pet-training
-- window or pet-spellbook reader, and the Hunter pet-training window is deliberately ignored by SpellTraining. So this module owns the GATE and the CARD SHAPE and nothing else: a pet source
-- (a future reader of what the client really offers) registers a function here; with no source, or with a source that has nothing to say, no card exists for ANY class. No pet data is invented
-- and no Era table is shipped.
--
--   PetTraining.RegisterSource(function(ctx) return { { text = "...", detail = "..." }, ... } or nil end)

local addonName, ns = ...

local PT = {}
ns.PetTraining = PT

PT.MAX_ROWS = 6
local sources = {}

function PT.RegisterSource(fn)
	if type(fn) == "function" then sources[#sources + 1] = fn end
end

--- Test seam: forget every source (a real client never calls this).
function PT._ClearSources() sources = {} end

--- { rows = { { text, detail } } } or nil. nil when the class is not pet-capable (nothing is even asked), when there is no source, and when no source has anything useful to say.
function PT.Card(ctx)
	if not (ns.Relevance and ns.Relevance.Applies("petTraining", ctx)) then return nil end
	local rows = {}
	for _, fn in ipairs(sources) do
		local ok, list = pcall(fn, ctx)
		if ok and type(list) == "table" then
			for _, r in ipairs(list) do
				if type(r) == "table" and type(r.text) == "string" and r.text ~= "" and #rows < PT.MAX_ROWS then rows[#rows + 1] = { text = r.text, detail = type(r.detail) == "string" and r.detail or nil } end
			end
		elseif not ok then
			ns.RecordError("pettraining", list)
		end
	end
	if #rows == 0 then return nil end
	return { rows = rows }
end

--- Report lines (developer text, /codex report): what the gate decided for this character and why there is or is not a card.
function PT.ReportLines(ctx)
	local eligible = ns.Relevance and ns.Relevance.Applies("petTraining", ctx)
	local card = PT.Card(ctx)
	return { string.format("PET TRAINING (shown only for pet classes: %s)", ns.Relevance and ns.Relevance.Describe("petTraining") or "?"),
		string.format("  this character: %s | pet sources registered: %d | card: %s%s", eligible and "pet-capable class" or "not a pet class", #sources, card and "shown" or "hidden",
			(eligible and #sources == 0) and " (Quest Flow reads no pet information on Forever yet)" or "") }
end
