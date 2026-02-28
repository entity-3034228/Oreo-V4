-- Services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Config
local PREMIUM_USER_ID = 1730521707
local WHITELIST_URL = "https://raw.githubusercontent.com/entity-3034228/playerwhitelist/refs/heads/main/whitelists.json"

-- Report where it fails
local function debugPrint(msg)
    print("[Loader Debug] " .. msg)
end

-- 1) Fetch whitelist JSON
debugPrint("Fetching whitelist JSON...")
local success, response = pcall(function()
    return game:HttpGet(WHITELIST_URL)
end)

local accountType = "free"
local kickMessage

if success then
    debugPrint("Whitelist JSON loaded")
    local data = HttpService:JSONDecode(response)

    -- Blacklist check
    for idStr, reason in pairs(data.BlacklistedUsers or {}) do
        if tonumber(idStr) == player.UserId then
            kickMessage = reason or "Blacklisted"
            break
        end
    end

    -- Whitelist (premium) check
    for _, w in ipairs(data.WhitelistedUsers or {}) do
        if w.userid == player.UserId then
            accountType = "premium"
            break
        end
    end

else
    debugPrint("Failed to fetch whitelist JSON")
end

-- Kick if blacklisted
if kickMessage then
    debugPrint("User is blacklisted, kicking...")
    player:Kick(kickMessage)
    return
end

debugPrint("User allowed, account type: " .. accountType)

-- 2) Load main script using official pattern
local baseUrl = "https://raw.githubusercontent.com/entity-3034228/Oreo-V4/main/poopparty-main/"
local mainScriptUrl = baseUrl .. "NewMainScript.lua"
debugPrint("Loading main script from: " .. mainScriptUrl)

local ok, code = pcall(function()
    return game:HttpGet(mainScriptUrl, true)
end)

if not ok or not code then
    error("Failed to download main script.")
end

debugPrint("Main script downloaded, executing...")
loadstring(code)()
