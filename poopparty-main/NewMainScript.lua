-- Services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

-- URLs
local WHITELIST_URL = "https://raw.githubusercontent.com/entity-3034228/playerwhitelist/refs/heads/main/whitelists.json"
local REPO_BASE = "https://raw.githubusercontent.com/entity-3034228/Oreo-V4/main/poopparty-main/"

-- Fetch whitelist/blacklist
local success, response = pcall(function()
    return game:HttpGet(WHITELIST_URL)
end)

local accountType = "free" -- default
local accountTags = {}
local kickReason = nil

if success then
    local data = HttpService:JSONDecode(response)

    -- Check blacklist
    for userIdStr, reason in pairs(data.BlacklistedUsers or {}) do
        if tonumber(userIdStr) == player.UserId then
            kickReason = reason or "You are blacklisted."
            break
        end
    end

    -- Check whitelist for premium
    for _, wuser in ipairs(data.WhitelistedUsers or {}) do
        if wuser.userid == player.UserId then
            accountType = "premium"
            accountTags = wuser.tags or {}
            break
        end
    end

else
    warn("Could not fetch whitelist JSON. Proceeding as free user.")
end

-- Kick blacklisted users
if kickReason then
    player:Kick(kickReason)
    return
end

print("Access granted! Account type:", accountType)

-- Load modules helper
local function loadModule(path)
    local url = REPO_BASE .. path
    local code = game:HttpGet(url, true)
    return loadstring(code)()
end

-- Load assets, libraries, GUIs
local assets = {
    "assets/init.lua",
    "libraries/init.lua",
    "guis/init.lua"
}

for _, modulePath in ipairs(assets) do
    pcall(function()
        loadModule(modulePath)
    end)
end

-- Load game scripts
local gameModules = {
    "games/6872274481.lua"
    -- add more game scripts here as needed
}

for _, gameScript in ipairs(gameModules) do
    pcall(function()
        loadModule(gameScript)
    end)
end

-- Run main script
pcall(function()
    loadModule("NewMainScript.lua")
end)

-- Optional: print account tags for premium users
if accountType == "premium" then
    for _, tag in ipairs(accountTags) do
        print("Premium tag:", tag.text)
    end
end
