-- ForeverCodex.Route: adapts engine ACTIONS to the M8.13 step schema, so the proven evaluators
-- (ForeverCodex.Eval, copied from ProgressionEval) can describe live progress for the current action, and so a
-- guided "follow the route" controller (M8.13's Progression.lua) can be reattached later without changing the engine.
--
-- Step kinds ACCEPT / TURN_IN / OBJECTIVE / TRAVEL map one-to-one. Any other action type becomes a step whose
-- kind the evaluator reports as UNDETECTABLE (manual confirmation), which is exactly how future action types
-- (TRAINER, CAMP, ...) behave until they get an evaluator.

local addonName, ns = ...

local Route = {}
ns.Route = Route

local STEP_KINDS = { ACCEPT = true, TURN_IN = true, OBJECTIVE = true, TRAVEL = true }

--- One action -> one M8.13-shaped step.
function Route.Step(a)
	local kind = STEP_KINDS[a.kind] and a.kind or (a.type or "OTHER")
	local step = {
		id = a.id, kind = kind, quest_id = a.quest, provenance = "codex-" .. tostring(a.src or "unknown"),
		display_text = a.title,
		codex = { src = a.src, verified = a.verified == true, actionType = a.type },
	}
	if a.target then
		step.destination = { kind = "CODEX_TARGET", ui_map_id = a.target.map, x = a.target.x, y = a.target.y }
		step.npc = a.giver and { name = a.giver } or nil
	end
	return step
end

--- The plan's sequence as a runtime route table (same shape as ns.Routes entries in M8.13).
function Route.Build(plan)
	local steps, order = {}, {}
	for _, a in ipairs(plan and plan.sequence or {}) do
		local s = Route.Step(a)
		steps[s.id] = s
		order[#order + 1] = s.id
	end
	local route = {
		id = "codex-dynamic", title = "Forever Codex (live plan)", provenance = "codex-dynamic",
		first_step = order[1], steps = steps, step_order = order,
	}
	for i, id in ipairs(order) do
		steps[id].next_step_id = order[i + 1]
	end
	return route
end

--- Live status of one action, using the M8.13 evaluators: { state = SATISFIED|WAITING|UNDETECTABLE, reason, distance }.
function Route.Evaluate(a)
	if not (ns.Eval and ns.Eval.Evaluate) then
		return { state = "UNDETECTABLE", reason = "evaluator not loaded" }
	end
	return ns.Eval.Evaluate(Route.Step(a), nil, nil)
end
