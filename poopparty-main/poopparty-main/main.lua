repeat task.wait() until game:IsLoaded()
if shared.vape then shared.vape:Uninject() end

if identifyexecutor then
    if table.find({'Argon', 'Wave'}, ({identifyexecutor()})[1]) then
        getgenv().setthreadidentity = nil
    end
end

local KEY_SECRET = "AERO_SECRET_2025"

local function getHWID()
    local hwid = nil

    if gethwid then
        hwid = gethwid()
    elseif getexecutorname then
        local executor_name = getexecutorname()
        local unique_str = executor_name .. tostring(game:GetService("UserInputService"):GetGamepadState(Enum.UserInputType.Gamepad1))
        if syn and syn.crypt and syn.crypt.hash then
            hwid = syn.crypt.hash(unique_str)
        elseif crypt and crypt.hash then
            hwid = crypt.hash(unique_str)
        else
            hwid = game:GetService("HttpService"):GenerateGUID(false)
        end
    end

    if not hwid and game:GetService("RbxAnalyticsService") then
        local success, result = pcall(function()
            return game:GetService("RbxAnalyticsService"):GetClientId()
        end)
        if success and result then
            hwid = result
        end
    end

    if not hwid then
        hwid = tostring(math.random(100000, 999999)) .. tostring(os.time())
    end

    return hwid
end

local function hwidToHash(hwid)
    local hash = ""
    for i = 1, #hwid do
        hash = hash .. string.format("%02x", string.byte(hwid, i))
    end
    return hash:sub(1, 16)
end

local function buildSignature(session, hwidHash, ts)
    local base = session .. hwidHash .. tostring(ts) .. KEY_SECRET
    local sig = ""
    for i = 1, #base do
        sig = sig .. string.format("%x", string.byte(base, i) % 16)
    end
    return sig:sub(1, 12)
end

local function validateSecurity()
    local HttpService = game:GetService("HttpService")

    if isfile('newvape/security/validated') then
        local validationContent = readfile('newvape/security/validated')
        local success, validationData = pcall(function()
            return HttpService:JSONDecode(validationContent)
        end)

        if success and validationData and validationData.account_type == "premium" then
            if not validationData.username or not validationData.hwid then
                return false, nil, nil
            end

            local currentHWID = getHWID()
            if validationData.hwid ~= currentHWID then
                return false, nil, nil
            end

            local ACCOUNT_SYSTEM_URL = "https://raw.githubusercontent.com/poopparty/whitelistcheck/main/AccountSystem.lua"

            local function fetchAccounts()
                local s, r = pcall(function() return game:HttpGet(ACCOUNT_SYSTEM_URL) end)
                if s and r then
                    local accountsTable = loadstring(r)()
                    if accountsTable and accountsTable.Accounts then
                        return accountsTable.Accounts
                    end
                end
                return nil
            end

            local accounts = fetchAccounts()
            if not accounts then return false, nil, nil end

            local accountValid = false
            local accountActive = false
            local accountHWID = nil

            for _, account in pairs(accounts) do
                if account.Username == validationData.username then
                    accountValid = true
                    accountActive = account.IsActive == true
                    accountHWID = account.HWID
                    break
                end
            end

            if not accountValid or not accountActive then return false, nil, nil end
            if accountHWID and currentHWID ~= accountHWID then return false, nil, nil end

            return true, validationData.username, "premium"
        end
    end

    if isfile('newvape/security/freekey.txt') then
        local keyContent = readfile('newvape/security/freekey.txt')
        local success, keyData = pcall(function()
            return HttpService:JSONDecode(keyContent)
        end)

        if success and keyData then
            local currentHWID = getHWID()
            if keyData.hwid ~= currentHWID then return false, nil, nil end
            if os.time() > keyData.expiry then return false, nil, nil end
            return true, "free user", "free"
        end
    end

    return false, nil, nil
end

local securityPassed, validatedUsername, accountType = validateSecurity()
if not securityPassed then return end

shared.ValidatedUsername = validatedUsername
shared.VapeAccountType = accountType

local vape
local loadstring = function(...)
    local res, err = loadstring(...)
    if err and vape then
        vape:CreateNotification('vape', 'failed to load: ' .. err, 30, 'alert')
    end
    return res
end
local queue_on_teleport = queue_on_teleport or function() end
local isfile = isfile or function(file)
    local suc, res = pcall(function() return readfile(file) end)
    return suc and res ~= nil and res ~= ''
end
local cloneref = cloneref or function(obj) return obj end
local playersService = cloneref(game:GetService('Players'))

local BEDWARS_PLACE_IDS = {
    [6872274481] = true,
    [8444591321] = true,
    [6872265039] = true
}

