if SERVER then
	AddCSLuaFile()
	return
end

Steam = Steam or {}

Steam.ProfileURL = "https://steamcommunity.com/miniprofile/%s/"
Steam.DefaultAvatar = "https://avatars.fastly.steamstatic.com/fef49e7fa7e1997310d705b2a6158ff8dc1cdfeb_full.jpg"
Steam.PatternAvatar = [[<div class="playersection_avatar%s[%s%S]-<img%s+[^>]-src="(https://[^"]-)"[^>]->]]

--- @type table<string, string>
Steam.AvatarCache = Steam.AvatarCache or {}

Steam.BotID = "90071996842377216"

Steam.RequestInterval = 0.2
Steam.MaxActiveRequests = 2
Steam.RateLimitBackoff = 10

--- @type string[]
Steam.AvatarQueue = Steam.AvatarQueue or {}

--- @type table<string, function[]>
Steam.AvatarPending = Steam.AvatarPending or {}

Steam.ActiveRequests = Steam.ActiveRequests or 0
Steam.NextRequestTime = Steam.NextRequestTime or 0



--- @param SteamID64 string
--- @return boolean
function Steam.IsBotID(SteamID64)
	if SteamID64 == "0" then return false end -- -multirun
	if string.len(SteamID64) ~= 17 then return false end

	return SteamID64 >= Steam.BotID and string.StartsWith(SteamID64, "90071996")
end

--- @param SteamID64 string
--- @return number|nil
function Steam.SteamIDToCommunityID(SteamID64)
	local SteamID = util.SteamIDFrom64(SteamID64)

	if SteamID == "STEAM_0:0:0" then
		return nil
	end

	local Universe, ID, AccountID = string.match(SteamID, "^STEAM_(%d+):(%d+):(%d+)$")
	if not Universe then return nil end

	ID = tonumber(ID)
	AccountID = tonumber(AccountID)

	if not ID or not AccountID then
		return nil
	end

	return (AccountID * 2) + ID
end

--- @param SteamID64 string
--- @param Callback function
function Steam.FetchProfile(SteamID64, Callback)
	local CommunityID = Steam.SteamIDToCommunityID(SteamID64)

	if not CommunityID then
		Callback(nil)
		return
	end

	local ProfileURL = Format(Steam.ProfileURL, CommunityID)

	http.Fetch(
		ProfileURL,

		function(Body, Size, Headers, Code)
			if Code ~= 200 then
				Callback(nil, Code)
				return
			end

			Callback(Body, Code)
		end,

		function(Error)
			Callback(nil, nil)
		end,

		{
			["accept"] = "text/html",
			["accept-language"] = "en"
		}
	)
end

--- @param SteamID64 string
--- @param Callback function
function Steam.FetchAvatar(SteamID64, Callback)
	local AvatarCache = Steam.AvatarCache

	if Steam.IsBotID(SteamID64) then
		AvatarCache[SteamID64] = Steam.GetDefaultAvatar()
	end

	if AvatarCache[SteamID64] then
		Callback(AvatarCache[SteamID64])
		return
	end

	local Pending = Steam.AvatarPending[SteamID64]

	if Pending then
		Pending[#Pending + 1] = Callback
		return
	end

	Steam.AvatarPending[SteamID64] = { Callback }
	Steam.AvatarQueue[#Steam.AvatarQueue + 1] = SteamID64
end

--- @param SteamID64 string
--- @param AvatarURL string|nil
function Steam.ResolveAvatar(SteamID64, AvatarURL)
	local Callbacks = Steam.AvatarPending[SteamID64]
	Steam.AvatarPending[SteamID64] = nil

	if not Callbacks then return end

	for i = 1, #Callbacks do
		xpcall(Callbacks[i], ErrorNoHaltWithStack, AvatarURL)
	end
end

--- @param SteamID64 string
function Steam.StartAvatarRequest(SteamID64)
	Steam.ActiveRequests = Steam.ActiveRequests + 1

	Steam.FetchProfile(SteamID64, function(Data, Code)
		Steam.ActiveRequests = math.max(Steam.ActiveRequests - 1, 0)

		if Code == 429 then
			Steam.NextRequestTime = math.max(Steam.NextRequestTime, SysTime() + Steam.RateLimitBackoff)
		end

		local AvatarURL

		if isstring(Data) and string.len(Data) > 0 then
			AvatarURL = string.match(Data, Steam.PatternAvatar)
			-- AvatarURL = AvatarURL or Steam.DefaultAvatar

			if AvatarURL then
				Steam.AvatarCache[SteamID64] = AvatarURL
			end
		end

		Steam.ResolveAvatar(SteamID64, AvatarURL)
	end)
end

function Steam.ProcessAvatarQueue()
	local Queue = Steam.AvatarQueue
	if #Queue < 1 then return end

	if Steam.ActiveRequests >= Steam.MaxActiveRequests then return end

	local Now = SysTime()
	if Now < Steam.NextRequestTime then return end

	local SteamID64 = table.remove(Queue, 1)
	Steam.NextRequestTime = Now + Steam.RequestInterval

	local Cached = Steam.AvatarCache[SteamID64]

	if Cached then
		Steam.ResolveAvatar(SteamID64, Cached)
		return
	end

	Steam.StartAvatarRequest(SteamID64)
end
hook.Add("Think", "Steam.ProcessAvatarQueue", Steam.ProcessAvatarQueue) -- This might cause cancer

--- Returns the default ? avatar
--- @return string
function Steam.GetDefaultAvatar()
	return Steam.DefaultAvatar
end
