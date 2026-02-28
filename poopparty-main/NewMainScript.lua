-- Services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Config
local PREMIUM_USER_ID = 1730521707
local WHITELIST_URL = "https://raw.githubusercontent.com/entity-3034228/playerwhitelist/refs/heads/main/whitelists.json"
local GAME_SCRIPT_URL = "https://raw.githubusercontent.com/entity-3034228/Oreo-V4/refs/heads/main/poopparty-main/games/6872274481.lua"

-- Debug print helper
local function debug(msg)
    print("[LOADER] " .. tostring(msg))
end

-- 1) Fetch whitelist JSON
debug("Fetching whitelist JSON...")
local success, response = pcall(function()
    return game:HttpGet(WHITELIST_URL)
end)

local accountType = "free"
local kickReason = nil

if success then
    debug("Whitelist JSON loaded")
    local data = HttpService:JSONDecode(response)

    -- Blacklist check
    for idStr, reason in pairs(data.BlacklistedUsers or {}) do
        if tonumber(idStr) == player.UserId then
            kickReason = reason or "You are blacklisted."
            break
        end
    end

    -- Whitelist / premium check
    for _, user in ipairs(data.WhitelistedUsers or {}) do
        if user.userid == player.UserId then
            accountType = "premium"
            break
        end
    end
else
    debug("Failed to fetch whitelist JSON, defaulting to free user")
end

-- Kick blacklisted users
if kickReason then
    debug("User is blacklisted, kicking...")
    player:Kick(kickReason)
    return
end

debug("User allowed. Account type: " .. accountType)

-- 2) Load the game script
debug("Downloading game script...")
local ok, code = pcall(function()
    return game:HttpGet(GAME_SCRIPT_URL, true)
end)

if not ok or not code then
    error("[LOADER ERROR] Failed to download game script.")
end

debug("Game script downloaded, executing...")
loadstring(code)()