local function downloadFile(path, func)
    if not isfile(path) then
        local suc, res = pcall(function()
            return game:HttpGet('https://raw.githubusercontent.com/poopparty/poopparty/' .. readfile('newvape/profiles/commit.txt') .. '/' .. select(1, path:gsub('newvape/', '')), true)
        end)
        if not suc or res == '404: Not Found' then error(res) end
        if path:find('.lua') then
            res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n' .. res
        end
        writefile(path, res)
    end
    return (func or readfile)(path)
end

local function downloadPremadeProfiles()
    local httpService = game:GetService('HttpService')
    if not isfolder('newvape/profiles/premade') then makefolder('newvape/profiles/premade') end

    local commit = 'main'
    if isfile('newvape/profiles/commit.txt') then commit = readfile('newvape/profiles/commit.txt') end

    local success, response = pcall(function()
        return game:HttpGet('https://api.github.com/repos/poopparty/poopparty/contents/profiles/premade?ref=' .. commit)
    end)

    if success and response then
        local ok, files = pcall(function() return httpService:JSONDecode(response) end)
        if ok and type(files) == 'table' then
            for _, file in pairs(files) do
                if file.name and file.name:find('.txt') and file.name ~= 'commit.txt' then
                    local filePath = 'newvape/profiles/premade/' .. file.name
                    if not isfile(filePath) then
                        local dl = file.download_url or ('https://raw.githubusercontent.com/poopparty/poopparty/' .. commit .. '/profiles/premade/' .. file.name)
                        local ds, dc = pcall(function() return game:HttpGet(dl, true) end)
                        if ds and dc and dc ~= '404: Not Found' then writefile(filePath, dc) end
                    end
                end
            end
        end
    end
end

local function finishLoading()
    vape.Init = nil
    vape:Load()
    task.spawn(function()
        repeat
            vape:Save()
            task.wait(10)
        until not vape.Loaded
    end)

    local teleportedServers
    vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
        if (not teleportedServers) and (not shared.VapeIndependent) then
            teleportedServers = true
            local teleportScript = [[
                shared.vapereload = true
                if shared.VapeDeveloper then
                    loadstring(readfile('newvape/loader.lua'), 'loader')()
                else
                    loadstring(game:HttpGet('https://raw.githubusercontent.com/poopparty/poopparty/'..readfile('newvape/profiles/commit.txt')..'/loader.lua', true), 'loader')()
                end
            ]]
            if shared.VapeDeveloper then
                teleportScript = 'shared.VapeDeveloper = true\n' .. teleportScript
            end
            if shared.VapeCustomProfile then
                teleportScript = 'shared.VapeCustomProfile = "' .. shared.VapeCustomProfile .. '"\n' .. teleportScript
            end
            vape:Save()
            queue_on_teleport(teleportScript)
        end
    end))

    if not shared.vapereload then
        if not vape.Categories then return end
        if vape.Categories.Main.Options['GUI bind indicator'].Enabled then
            local greeting
            if accountType == "premium" then
                greeting = 'what up, ' .. shared.ValidatedUsername .. '! ' .. (vape.VapeButton and 'press the button in the top right to open gui' or 'press ' .. table.concat(vape.Keybind, ' + '):upper() .. ' to open gui')
            else
                greeting = 'loaded free version! ' .. (vape.VapeButton and 'press the button in the top right to open gui' or 'press ' .. table.concat(vape.Keybind, ' + '):upper() .. ' to open gui')
            end
            vape:CreateNotification('[AEROV4] Finished Loading', greeting, 5)
        end
    end
end

if not isfile('newvape/profiles/gui.txt') then
    writefile('newvape/profiles/gui.txt', 'new')
end
local gui = readfile('newvape/profiles/gui.txt')

if not isfolder('newvape/assets/' .. gui) then
    makefolder('newvape/assets/' .. gui)
end

downloadPremadeProfiles()

vape = loadstring(downloadFile('newvape/guis/' .. gui .. '.lua'), 'gui')()
shared.vape = vape

if not shared.VapeIndependent then
    loadstring(downloadFile('newvape/games/universal.lua'), 'universal')()

    local gameFileName = tostring(game.PlaceId) .. '.lua'

    if accountType == "free" and BEDWARS_PLACE_IDS[game.PlaceId] then
        gameFileName = 'FREE' .. tostring(game.PlaceId) .. '.lua'
    end

    if isfile('newvape/games/' .. gameFileName) then
        loadstring(readfile('newvape/games/' .. gameFileName), tostring(game.PlaceId))(...)
    else
        if not shared.VapeDeveloper then
            local suc, res = pcall(function()
                return game:HttpGet('https://raw.githubusercontent.com/poopparty/poopparty/' .. readfile('newvape/profiles/commit.txt') .. '/games/' .. gameFileName, true)
            end)
            if suc and res ~= '404: Not Found' then
                if gameFileName:find('.lua') then
                    res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n' .. res
                end
                writefile('newvape/games/' .. gameFileName, res)
                loadstring(res, tostring(game.PlaceId))(...)
            end
        end
    end

    finishLoading()
else
    vape.Init = finishLoading
    return vape
end
