if SERVER then
	AddCSLuaFile()
	return
end

Steam = Steam or {}

Steam.ProfileURL = "https://steamcommunity.com/profiles/%s/"
Steam.PatternDecor = [[<div class="playerAvatarAutoSizeInner".-<img%s+src="(https://[^"]-)"%s*>%s*</div>%s*</div>]] -- Avatar decorations add extra stuff inside
Steam.PatternAvatar = [[<div class="playerAvatarAutoSizeInner".-<img%s+src="(https://[^"]-)"%s*>%s*</div>]]

--- @param SteamID64 string
--- @param Callback function
function Steam.FetchProfile(SteamID64, Callback)
	local ProfileURL = Format(Steam.ProfileURL, SteamID64)

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

		local AvatarURL = string.match(Data, Steam.PatternDecor)
		AvatarURL = AvatarURL or string.match(Data, Steam.PatternAvatar)

		Callback(AvatarURL)
	end)
end
