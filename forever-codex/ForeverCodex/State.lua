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
local DIRTY_DELAY = 0.4      -- seconds before a dirty state recomputes
local PERIODIC = 3           -- seconds between refreshes while the window is open

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
	local t0 = clockMs()
	local plan = S.RecomputeInner()
	local t1 = clockMs()
	reason = type(reason) == "string" and reason or "direct"
	perf.count = perf.count + 1
	perf.recomputeBy[reason] = (perf.recomputeBy[reason] or 0) + 1
	if t0 and t1 then
		local ms = t1 - t0
		perf.last, perf.total = ms, perf.total + ms
		if ms > perf.worst then perf.worst, perf.worstReason = ms, reason end
	end
	if perf.memFirstKb == nil and perf.count == 1 then perf.memFirstKb = addonMemoryKb() or false end   -- once, after the first (cold) build
	return plan
end

function S.RecomputeInner()
	sinceCompute = 0
	dirty = false
	local okC, ctx = pcall(ns.Context.Build)
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
			if okE then plan.warnings[#plan.warnings + 1] = "The planner failed (see /codex diag); using the previous method." end
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

function S.Tick(elapsed)
	sinceCompute = sinceCompute + (elapsed or 0)
	if dirty and sinceCompute >= DIRTY_DELAY then
		S.Recompute("dirty")
	elseif ns.UI and ns.UI.IsShown and ns.UI.IsShown() and sinceCompute >= PERIODIC then
		S.Recompute("periodic")
	end
end
