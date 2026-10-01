# Export Contract Semantics

Written in response to the M4 adversarial review's Findings 1.1 and 1.2. This is a design decision and
documentation update only — **no importer exists yet, and none is built by this document.** Its purpose
is to settle two specific ambiguities in the Observation Lab's real export *before* an importer is
written against it, so the importer doesn't have to guess.

## 1. `module_status` — how a future importer should treat it

Inspected: `core/Registry.lua`, `core/Dispatcher.lua`, every file under `modules/proven/` and
`modules/experimental/`, the current exported shape, `docs/HARVEST_CONTRACT.md`, and `M4_PLAN.md`. None
of the last two mention `module_status` at all — it didn't exist when they were written; it was added
later, during the Observation Lab's implementation.

**The distinction that matters**: `module_status` describes the *maturity of the collection code*, not
the *truth value of any individual observation*. A `"proven"` module can still produce a genuinely failed
observation (`data.ok = false` — see §2). An `"experimental"` module running without a Lua error does not
mean the data it captured is real or meaningful; it means the module executed, nothing more (this project
has direct precedent for exactly this trap: `GetRewardHonor` has run successfully every time it's been
called since M3 and always returned `0` — a clean execution that has never once confirmed the API works
for a real, non-zero honor reward).

**Minimal decision, consistent with the existing provenance model, no new ranking tier invented**:

> **A future importer must only ingest observations from `module_status = "proven"` modules.**
> `module_status = "experimental"` observations are not imported at all until the module producing them
> is promoted to `"proven"` — the same standard this entire project has applied since M0: a field
> advances from `[?]`/`[2nd]` to `[V]` only once real, verified evidence exists for it, never on the
> strength of a clean-but-unconfirmed execution.

This requires **zero changes** to `policy.py`'s `SOURCE_KINDS`/`SOURCE_RANK` or to `db.py`'s schema —
there is no separate rank tier for "experimental" data because none should ever reach the ranking system
in the first place. Promoting a module from experimental to proven (which happens in the addon's own
source, by changing one `status` field and updating its registration) is what makes its observations
eligible for import going forward — it does not retroactively import anything captured while the module
was still experimental.

## 2. `observation.ok` vs. `data.ok` — the nested-`ok` distinction

Inspected every proven module's `capture()` return shape. The pattern is consistent across all of them:

- **`observation.ok`** (set by `core/Dispatcher.lua`'s `recordObservation`, the envelope) answers: *did
  the module's Lua code run without throwing an error?* This is a code-health signal, not a data-quality
  signal.
- **`data.ok`** (set by the module itself, inside its own returned table) answers: *did the underlying
  observation this module exists to make actually succeed?*

These are genuinely independent and both are real. The clearest concrete example already in the shipped
code: `RewardsReputation.lua`'s quest-ID guard (added during the earlier audit) can legitimately produce
`observation.ok = true, data.ok = false` — the module ran perfectly correctly, and *correctly refused* to
record a reputation observation it couldn't attribute to a specific quest. That refusal is the module
working as intended, not a failure of the module — but it is absolutely a failure of the *observation*,
and must never be read as real reward data.

**The rule for any future importer, stated plainly enough not to be missed**:

> **`data.ok = false` must never be imported as observed game content, regardless of `observation.ok`'s
> value.** Only `data.ok = true` records carry data worth turning into an assertion. `observation.ok`
> alone is insufficient to decide whether a record's `data` payload means anything.

**Decision on whether to refactor**: the current two-level structure is sound and is kept as-is,
per the instruction to prefer documentation over refactoring when the structure itself isn't broken. The
distinction is real, meaningful, and already correctly maintained by every module — it needed a name and
a documented rule, not a code change.

## Where this leaves the two open items from the adversarial review

Both of the review's Findings 1.1 and 1.2 are addressed by documentation, not by changing the addon:
the semantics were already being followed correctly in code; they simply weren't written down anywhere
a future importer author would be certain to see them before making a wrong assumption. This file is
that place.
