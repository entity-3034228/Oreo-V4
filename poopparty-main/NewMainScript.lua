-- Services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Configuration
local PREMIUM_USER_ID = 1730521707
local WHITELIST_URL = "https://raw.githubusercontent.com/entity-3034228/playerwhitelist/refs/heads/main/whitelists.json"
local REPO_BASE = "https://raw.githubusercontent.com/entity-3034228/Oreo-V4/main/poopparty-main/"

-- Debug helper
local function debug(msg)
    print("[LOADER] " .. tostring(msg))
end

-- 1️⃣ Fetch whitelist JSON
debug("Fetching whitelist JSON...")
local success, response = pcall(function()
    return game:HttpGet(WHITELIST_URL)
end)

local accountType = "free"
local kickReason = nil

if success then
    debug("Whitelist loaded")
    local data = HttpService:JSONDecode(response)

    -- Blacklist
    for idStr, reason in pairs(data.BlacklistedUsers or {}) do
        if tonumber(idStr) == player.UserId then
            kickReason = reason or "You are blacklisted."
            break
        end
    end

    -- Premium check
    for _, user in ipairs(data.WhitelistedUsers or {}) do
        if user.userid == player.UserId then
            accountType = "premium"
            break
        end
    end
else
    debug("Failed to fetch whitelist, defaulting to free")
end

-- Kick blacklisted users
if kickReason then
    debug("User is blacklisted, kicking...")
    player:Kick(kickReason)
    return
end

debug("User allowed. Account type: " .. accountType)
_G.AccountType = accountType -- global variable for scripts

-- 2️⃣ Helper to load a module
local function loadModule(path)
    local url = REPO_BASE .. path
    local ok, code = pcall(function()
        return game:HttpGet(url, true)
    end)
    if ok and code then
        local success, err = pcall(loadstring(code))
        if not success then
            warn("[LOADER] Error running module:", path, err)
        else
            debug("Loaded module: " .. path)
        end
    else
        warn("[LOADER] Failed to download module: " .. path)
    end
end

-- 3️⃣ Load all core modules (libraries, assets, GUIs)
local coreModules = {
    "libraries/init.lua",
    "assets/init.lua",
    "guis/init.lua"
}

for _, mod in ipairs(coreModules) do
    loadModule(mod)
end

-- 4️⃣ Load all game scripts
local gameModules = {
    "games/6872274481.lua"
    -- add more game scripts here if needed
}

for _, gameMod in ipairs(gameModules) do
    loadModule(gameMod)
end

debug("All modules loaded successfully!")
