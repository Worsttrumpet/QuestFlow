-- Minimal, permissive fake WoW UI environment for M8.1's execute-level
-- self-test ONLY. This is NOT a claim that these APIs behave this way on
-- the real Forever client -- it exists solely to catch genuine Lua errors
-- (nil references, bad argument counts, typos) in Core.lua/UI.lua that pure
-- syntax parsing (loadfile/luac -p) cannot catch, since parsing never
-- executes a single line. Every real-client behavior claim in
-- docs/M8_1_COMPLETION_REPORT.md is drawn from the manual test procedure,
-- never from this stub.
--
-- Unlike the project's existing m5-production-recorder/tests/stub_env.lua
-- (which fakes quest/gossip/reward APIs to validate observer logic against
-- known real captures), this stub fakes only the generic UI object model
-- (CreateFrame, textures, font strings, event registration) that M8.1's
-- addon actually calls, and does not touch or duplicate that file.

local calls = {}
local function log(name)
	calls[name] = (calls[name] or 0) + 1
end

local FrameMT = {}
FrameMT.__index = function(t, k)
	log("Frame:" .. k)
	return function(self, ...)
		if k == "CreateFontString" or k == "CreateTexture" then
			return setmetatable({}, FrameMT)
		elseif k == "IsShown" then
			return t._shown or false
		elseif k == "Show" then
			t._shown = true
		elseif k == "Hide" then
			t._shown = false
		elseif k == "SetScript" then
			t._scripts = t._scripts or {}
			t._scripts[(select(1, ...))] = select(2, ...)
		elseif k == "GetScript" then
			return t._scripts and t._scripts[(select(1, ...))]
		elseif k == "SetText" then
			-- M8.6-A: needed to test the search box's real OnTextChanged handler, which calls
			-- self:GetText() -- without this, GetText would fall through to the generic chainable
			-- no-op below and return the object itself instead of a string.
			t._text = (select(1, ...)) or ""
		elseif k == "GetText" then
			return t._text or ""
		end
		return t -- chainable no-op for everything else (SetPoint, SetSize, SetText, ...)
	end
end

local function newObject()
	-- _shown/_scripts are pre-populated as REAL table fields (not left to
	-- __index) so later reads of t._shown / t._scripts hit the raw table
	-- directly instead of re-triggering __index, which would otherwise
	-- return a fresh no-op-method closure (always truthy) instead of the
	-- actual stored value.
	return setmetatable({ _shown = false, _scripts = {}, _text = "" }, FrameMT)
end

function CreateFrame(frameType, globalName, parent, template)
	log("CreateFrame:" .. tostring(frameType))
	local f = newObject()
	if globalName then
		_G[globalName] = f
	end
	return f
end

DEFAULT_CHAT_FRAME = { AddMessage = function(self, msg) log("Say") end }
UIParent = newObject()
GameFontNormal = newObject()
-- M8.5: neither of these has been confirmed to exist on Forever (see MinimapButton.lua's own header
-- comment for the reasoning on Minimap specifically). Defined here only so the self-test can execute
-- MinimapButton.lua's/WelcomePopup.lua's tooltip code without erroring -- their EXISTENCE on the real
-- client is untested; this stub cannot and does not claim otherwise.
Minimap = newObject()
GameTooltip = newObject()

SlashCmdList = {}

function GetBuildInfo()
	log("GetBuildInfo")
	return "1.60.1", "70009", "Sep 23 2026", 16001
end

return { calls = calls }
