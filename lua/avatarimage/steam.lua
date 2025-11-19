if SERVER then
	AddCSLuaFile()
	return
end

Steam = Steam or {}

Steam.ProfileURL = "https://steamcommunity.com/miniprofile/%s/"
Steam.DefaultAvatar = "https://avatars.fastly.steamstatic.com/fef49e7fa7e1997310d705b2a6158ff8dc1cdfeb_full.jpg"
Steam.PatternAvatar = [[<div class="playersection_avatar%s[%s%S]-<img%s+[^>]-src="(https://[^"]-)"[^>]->]]

--- @param SteamID64 string
--- @return number|nil
function Steam.SteamIDToCommunityID(SteamID64)
	local SteamID = util.SteamIDFrom64(SteamID64)

	if SteamID == "STEAM_0:0:0" then
		print("bad conversion")
		return nil
	end

	local Universe, ID, AccountID = string.match(SteamID, "^STEAM_(%d+):(%d+):(%d+)$")
	if not Universe then print("no Universe", SteamID) return nil end

	ID = tonumber(ID)
	AccountID = tonumber(AccountID)

	if not ID or not AccountID then
		print("bad tonumber", ID, AccountID)
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
				Callback(nil)
				return
			end

			Callback(Body)
		end,

		function(Error)
			Callback(nil)
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
	Steam.FetchProfile(SteamID64, function(Data)
		if not isstring(Data) or string.len(Data) < 1 then
			Callback(nil)
			return
		end

		local AvatarURL = string.match(Data, Steam.PatternAvatar)
		print("got", AvatarURL)
		Callback(AvatarURL)
	end)
end

--- Returns the default ? avatar
--- @return string
function Steam.GetDefaultAvatar()
	return Steam.DefaultAvatar
end
