-- Services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Config
local PREMIUM_USER_ID = 1730521707
local WHITELIST_URL = "https://raw.githubusercontent.com/entity-3034228/playerwhitelist/refs/heads/main/whitelists.json"
local REPO_OWNER = "entity-3034228"
local REPO_NAME = "Oreo-V4"
local BRANCH = "main"
local BASE_PATH = "poopparty-main"

-- Debug helper
local function debug(msg)
    print("[LOADER] " .. tostring(msg))
end

-- 1️⃣ Whitelist / Blacklist
debug("Fetching whitelist JSON...")
local success, response = pcall(function()
    return game:HttpGet(WHITELIST_URL)
end)

local accountType = "free"
local kickReason = nil

if success then
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

if kickReason then
    player:Kick(kickReason)
    return
end

debug("User allowed. Account type: " .. accountType)
_G.AccountType = accountType

-- 2️⃣ GitHub API fetcher for a folder
local function fetchFolder(folderPath)
    local apiUrl = ("https://api.github.com/repos/%s/%s/contents/%s?ref=%s"):format(
        REPO_OWNER, REPO_NAME, folderPath, BRANCH
    )
    local ok, response = pcall(function()
        return game:HttpGet(apiUrl)
    end)
    if not ok then
        warn("[LOADER] Failed to fetch folder:", folderPath)
        return {}
    end
    local decoded = HttpService:JSONDecode(response)
    local luaFiles = {}
    for _, file in ipairs(decoded) do
        if file.type == "file" and file.name:sub(-4) == ".lua" then
            table.insert(luaFiles, file.download_url)
        end
    end
    return luaFiles
end

-- 3️⃣ Load a Lua file from URL
local function loadLua(url)
    local ok, code = pcall(function()
        return game:HttpGet(url, true)
    end)
    if ok and code then
        local success, err = pcall(loadstring(code))
        if not success then
            warn("[LOADER] Failed to execute script:", url, err)
        else
            debug("Loaded script: " .. url)
        end
    else
        warn("[LOADER] Failed to download script:", url)
    end
end

-- 4️⃣ Folders to auto-load (except GUIs)
local folders = {"assets", "games", "libraries", "src", "profiles/premade"}

for _, folder in ipairs(folders) do
    debug("Fetching folder: " .. folder)
    local luaFiles = fetchFolder(BASE_PATH .. "/" .. folder)
    for _, fileUrl in ipairs(luaFiles) do
        loadLua(fileUrl)
    end
end

-- 5️⃣ Load only the specific GUI script
local guiScriptUrl = ("https://raw.githubusercontent.com/%s/%s/%s/%s/guis/new.lua"):format(
    REPO_OWNER, REPO_NAME, BRANCH, BASE_PATH
)
loadLua(guiScriptUrl)

-- 6️⃣ Load individual scripts
local individualScripts = {"Anti-Crash.lua"}

for _, file in ipairs(individualScripts) do
    local url = ("https://raw.githubusercontent.com/%s/%s/%s/%s/%s"):format(
        REPO_OWNER, REPO_NAME, BRANCH, BASE_PATH, file
    )
    loadLua(url)
end

debug("All modules loaded successfully!")
