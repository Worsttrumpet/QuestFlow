-- ForeverRecorder.Export: manual, opt-in export only. No automatic saving,
-- no network transmission anywhere in this file or called from it.
--
-- The save-confirmation behavior required by M5 design §11 does not live
-- here: ReloadUI() tears down and rebuilds the whole Lua environment, so
-- nothing after that call in THIS file could ever run to confirm success.
-- The confirmation is Bootstrap.lua's ObservationCountAtLoad /
-- PrintBanner() output on the NEXT load -- a concrete, visible fact
-- ("N observations present at load") rather than a message printed here
-- that cannot actually verify anything.

ForeverRecorder = ForeverRecorder or {}
ForeverRecorder.Export = {}

function ForeverRecorder.Export.Save()
	ForeverRecorder.Say("saving and reloading UI now... check the load message after reload for confirmation.")
	local ok, err = ForeverRecorder.SafeCall(ReloadUI, 0)
	if not ok then
		ForeverRecorder.Say("ReloadUI unavailable: " .. tostring(err))
	end
end
