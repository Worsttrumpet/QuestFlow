-- ForeverRecorder.SlashCommands: exactly the three commands the M5 design
-- specifies -- status, save, clear. No scan (no diagnostic surface needed
-- in production), no list/enable/disable (no experimental modules exist
-- to toggle -- Registry.lua hard-enforces this).

ForeverRecorder = ForeverRecorder or {}

SLASH_FOREVERRECORDER1 = "/fr"
SlashCmdList["FOREVERRECORDER"] = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

	if msg == "status" then
		ForeverRecorder.Say(string.format(
			"observations recorded: %d | session: %s | build: %s",
			#ForeverObservationLabDB.observations,
			tostring(ForeverRecorder.CurrentSessionID),
			tostring(ForeverRecorder.CurrentBuildInfo and ForeverRecorder.CurrentBuildInfo.observed_build)))
	elseif msg == "save" then
		ForeverRecorder.Export.Save()
	elseif msg == "clear" then
		ForeverObservationLabDB.observations = {}
		ForeverRecorder.Say("cleared all recorded observations (meta kept).")
	else
		ForeverRecorder.Say("usage: /fr status | /fr save | /fr clear")
	end
end
