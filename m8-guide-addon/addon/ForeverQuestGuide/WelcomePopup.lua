-- ForeverQuestGuide.WelcomePopup: a one-time (until dismissed permanently) welcome prompt.
--
-- Built from bare CreateFrame/CreateTexture/CreateFontString primitives, exactly like the main window --
-- NOT Blizzard's StaticPopupDialogs framework, since that is an XML-template-backed system this project has
-- never used or confirmed on Forever (the same reasoning M8.1/M8.3 already applied to avoid every other
-- template: UIPanelButtonTemplate, UIPanelScrollFrameTemplate, and now StaticPopup). Self-contained in its
-- own file per the M8.5 request's spirit for the minimap button, applied here too.
--
-- Behavior (exact wording from the M8.5 request):
--   "Open Guide" opens the guide and dismisses the popup THIS SESSION ONLY -- it does not persist a
--     do-not-show flag, so the popup can appear again on a future login unless "Don't Show Again" was used.
--   "Don't Show Again" dismisses the popup and PERSISTS ForeverQuestGuideDB.welcomePopupDisabled = true,
--     so it never auto-shows again (until/unless a future milestone adds a way to reset it, which none of
--     M8.5 does).
-- Neither button reads or writes anything about quest or route data -- only the one preference above.

local addonName, ns = ...

local frame

local function newFontString(parent, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	local ok = ns.Safe(fs.SetFontObject, fs, GameFontNormal)
	if not ok then
		ns.Safe(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", 12, "")
	end
	return fs
end

local function newButton(parent, w, h, label, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h)
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints()
	b.bg:SetColorTexture(0.25, 0.25, 0.25, 0.9)
	b.text = newFontString(b, "OVERLAY")
	b.text:SetPoint("CENTER")
	b.text:SetText(label)
	b:SetScript("OnClick", onClick)
	return b
end

local function build()
	frame = CreateFrame("Frame", "ForeverQuestGuideWelcomePopup", UIParent)
	frame:SetSize(360, 170)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
	frame:SetFrameStrata("DIALOG")
	frame:EnableMouse(true)

	frame.bg = frame:CreateTexture(nil, "BACKGROUND")
	frame.bg:SetAllPoints()
	frame.bg:SetColorTexture(0, 0, 0, 0.9)

	frame.border = frame:CreateTexture(nil, "BORDER")
	frame.border:SetPoint("TOPLEFT", -1, 1)
	frame.border:SetPoint("BOTTOMRIGHT", 1, -1)
	frame.border:SetColorTexture(1, 0.82, 0, 0.5)

	local line1 = newFontString(frame, "OVERLAY")
	line1:SetPoint("TOP", frame, "TOP", 0, -16)
	line1:SetText("Welcome to Forever Quest Guide!")

	local line2 = newFontString(frame, "OVERLAY")
	line2:SetPoint("TOP", line1, "BOTTOM", 0, -14)
	line2:SetText("Your leveling guide is ready.")

	local line3 = newFontString(frame, "OVERLAY")
	line3:SetPoint("TOP", line2, "BOTTOM", 0, -14)
	line3:SetWidth(320)
	line3:SetJustifyH("CENTER")
	line3:SetText("Open the guide anytime from the minimap button or by typing /fguide.")

	frame.openBtn = newButton(frame, 140, 26, "Open Guide", function()
		frame:Hide()
		if ns.UI and ns.UI.Toggle then
			-- Only open, never close: the popup guarantees a fresh, closed guide window at this point
			-- (nothing could have opened it before the player has even seen this popup), so toggling here
			-- always means "open," never "close." Toggle() is reused rather than duplicating build logic.
			ns.UI.Toggle()
		end
	end)
	frame.openBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOM", -150, 16)

	frame.dontShowBtn = newButton(frame, 140, 26, "Don't Show Again", function()
		frame:Hide()
		ns.Prefs.DisableWelcomePopup()
	end)
	frame.dontShowBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", 150, 16)
end

local function show()
	if not frame then
		build()
	end
	frame:Show()
end

ns.WelcomePopup = {
	Show = show,
	_selftest_getFrame = function() return frame end,
	_selftest_getButtons = function() return frame and { open = frame.openBtn, dontShow = frame.dontShowBtn } end,
}
