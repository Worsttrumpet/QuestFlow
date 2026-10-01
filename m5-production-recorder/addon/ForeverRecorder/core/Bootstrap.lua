-- ForeverRecorder.Bootstrap: ported from the Observation Lab's Bootstrap.lua
-- with one addition (marked below): a persistence-confirmation signal,
-- per M5 design §11.

ForeverRecorder = ForeverRecorder or {}
ForeverRecorder.RECORDER_VERSION = "m5-recorder-0.1"
ForeverRecorder.EXPECTED_INTERFACE = 16001

ForeverObservationLabDB = ForeverObservationLabDB or {
	meta = {},
	observations = {},
}

function ForeverRecorder.Now()
	return date("%Y-%m-%d %H:%M:%S")
end

function ForeverRecorder.Say(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff33cc99[FRecorder]|r " .. msg)
	end
end

-- Seeds math.random once, at addon init (ported unchanged from the Lab's
-- own fix, found necessary by the M4 adversarial review: the Lab called
-- math.random() but never math.randomseed(), an unconfirmed-consequence
-- but real code-level gap). Uses only clock-based values already available
-- in the WoW addon sandbox; neither value is account/character/realm
-- information, and neither is stored or exported.
local function seedPRNG()
	local okT, _, vT = ForeverRecorder.SafeCall(time, 1)
	local okG, _, vG = ForeverRecorder.SafeCall(GetTime, 1)
	local seed = (okT and vT[1] or 0) + (okG and vG[1] or 0)
	ForeverRecorder.SafeCall(math.randomseed, 0, seed)
end

-- Random per LOGIN, not persisted across sessions or reused.
local function randomSessionID()
	local a = math.random(0, 0xFFFFFFF)
	local b = math.random(0, 0xFFFFFFF)
	return string.format("%07x%07x", a, b)
end

function ForeverRecorder.InitMeta()
	seedPRNG() -- must run before randomSessionID() is ever called

	-- NEW FOR M5 (design §11): captured BEFORE this session adds anything,
	-- so it reflects exactly what survived from the PREVIOUS session's
	-- save/reload round trip -- the concrete, visible persistence signal
	-- the design calls for, since ReloadUI() itself gives no confirmation
	-- once it actually reloads (the whole Lua state resets, so nothing
	-- can print "the save worked" until the NEXT login).
	ForeverRecorder.ObservationCountAtLoad = #ForeverObservationLabDB.observations

	local okB, errB, vB = ForeverRecorder.SafeCall(GetBuildInfo, 4)
	local okL, errL, vL = ForeverRecorder.SafeCall(GetLocale, 1)
	local tocv = okB and vB[4] or nil

	ForeverRecorder.CurrentSessionID = randomSessionID()

	-- Per-observation build snapshot -- same reasoning and pattern as
	-- CurrentSessionID: meta gets overwritten every login, so an
	-- observation that only read meta.observed_build at export time would
	-- silently take on whatever build the LATEST session reported.
	ForeverRecorder.CurrentBuildInfo = {
		observed_version = okB and vB[1] or nil,
		observed_build = okB and vB[2] or nil,
		observed_build_date = okB and vB[3] or nil,
		observed_toc_version = tocv,
	}

	ForeverObservationLabDB.meta = {
		-- KEY NAME must be "lab_version" -- this is baked into the documented
		-- v1 contract itself (schema's required list, HARVEST_CONTRACT.md),
		-- not just a Lab-specific implementation detail. The VALUE correctly
		-- identifies this as the recorder, not the Lab -- only the key name
		-- must match the existing contract exactly.
		lab_version = ForeverRecorder.RECORDER_VERSION,
		recorded_at = ForeverRecorder.Now(),
		session_id = ForeverRecorder.CurrentSessionID,
		observed_version = okB and vB[1] or nil,
		observed_build = okB and vB[2] or nil,
		observed_build_date = okB and vB[3] or nil,
		observed_toc_version = tocv,
		expected_toc_version = ForeverRecorder.EXPECTED_INTERFACE,
		toc_version_matches_expectation = okB and (tocv == ForeverRecorder.EXPECTED_INTERFACE) or nil,
		-- locale is captured and exported here, same as the Observation Lab.
		-- NOTE: as of this writing, neither the recorder nor the M4 importer
		-- consumes this field for anything -- it is preserved, not acted
		-- upon. Not described as "used downstream" anywhere in this addon
		-- or its documentation, since that has not been verified.
		locale = okL and vL[1] or nil,
		build_info_ok = okB, build_info_error = (not okB) and errB or nil,
		locale_ok = okL, locale_error = (not okL) and errL or nil,
	}
end

function ForeverRecorder.PrintBanner()
	local m = ForeverObservationLabDB.meta
	ForeverRecorder.Say("recorder " .. ForeverRecorder.RECORDER_VERSION .. " loaded. Read-only: does not "
		.. "accept/complete/turn in quests, never calls GetQuestReward().")
	ForeverRecorder.Say(string.format("GetBuildInfo() = %s, %s, %s, %s | locale=%s",
		tostring(m.observed_version), tostring(m.observed_build), tostring(m.observed_build_date),
		tostring(m.observed_toc_version), tostring(m.locale)))
	if m.toc_version_matches_expectation then
		ForeverRecorder.Say("Interface matches the recorded expectation (" .. ForeverRecorder.EXPECTED_INTERFACE .. "). [V]")
	elseif m.toc_version_matches_expectation == false then
		ForeverRecorder.Say("Interface DIFFERS from the recorded expectation (" .. ForeverRecorder.EXPECTED_INTERFACE
			.. "). Recording the real value, not treating this as an error.")
	end
	-- NEW FOR M5 (design §11): the persistence-confirmation signal itself.
	-- A visible, concrete fact the player can check every login: did
	-- anything survive from before. This does not diagnose WHY a save was
	-- or wasn't retained (the SavedVariables logout-persistence root cause
	-- remains [?], never solved by this addon) -- it only reports the
	-- observable fact plainly.
	ForeverRecorder.Say(string.format(
		"%d observation(s) present at load (persisted from a previous session, if any).",
		ForeverRecorder.ObservationCountAtLoad))
end
