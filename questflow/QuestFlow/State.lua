-- ForeverCodex.State: the latest context + plan, and when to recompute.
--
-- Events and player choices only MARK the state dirty; recomputation is throttled so an event burst (quest log
-- updates fire in clusters) costs one engine run. While the window is open the plan is also refreshed every few
-- seconds, because the character moves.

local addonName, ns = ...

local S = {}
ns.State = S

S.ctx, S.plan = nil, nil
S.computeCount = 0
S.mode = "planner"      -- "planner" (Engine.Candidates -> Planner -> adapter) or "legacy" (the old Engine.Compute); not saved

local dirty = true
local sinceCompute = 0
local R = ns.Registry
local DIRTY_DELAY = 0.4      -- seconds before a dirty state recomputes
local PERIODIC = 3           -- seconds between refreshes while the window is open
local TIMED_PERIODIC = 10    -- seconds between refreshes while the window is CLOSED and a timed quest is counting down (only then)
local MOVE_YD = 20           -- yards the player must have moved before an IDLE refresh (nothing marked dirty, no timed quest) is worth a recompute
local WARMUP_MIN_IDS = 1000  -- fewer known quests than this: a plain synchronous first recompute is cheaper than slicing it
local WARM_BUDGET_MS = 6     -- milliseconds of the first scan done per frame while warming up
local lastPos                -- the player's place at the last recompute { available, map, x, y, world }

-- Lightweight performance counters (no timer, no polling: they are updated only where work already happens). Read by /codex report.
local perf = { dirtyBy = {}, recomputeBy = {}, count = 0, total = 0, worst = 0, last = nil, worstReason = nil }
S.perf = perf
local function clockMs()
	local f = _G.debugprofilestop
	if type(f) == "function" then
		local ok, v = pcall(f)
		if ok and type(v) == "number" then return v end
	end
	return nil
end
local function addonMemoryKb()
	local f = _G.GetAddOnMemoryUsage
	if type(f) ~= "function" then return nil end
	local u = _G.UpdateAddOnMemoryUsage
	if type(u) == "function" then pcall(u) end
	local ok, v = pcall(f, addonName)
	return ok and type(v) == "number" and v or nil
end
S.AddonMemoryKb = addonMemoryKb
S.Clock = clockMs            -- (PlanAdapter times its two stages with the same clock)
perf.startedAt = type(_G.GetTime) == "function" and _G.GetTime() or nil

--- Marks the plan stale. `why` (optional, an event name) only feeds the counters; callers that pass nothing count as "other".
function S.MarkDirty(why)
	dirty = true
	local k = type(why) == "string" and why or "other"
	perf.dirtyBy[k] = (perf.dirtyBy[k] or 0) + 1
end

--- Switches between the Planner and the legacy engine path (kept for comparison and as a fallback). Session only.
function S.SetPlanner(on)
	S.mode = on and "planner" or "legacy"
	dirty = true
end

--- Rebuilds the context and the plan now. Never raises; a failure leaves the previous plan in place.
function S.Recompute(reason)
	if S.warmup.state == "running" then S.warmup.state, S.warmup.early, S.warmup.ids = "done", true, nil end     -- someone needs the plan NOW: the scan is paid for here instead
	local t0 = clockMs()
	local plan = S.RecomputeInner()
	local t1 = clockMs()
	reason = type(reason) == "string" and reason or "direct"
	perf.count = perf.count + 1
	perf.recomputeBy[reason] = (perf.recomputeBy[reason] or 0) + 1
	if t0 and t1 then
		local ms = t1 - t0
		perf.last, perf.total = ms, perf.total + ms
		if ms > perf.worst then
			perf.worst, perf.worstReason, perf.worstN = ms, reason, perf.count
			-- where the worst one went (scalars copied from the stage timers below: nothing allocated, nothing measured beyond four clock reads per recompute)
			perf.wCtx, perf.wCand, perf.wPlan = perf.stCtx, perf.stCand, perf.stPlan
		end
		if perf.count == 1 then perf.firstMs = ms end
	end
	if perf.memFirstKb == nil and perf.count == 1 then perf.memFirstKb = addonMemoryKb() or false end   -- once, after the first (cold) build
	return plan
end

