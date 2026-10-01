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

local dirty = true
local sinceCompute = 0
local DIRTY_DELAY = 0.4      -- seconds before a dirty state recomputes
local PERIODIC = 3           -- seconds between refreshes while the window is open

function S.MarkDirty()
	dirty = true
end

--- Rebuilds the context and the plan now. Never raises; a failure leaves the previous plan in place.
function S.Recompute()
	sinceCompute = 0
	dirty = false
	local okC, ctx = pcall(ns.Context.Build)
	if not okC then
		ns.RecordError("context", ctx)
		return S.plan
	end
	local okE, plan = pcall(ns.Engine.Compute, ctx)
	if not okE then
		ns.RecordError("engine", plan)
		return S.plan
	end
	S.ctx, S.plan = ctx, plan
	S.computeCount = S.computeCount + 1
	if ns.UI and ns.UI.Refresh then
		local okU, err = pcall(ns.UI.Refresh)
		if not okU then ns.RecordError("ui", err) end
	end
	return plan
end

--- Called every frame by Boot's OnUpdate.
function S.Tick(elapsed)
	sinceCompute = sinceCompute + (elapsed or 0)
	if dirty and sinceCompute >= DIRTY_DELAY then
		S.Recompute()
	elseif ns.UI and ns.UI.IsShown and ns.UI.IsShown() and sinceCompute >= PERIODIC then
		S.Recompute()
	end
end
