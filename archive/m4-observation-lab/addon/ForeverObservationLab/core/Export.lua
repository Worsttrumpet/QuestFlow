-- ForeverLab.Export: manual, opt-in export only. No automatic saving, no
-- network transmission anywhere in this file or called from it.

ForeverLab = ForeverLab or {}
ForeverLab.Export = {}

function ForeverLab.Export.Save()
	ForeverLab.Say("saving and reloading UI now...")
	local ok, err = ForeverLab.SafeCall(ReloadUI, 0)
	if not ok then
		ForeverLab.Say("ReloadUI unavailable: " .. tostring(err))
	end
end