function S.RecomputeInner()
	sinceCompute = 0
	dirty = false
	local tCtx = clockMs()
	local okC, ctx = pcall(ns.Context.Build)
	local tCtx2 = clockMs()
	perf.stCtx, perf.stCand, perf.stPlan = (tCtx and tCtx2) and (tCtx2 - tCtx) or nil, nil, nil
	if not okC then
		ns.RecordError("context", ctx)
		return S.plan
	end
	-- Observers of the CONTEXT alone (quest-log progress for the party and the journey, level-based cards) must not depend on the
	-- planner succeeding: a planner error must never hide that an objective was finished.
	local function observeCtx(name, mod, fn)
		if mod and mod[fn] then
			local okO, errO = pcall(mod[fn], ctx)
			if not okO then ns.RecordError(name, errO) end
		end
	end
	if ns.Prefs.NoteLevel then ns.Prefs.NoteLevel(ctx.char and ctx.char.level) end
	observeCtx("areaevidence", ns.AreaEvidence, "Observe")
	observeCtx("questtimers", ns.QuestTimers, "Observe")           -- BEFORE the planner: a timed quest's live remaining time is an input to its value
	observeCtx("journey", ns.Journey, "OnContext")
	observeCtx("party", ns.Party, "OnContext")
	observeCtx("newforyou", ns.NewForYou, "OnContext")
	local okE, plan
	if S.mode == "planner" then
		okE, plan = pcall(ns.PlanAdapter.Compute, ctx, { prevNowId = S.plan and S.plan.now and S.plan.now.id or nil })
		if not okE then
			-- never leave the player without a recommendation: record the error and fall back to the old engine
			ns.RecordError("planner", plan)
			okE, plan = pcall(ns.Engine.Compute, ctx)
			if okE then plan.warnings[#plan.warnings + 1] = "The planner failed (see /qflow diag); using the previous method." end
		end
	else
		okE, plan = pcall(ns.Engine.Compute, ctx)
	end
	if not okE then
		ns.RecordError("engine", plan)
		return S.plan
	end
	S.ctx, S.plan = ctx, plan
	S.computeCount = S.computeCount + 1
	local l = ctx.loc
	lastPos = l and { available = l.available, map = l.map, x = l.x, y = l.y, world = l.world and { continent = l.world.continent, x = l.world.x, y = l.world.y } or nil } or nil
	-- Consumers of the new context and plan. Each is isolated: a failure in one never costs the player the recommendation.
	local function observe(name, mod, fn, ...)
		if mod and mod[fn] then
			local okO, errO = pcall(mod[fn], ...)
			if not okO then ns.RecordError(name, errO) end
		end
	end
	observe("navigation", ns.Navigation, "OnPlan", plan, ctx)
	if ns.UI and ns.UI.Refresh then
		local okU, err = pcall(ns.UI.Refresh)
		if not okU then ns.RecordError("ui", err) end
	end
	return plan
end

--- Called every frame by Boot's OnUpdate.
--- Skips the current NOW (the player's veto on a recommendation that is wrong or unavailable) and recomputes. Returns the skipped action, or nil
-- when there was nothing to skip. `/codex unskip` brings skipped items back. The same call backs `/codex skip` and the Skip button on the NOW card.
function S.SkipCurrent()
	local plan = S.plan or S.Recompute()
	local a = plan and (plan.now or plan.next)
	if a and ns.Prefs.Skip(a.skipKey) then
		S.Recompute()
		return a
	end
	return nil
end

-- ---------------------------------------------------------------- the first scan, spread across frames
--
-- The first recompute of a session is slow (measured on the real client: about 600 ms, of which about 375 ms is building every known quest's record once). Doing it inside the login frame
-- freezes the game for that long. BeginLogin therefore WARMS the quest records a few milliseconds per frame (the same Registry.Quest calls the scan makes, so the result is identical) and runs
-- the one real recompute when they are all built (about the cost of any later refresh). Until then the window says "Gathering information...". Nothing about the plan changes.
S.warmup = { state = "idle" }

local function stepWarmup()
	local w = S.warmup
	local t0 = clockMs()
	local done = 0
	while w.i <= w.n do
		pcall(R.Quest, w.ids[w.i])
		w.i = w.i + 1
		done = done + 1
		if done % 20 == 0 then
			local t = clockMs()
			if t0 and t then
				if t - t0 >= WARM_BUDGET_MS then break end
			elseif done >= 60 then break end                 -- no clock on this client: a fixed slice per frame
		end
	end
	w.frames = w.frames + 1
	local t1 = clockMs()
	if t0 and t1 then w.ms = w.ms + (t1 - t0) end
	if w.i > w.n then
		w.state = "done"
		w.ids = nil
		S.Recompute("warmup")
	end
end

--- Called by Boot at login instead of an immediate Recompute. Small data sets recompute at once; a large one is warmed over several frames (see above).
function S.BeginLogin()
	local ids = R.QuestIds()
	if #ids < WARMUP_MIN_IDS then
		S.warmup = { state = "skipped", n = #ids }
		return S.Recompute("login")
	end
	local okC, ctx = pcall(ns.Context.Build)             -- cheap: the character, the place, the quest log. The window can already say who and where.
	if okC then S.ctx = ctx else ns.RecordError("context", ctx) end
	S.warmup = { state = "running", ids = ids, i = 1, n = #ids, frames = 0, ms = 0 }
	return nil
end

--- True when the player has moved far enough (or changed map) since the last plan that an idle refresh could change what it says.
local function moved()
	local okL, l = pcall(ns.Context.Position)
	if not okL or type(l) ~= "table" then return true end             -- cannot tell: refresh, as before
	local p = lastPos
	if not p then return true end
	if l.map ~= p.map or l.available ~= p.available then return true end
	if l.world and p.world and l.world.continent == p.world.continent then
		local dx, dy = l.world.x - p.world.x, l.world.y - p.world.y
		return dx * dx + dy * dy >= MOVE_YD * MOVE_YD
	end
	if type(l.x) == "number" and type(p.x) == "number" then return math.abs(l.x - p.x) > 0.004 or math.abs(l.y - p.y) > 0.004 end
	return false
end

function S.Tick(elapsed)
	if S.warmup.state == "running" then stepWarmup() return end
	sinceCompute = sinceCompute + (elapsed or 0)
	if dirty and sinceCompute >= DIRTY_DELAY then
		S.Recompute("dirty")
	elseif ns.UI and ns.UI.IsShown and ns.UI.IsShown() and sinceCompute >= PERIODIC then
		-- the window is open and NOTHING was marked dirty: a refresh only matters when the player has moved (distances change) or a timed quest is counting down. Otherwise skip it and leave the window as it is.
		if (ns.QuestTimers and ns.QuestTimers.AnyActive()) or moved() then
			S.Recompute("periodic")
		else
			sinceCompute = 0
			perf.skippedIdle = (perf.skippedIdle or 0) + 1
		end
	elseif ns.QuestTimers and ns.QuestTimers.AnyActive() and sinceCompute >= TIMED_PERIODIC then
		S.Recompute("timed quest")           -- the window is closed but a quest is counting down: the plan (and the arrow) must follow the deadline
	end
end
