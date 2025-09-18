--!strict

-- hack taken from here:
-- https://github.com/metatablecat/lxm/blob/main/src/zstd.lua

local HttpService = game:GetService("HttpService") :: HttpService

local Base64 = require(script.Parent.Base64)

local zstd = {}

function zstd.decompress(b: buffer): buffer
	local zbase64 = Base64.encode(b)
	return HttpService:JSONDecode(`\{"m": null, "t":"buffer", "zbase64":"{zbase64}"\}`)
end

return zstd
