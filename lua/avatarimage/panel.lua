if SERVER then
	AddCSLuaFile()
	return
end

local PANEL = {}

AccessorFunc(PANEL, "m_strSteamID", "PlayerSteamID", FORCE_STRING)

AccessorFunc(PANEL, "m_bLoadingAvatar", "LoadingAvatar", FORCE_BOOL)
AccessorFunc(PANEL, "m_bTryLoad", "TryLoad", FORCE_BOOL)

function PANEL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:SetPaintBorderEnabled(false)
	self:SetText("")

	self:SetPlayerSteamID("0")

	self:SetLoadingAvatar(false)
	self:SetTryLoad(false)

	self:LoadAvatar()
end

--- @param SteamID64 string
function PANEL:SetPlayerSteamID(SteamID64)
	self.m_strSteamID = tostring(SteamID64)

	self:LoadAvatar()
end

--- Sets the Panel's SteamID to the SteamID64 of the given Player
--- @param Player Player
function PANEL:SetPlayer(Player)
	local SteamID64 = Player:SteamID64()
	self:SetPlayerSteamID(SteamID64)
end

--- Sets the Panel's SteamID, will be converted to SteamID64
--- @param SteamID string
function PANEL:SetSteamID(SteamID)
	local SteamID64 = util.SteamIDTo64(SteamID)

	if SteamID64 == "0" then
		error("Invalid SteamID in SetSteamID")
	end

	self:SetPlayerSteamID(SteamID64)
end

--- Sets the Panel's SteamID
--- @param SteamID64 string
function PANEL:SetSteamID64(SteamID64)
	local SteamID = util.SteamIDFrom64(SteamID64)
	local SteamIDTest = util.SteamIDTo64(SteamID)

	if SteamIDTest ~= SteamID64 then
		error("Invalid SteamID in SetSteamID64")
	end

	self:SetPlayerSteamID(SteamID64)
end

--- Makes sure m_pHTML is valid
--- @return Panel|nil
function PANEL:EnsureHTML()
	local HTML = self.m_pHTML

	if not ispanel(HTML) or not IsValid(HTML) then
		self.m_pHTML = vgui.Create("DHTML", self)
		HTML = self.m_pHTML

		if not IsValid(HTML) then
			error("Failed to create DHTML for AvatarImageEx")
			return nil
		end

		HTML:Dock(FILL)
	end

	return HTML
end

function PANEL:TryLoad()
	self:SetTryLoad(false)

	Steam.FetchAvatar(self:GetPlayerSteamID(), function(AvatarURL)
		if not IsValid(self) then return end

		if not self:GetLoadingAvatar() then
			-- Another attempt succeeded
			return
		end

		if not AvatarURL then
			-- Ohh try again
			self:SetTryLoad(true)
			return
		else
			self:SetLoadingAvatar(false)
			self:SetTryLoad(false)
		end

		local HTML = self:EnsureHTML()

		if not HTML then
			return
		end

		HTML:OpenURL(AvatarURL)
	end)
end

function PANEL:Think()
	if self:GetLoadingAvatar() and self:GetTryLoad() then
		self:TryLoad()
	end
end

--- Makes the panel (re)load the avatar
function PANEL:LoadAvatar()
	local HTML = self:EnsureHTML()

	if HTML then
		HTML:OpenURL(Steam.GetDefaultAvatar())
	end

	if self:GetPlayerSteamID() ~= "0" then
		self:SetLoadingAvatar(true)
		self:SetTryLoad(true)
	end
end

vgui.Register("AvatarImage", PANEL, "EditablePanel")
