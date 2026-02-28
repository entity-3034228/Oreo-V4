-- Services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Configuration
local PREMIUM_USER_ID = 1730521707
local WHITELIST_URL = "https://raw.githubusercontent.com/entity-3034228/playerwhitelist/refs/heads/main/whitelists.json"
local REPO_BASE = "https://raw.githubusercontent.com/entity-3034228/Oreo-V4/main/poopparty-main/"

-- Helper function to load a remote Lua module
local function loadModule(path)
    local url = REPO_BASE .. path
    local success, code = pcall(function()
        return game:HttpGet(url, true)
    end)
    if success and code then
        return loadstring(code)()
    else
        warn("Failed to load module:", path)
    end
end

-- 1) Fetch whitelist/blacklist
local success, response = pcall(function()
    return game:HttpGet(WHITELIST_URL)
end)

local accountType = "free"
local kickReason = nil
local accountTags = {}

if success then
    local data = HttpService:JSONDecode(response)

    -- Check blacklist
    for idStr, reason in pairs(data.BlacklistedUsers or {}) do
        if tonumber(idStr) == player.UserId then
            kickReason = reason or "You are blacklisted."
            break
        end
    end

    -- Check whitelist / premium
    for _, user in ipairs(data.WhitelistedUsers or {}) do
        if user.userid == player.UserId then
            accountType = "premium"
            accountTags = user.tags or {}
            break
        end
    end
else
    warn("Could not fetch whitelist JSON. Defaulting to free user.")
end

-- Kick if blacklisted
if kickReason then
    player:Kick(kickReason)
    return
end

print("Access granted! Account type:", accountType)

-- Optional: display premium tags
if accountType == "premium" then
    for _, tag in ipairs(accountTags) do
        print("Premium tag:", tag.text)
    end
end

-- 2) Load core modules (assets, libraries, GUIs)
local coreModules = {
    "assets/init.lua",
    "libraries/init.lua",
    "guis/init.lua"
}

for _, modulePath in ipairs(coreModules) do
    pcall(function()
        loadModule(modulePath)
    end)
end

-- 3) Load all game modules
-- Add all your game scripts here
local gameModules = {
    "games/6872274481.lua"
    -- add more game scripts if needed
}

for _, gameScript in ipairs(gameModules) do
    pcall(function()
        loadModule(gameScript)
    end)
end

-- 4) Load main script last
pcall(function()
    loadModule("NewMainScript.lua")
end)
