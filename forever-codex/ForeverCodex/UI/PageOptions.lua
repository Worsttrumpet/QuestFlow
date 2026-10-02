-- UI page "Codex Options": the settings tab of the options window. Before the first-time setup is finished it shows the setup panel
-- (route zone, route style, what to look out for, Start); after that, the settings (waypoint, arrow, the game's quest tracker, Hardcore,
-- party news, "Run setup again"). The panels themselves are in UI/PageSetup.lua.

local addonName, ns = ...
local UI = ns.UI

UI.RegisterPage("options", "Codex Options", function(parent)
	local setup = UI.BuildSetup(parent, "setup")
	local settings = UI.BuildSetup(parent, "settings")
	UI.main.setupPanel, UI.main.settingsPanel = setup, settings
	return { Refresh = function()
		if ns.Prefs.SetupDone() then
			setup.frame:Hide()
			settings.frame:Show()
			settings.Refresh()
		else
			settings.frame:Hide()
			setup.frame:Show()
			setup.Refresh()
		end
	end }
end)
