-- ForeverLab.Bootstrap: SavedVariables shape, meta capture, chat helper.
-- Depends on ForeverLab.SafeCall (SafeCall.lua) -- load order within the
-- core/ folder doesn't matter for correctness here, since nothing in this
-- file executes until an event fires (after every file has loaded), but
-- SafeCall.lua is listed first in the .toc for readability.

ForeverLab = ForeverLab or {}
ForeverLab.LAB_VERSION = "m4-observation-lab-0.1"
-- Recorded assumption from M2/M3/every prior M4 probe; checked, not required.
ForeverLab.EXPECTED_INTERFACE = 16001

ForeverObservationLabDB = ForeverObservationLabDB or {
	meta = {},
	api_scan = {},
	observations = {},
}

function ForeverLab.Now()
	return date("%Y-%m-%d %H:%M:%S")
end

function ForeverLab.Say(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff[FLab]|r " .. msg)
	end
end

-- Seeds math.random once, at addon init, so the session ID below doesn't
-- rely on however Lua/WoW happens to initialize the PRNG by default (found
-- during the M4 adversarial review: the addon called math.random() but
-- never math.randomseed(), a real gap even though its real-world
-- consequence on this specific client was unconfirmed). Uses only
-- clock-based values already available in the WoW addon sandbox --
-- time() (Unix seconds) and GetTime() (sub-second float, time since the
-- client process started) -- combined so two logins landing in the same
-- integer second still get different seeds. Neither value is account,
-- character, or realm information, and neither is stored or exported;
-- this seeds the PRNG, it is not itself a session identifier.
-- NOTE: this does not claim cryptographic-quality randomness -- it only
-- avoids depending on an unverified implicit default seed.
local function seedPRNG()
	local okT, _, vT = ForeverLab.SafeCall(time, 1)
	local okG, _, vG = ForeverLab.SafeCall(GetTime, 1)
	local seed = (okT and vT[1] or 0) + (okG and vG[1] or 0)
	ForeverLab.SafeCall(math.randomseed, 0, seed)
end

-- Random per LOGIN, not persisted across sessions or reused -- satisfies
-- "avoid unnecessary persistent identifiers" while still letting one
-- session's observations be grouped together if useful later.
local function randomSessionID()
	local a = math.random(0, 0xFFFFFFF)
	local b = math.random(0, 0xFFFFFFF)
	return string.format("%07x%07x", a, b)
end

function ForeverLab.InitMeta()
	seedPRNG() -- must run before randomSessionID() is ever called; see note above
	local okB, errB, vB = ForeverLab.SafeCall(GetBuildInfo, 4)
	local okL, errL, vL = ForeverLab.SafeCall(GetLocale, 1)
	local tocv = okB and vB[4] or nil

	-- Generated once per login, kept in memory for the rest of THIS session
	-- (ForeverLab.CurrentSessionID), and stamped onto every observation at
	-- the moment it's created (see Dispatcher.lua's recordObservation).
	-- meta.session_id below is a convenience mirror for quick inspection of
	-- "what session is this file's meta from right now" -- it is NOT the
	-- source of truth for any individual observation, since meta gets
	-- overwritten on the next login while already-recorded observations
	-- must keep the session_id they were actually captured under.
	ForeverLab.CurrentSessionID = randomSessionID()

	-- Same pattern as CurrentSessionID, and for the same reason: meta gets
	-- overwritten on the next login, so an observation that only read
	-- meta.observed_build at export time would silently take on whatever
	-- build the LATEST session reported, not the one that actually
	-- produced it -- the exact gap the session_id fix closed, left open
	-- here until now (found in the M4 adversarial review). Only the
	-- fields that actually distinguish one build from another are kept:
	-- not locale, not lab_version, not the ok/error flags -- those aren't
	-- about identifying which build produced an observation.
	ForeverLab.CurrentBuildInfo = {
		observed_version = okB and vB[1] or nil,
		observed_build = okB and vB[2] or nil,
		observed_build_date = okB and vB[3] or nil,
		observed_toc_version = tocv,
	}

	ForeverObservationLabDB.meta = {
		lab_version = ForeverLab.LAB_VERSION,
		recorded_at = ForeverLab.Now(),
		session_id = ForeverLab.CurrentSessionID,
		observed_version = okB and vB[1] or nil,
		observed_build = okB and vB[2] or nil,
		observed_build_date = okB and vB[3] or nil,
		observed_toc_version = tocv,
		expected_toc_version = ForeverLab.EXPECTED_INTERFACE,
		toc_version_matches_expectation = okB and (tocv == ForeverLab.EXPECTED_INTERFACE) or nil,
		locale = okL and vL[1] or nil,
		build_info_ok = okB, build_info_error = (not okB) and errB or nil,
		locale_ok = okL, locale_error = (not okL) and errL or nil,
	}
end

function ForeverLab.PrintBanner()
	local m = ForeverObservationLabDB.meta
	ForeverLab.Say("lab " .. ForeverLab.LAB_VERSION .. " loaded. Read-only: does not accept/complete/turn in "
		.. "quests, never calls GetQuestReward().")
	ForeverLab.Say(string.format("GetBuildInfo() = %s, %s, %s, %s | locale=%s",
		tostring(m.observed_version), tostring(m.observed_build), tostring(m.observed_build_date),
		tostring(m.observed_toc_version), tostring(m.locale)))
	if m.toc_version_matches_expectation then
		ForeverLab.Say("Interface matches the recorded expectation (" .. ForeverLab.EXPECTED_INTERFACE .. "). [V]")
	elseif m.toc_version_matches_expectation == false then
		ForeverLab.Say("Interface DIFFERS from the recorded expectation (" .. ForeverLab.EXPECTED_INTERFACE
			.. "). Recording the real value, not treating this as an error.")
	end
end
