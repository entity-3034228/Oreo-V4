local EXPECTED_REPO_OWNER = "poopparty"
local EXPECTED_REPO_NAME = "poopparty"
local ACCOUNT_SYSTEM_URL = "https://raw.githubusercontent.com/poopparty/whitelistcheck/main/AccountSystem.lua"
local KEY_PAGE_URL = "https://wrealaero.github.io/vape-keys/"
local KEY_SECRET = "AERO_SECRET_2025"

if not shared.VapeLoaded then
    shared.VapeLoaded = true
else
    return
end

game:GetService("Players").LocalPlayer.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Started then
        shared.VapeLoaded = nil 
    end
end)

local function createNotification(title, text, duration)
    duration = duration or 3
    pcall(function()
        game.StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration
        })
    end)
end

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

local function validateKey(inputKey, hwid)
    if not inputKey or inputKey == "" then
        return false, "empty key bro"
    end

    if not inputKey:match("^AEROV4_") then
        return false, "wrong format. needs to start with AEROV4_"
    end

    local parts = {}
    for part in inputKey:gmatch("[^_]+") do
        table.insert(parts, part)
    end

    if #parts ~= 5 then
        return false, "key is missing parts or corrupted"
    end

    local prefix = parts[1]
    local session = parts[2]
    local keyHwidHash = parts[3]
    local keyTimestamp = tonumber(parts[4])
    local keySignature = parts[5]

    if prefix ~= "AEROV4" then
        return false, "wrong key prefix"
    end

    if not session or #session ~= 8 then
        return false, "session code invalid"
    end

    if not keyTimestamp then
        return false, "timestamp messed up"
    end

    local currentTime = os.time()
    local keyAge = currentTime - keyTimestamp
    local maxAge = 8 * 60 * 60

    if keyAge < 0 then
        return false, "timestamp is in the future wtf"
    end

    if keyAge > maxAge then
        return false, "key expired. go get a new one"
    end

    local currentHwidHash = hwidToHash(hwid)
    if keyHwidHash ~= currentHwidHash then
        return false, "this key ain't for ur device"
    end

    local expectedSig = buildSignature(session, keyHwidHash, keyTimestamp)
    if keySignature ~= expectedSig then
        return false, "key signature invalid. might be fake or tampered"
    end

    return true, "valid"
end

local function clearSecurityFolder()
    if not isfolder('newvape/security') then
        makefolder('newvape/security')
        return
    end
    local files = listfiles('newvape/security')
    for _, file in pairs(files) do
        if isfile(file) then
            delfile(file)
        end
    end
end

local function createValidationFile(username, hwid, accountType)
    if not isfolder('newvape/security') then
        makefolder('newvape/security')
    end

    if accountType == "premium" then
        local validationData = {
            username = username,
            hwid = hwid,
            timestamp = os.time(),
            account_type = "premium"
        }
        local encoded = game:GetService("HttpService"):JSONEncode(validationData)
        writefile('newvape/security/validated', encoded)
    else
        local keyData = {
            hwid = hwid,
            expiry = os.time() + (8 * 60 * 60),
            created = os.time()
        }
        local encoded = game:GetService("HttpService"):JSONEncode(keyData)
        writefile('newvape/security/freekey.txt', encoded)
    end
end

local function checkExistingValidation()
    if isfile('newvape/security/validated') then
        local validationContent = readfile('newvape/security/validated')
        local success, validationData = pcall(function()
            return game:GetService("HttpService"):JSONDecode(validationContent)
        end)
        if success and validationData and validationData.account_type == "premium" then
            local currentHWID = getHWID()
            if validationData.hwid == currentHWID then
                return true, validationData.username, "premium"
            end
        end
    end

    if isfile('newvape/security/freekey.txt') then
        local keyContent = readfile('newvape/security/freekey.txt')
        local success, keyData = pcall(function()
            return game:GetService("HttpService"):JSONDecode(keyContent)
        end)
        if success and keyData then
            local currentHWID = getHWID()
            if keyData.hwid == currentHWID then
                if os.time() <= keyData.expiry then
                    return true, "free user", "free"
                end
            end
        end
    end

    return false, nil, nil
end

local function fetchAccounts()
    local success, response = pcall(function()
        return game:HttpGet(ACCOUNT_SYSTEM_URL)
    end)
    if success and response then
        local accountsTable = loadstring(response)()
        if accountsTable and accountsTable.Accounts then
            return accountsTable.Accounts
        end
    end
    return nil
end

local function SecurityCheck(loginData)
    if not loginData or type(loginData) ~= "table" then
        createNotification("error", "wrong loadstring bro. dm aero", 3)
        return false
    end

    local inputUsername = loginData.Username
    local inputPassword = loginData.Password

    if not inputUsername or not inputPassword then
        createNotification("error", "missing credentials bro wtf. dm aero", 3)
        return false
    end

    clearSecurityFolder()

    local currentHWID = getHWID()
    local accounts = fetchAccounts()

    if not accounts then
        createNotification("error", "couldn't fetch accounts. check ur wifi it might be ass. dm aero", 3)
        return false
    end

    local accountFound = false
    local correctPassword = false
    local accountActive = false
    local accountHWID = nil

    for _, account in pairs(accounts) do
        if account.Username == inputUsername then
            accountFound = true
            if account.Password == inputPassword then
                correctPassword = true
                accountActive = account.IsActive == true
                accountHWID = account.HWID
            end
            break
        end
    end

    if not accountFound then
        createNotification("access denied", "username not found. dm 5qvx for access", 3)
        return false
    end

    if not correctPassword then
        createNotification("access denied", "wrong password for " .. inputUsername, 3)
        return false
    end

    if not accountActive then
        createNotification("account inactive", "ur account is currently inactive", 3)
        return false
    end

    if not accountHWID or accountHWID == "" or accountHWID:find("hwid%-here") then
        createNotification("no hwid set", "ur account has no hwid set. dm aero to get it set up", 10)
        return false
    end

    if currentHWID ~= accountHWID then
        createNotification("hwid mismatch", "this device isn't authorized for this account", 5)
        return false
    end

    createValidationFile(inputUsername, currentHWID, "premium")
    return true
end

local UserInputService = game:GetService("UserInputService")

local function showKeyUI()
    local hasClipboard = setclipboard ~= nil

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AeroKeySystem"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = true
    local success = pcall(function()
        screenGui.Parent = game.CoreGui
    end)
    if not success then
        screenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    end

    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    local frameWidth = isMobile and 340 or 420
    local frameHeight = isMobile and 280 or 240

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, frameWidth, 0, frameHeight)
    mainFrame.Position = UDim2.new(0.5, -frameWidth/2, 0.5, -frameHeight/2)
    mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 27)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Parent = screenGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 12)
    mainCorner.Parent = mainFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(138, 43, 226)
    mainStroke.Transparency = 0.7
    mainStroke.Thickness = 1
    mainStroke.Parent = mainFrame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 0, 24)
    title.Position = UDim2.new(0, 20, 0, 16)
    title.BackgroundTransparency = 1
    title.Text = "aerov4"
    title.TextColor3 = Color3.fromRGB(168, 85, 247)
    title.TextSize = isMobile and 20 or 18
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = mainFrame

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -40, 0, 16)
    subtitle.Position = UDim2.new(0, 20, 0, 40)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "free key system"
    subtitle.TextColor3 = Color3.fromRGB(120, 120, 140)
    subtitle.TextSize = isMobile and 12 or 11
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = mainFrame

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, isMobile and 36 or 28, 0, isMobile and 36 or 28)
    closeBtn.Position = UDim2.new(1, isMobile and -44 or -36, 0, 12)
    closeBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    closeBtn.Text = "x"
    closeBtn.TextColor3 = Color3.fromRGB(200, 200, 220)
    closeBtn.TextSize = isMobile and 24 or 20
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = mainFrame

    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 6)
    closeBtnCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        createNotification("key system", "u closed it. run the script again if u need to", 3)
        screenGui:Destroy()
    end)

    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, -40, 1, -75)
    contentFrame.Position = UDim2.new(0, 20, 0, 65)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = mainFrame

    local inputLabel = Instance.new("TextLabel")
    inputLabel.Size = UDim2.new(1, 0, 0, 16)
    inputLabel.BackgroundTransparency = 1
    inputLabel.Text = "paste ur key here"
    inputLabel.TextColor3 = Color3.fromRGB(168, 85, 247)
    inputLabel.TextSize = isMobile and 12 or 11
    inputLabel.Font = Enum.Font.GothamBold
    inputLabel.TextXAlignment = Enum.TextXAlignment.Left
    inputLabel.Parent = contentFrame

    local inputBox = Instance.new("TextBox")
    inputBox.Size = UDim2.new(1, 0, 0, isMobile and 48 or 42)
    inputBox.Position = UDim2.new(0, 0, 0, 24)
    inputBox.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    inputBox.PlaceholderText = "AEROV4_..."
    inputBox.PlaceholderColor3 = Color3.fromRGB(80, 80, 100)
    inputBox.Text = ""
    inputBox.TextColor3 = Color3.fromRGB(200, 200, 220)
    inputBox.TextSize = isMobile and 13 or 12
    inputBox.Font = Enum.Font.Code
    inputBox.ClearTextOnFocus = false
    inputBox.TextWrapped = true
    inputBox.MultiLine = true
    inputBox.Parent = contentFrame

    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 8)
    inputCorner.Parent = inputBox

    local inputPadding = Instance.new("UIPadding")
    inputPadding.PaddingLeft = UDim.new(0, 12)
    inputPadding.PaddingRight = UDim.new(0, 12)
    inputPadding.PaddingTop = UDim.new(0, 10)
    inputPadding.PaddingBottom = UDim.new(0, 10)
    inputPadding.Parent = inputBox

    local inputStroke = Instance.new("UIStroke")
    inputStroke.Color = Color3.fromRGB(138, 43, 226)
    inputStroke.Transparency = 0.7
    inputStroke.Thickness = 1
    inputStroke.Parent = inputBox

    local activateBtn = Instance.new("TextButton")
    activateBtn.Size = UDim2.new(1, 0, 0, isMobile and 48 or 42)
    activateBtn.Position = UDim2.new(0, 0, 0, isMobile and 82 or 76)
    activateBtn.BackgroundColor3 = Color3.fromRGB(100, 80, 200)
    activateBtn.Text = "activate key"
    activateBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    activateBtn.TextSize = isMobile and 14 or 13
    activateBtn.Font = Enum.Font.GothamBold
    activateBtn.Parent = contentFrame

    local activateCorner = Instance.new("UICorner")
    activateCorner.CornerRadius = UDim.new(0, 8)
    activateCorner.Parent = activateBtn

    local getKeyBtn = Instance.new("TextButton")
    getKeyBtn.Size = UDim2.new(1, 0, 0, isMobile and 40 or 32)
    getKeyBtn.Position = UDim2.new(0, 0, 1, isMobile and -40 or -32)
    getKeyBtn.BackgroundTransparency = 1
    getKeyBtn.Text = hasClipboard and "get key (tap to copy link)" or "get key"
    getKeyBtn.TextColor3 = Color3.fromRGB(168, 85, 247)
    getKeyBtn.TextSize = isMobile and 13 or 12
    getKeyBtn.Font = Enum.Font.GothamBold
    getKeyBtn.Parent = contentFrame

    local dragging = false
    local dragInput, dragStart, startPos

    local function updateInput(input)
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end

    mainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    mainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            updateInput(input)
        end
    end)

    if isMobile then
        mainFrame.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch and dragging then
                updateInput(input)
            end
        end)
    end

    getKeyBtn.MouseButton1Click:Connect(function()
        if hasClipboard then
            local success = pcall(function()
                setclipboard(KEY_PAGE_URL)
            end)
            if success then
                createNotification("copied!", "link copied to clipboard. paste it in ur browser to get a key", 5)
            else
                createNotification("clipboard failed", "couldn't copy. go to: " .. KEY_PAGE_URL, 7)
            end
        else
            createNotification("get key", "go to: " .. KEY_PAGE_URL, 10)
        end
    end)

    activateBtn.MouseButton1Click:Connect(function()
        local key = inputBox.Text:gsub("^%s*(.-)%s*$", "%1")

        if key == "" then
            createNotification("empty key", "bro paste ur key first", 3)
            return
        end

        activateBtn.Text = "checking..."
        activateBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)

        task.wait(0.3)

        local currentHWID = getHWID()
        local valid, reason = validateKey(key, currentHWID)

        if valid then
            createNotification("key accepted!", "loading aerov4...", 3)
            createValidationFile("free user", currentHWID, "free")

            task.wait(0.5)
            screenGui:Destroy()

            local isfile = isfile or function(file)
                local suc, res = pcall(function() return readfile(file) end)
                return suc and res ~= nil and res ~= ''
            end

            local delfile = delfile or function(file) writefile(file, '') end

            local function downloadFile(path, func)
                if not isfile(path) then
                    local suc, res = pcall(function()
                        return game:HttpGet('https://raw.githubusercontent.com/' .. EXPECTED_REPO_OWNER .. '/' .. EXPECTED_REPO_NAME .. '/' .. readfile('newvape/profiles/commit.txt') .. '/' .. select(1, path:gsub('newvape/', '')), true)
                    end)
                    if not suc or res == '404: Not Found' then error(res) end
                    if path:find('.lua') then
                        res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n' .. res
                    end
                    writefile(path, res)
                end
                return (func or readfile)(path)
            end

            local function wipeFolder(path)
                if not isfolder(path) then return end
                for _, file in listfiles(path) do
                    if file:find('loader') then continue end
                    if isfile(file) and select(1, readfile(file):find('--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.')) == 1 then
                        delfile(file)
                    end
                end
            end

            local function downloadPremadeProfiles(commit)
                local httpService = game:GetService('HttpService')
                if not isfolder('newvape/profiles/premade') then makefolder('newvape/profiles/premade') end
                local success, response = pcall(function()
                    return game:HttpGet('https://api.github.com/repos/' .. EXPECTED_REPO_OWNER .. '/' .. EXPECTED_REPO_NAME .. '/contents/profiles/premade?ref=' .. commit)
                end)
                if success and response then
                    local ok, files = pcall(function() return httpService:JSONDecode(response) end)
                    if ok and type(files) == 'table' then
                        for _, file in pairs(files) do
                            if file.name and file.name:find('.txt') and file.name ~= 'commit.txt' then
                                local filePath = 'newvape/profiles/premade/' .. file.name
                                if not isfile(filePath) then
                                    local dl = file.download_url or ('https://raw.githubusercontent.com/' .. EXPECTED_REPO_OWNER .. '/' .. EXPECTED_REPO_NAME .. '/' .. commit .. '/profiles/premade/' .. file.name)
                                    local ds, dc = pcall(function() return game:HttpGet(dl, true) end)
                                    if ds and dc and dc ~= '404: Not Found' then writefile(filePath, dc) end
                                end
                            end
                        end
                    end
                end
            end

            for _, folder in {'newvape', 'newvape/games', 'newvape/profiles', 'newvape/profiles/premade', 'newvape/assets', 'newvape/libraries', 'newvape/guis', 'newvape/security'} do
                if not isfolder(folder) then makefolder(folder) end
            end

            if not shared.VapeDeveloper then
                local _, subbed = pcall(function() return game:HttpGet('https://github.com/' .. EXPECTED_REPO_OWNER .. '/' .. EXPECTED_REPO_NAME) end)
                local commit = subbed:find('currentOid')
                commit = commit and subbed:sub(commit + 13, commit + 52) or nil
                commit = commit and #commit == 40 and commit or 'main'

                local needsUpdate = commit == 'main' or (isfile('newvape/profiles/commit.txt') and readfile('newvape/profiles/commit.txt') or '') ~= commit
                if needsUpdate then
                    wipeFolder('newvape')
                    wipeFolder('newvape/games')
                    wipeFolder('newvape/guis')
                    wipeFolder('newvape/libraries')
                end

                downloadPremadeProfiles(commit)
                writefile('newvape/profiles/commit.txt', commit)
            end

            shared.ValidatedUsername = "free user"
            shared.VapeAccountType = "free"

            return loadstring(downloadFile('newvape/main.lua'), 'main')()
        else
            activateBtn.Text = "activate key"
            activateBtn.BackgroundColor3 = Color3.fromRGB(100, 80, 200)
            createNotification("invalid key", reason, 5)
        end
    end)

    task.wait(0.5)
    createNotification("key system", "tap 'get key' to copy the link. paste in browser to get ur key", 7)
end

local passedArgs = {}
local rawArgs = ...
if type(rawArgs) == "table" then
    passedArgs = rawArgs
end

local isPremiumLogin = type(passedArgs.Username) == "string" and #passedArgs.Username > 0
                    and type(passedArgs.Password) == "string" and #passedArgs.Password > 0

if isPremiumLogin then
    local success = SecurityCheck(passedArgs)
    if not success then return end

    local isfile = isfile or function(file)
        local suc, res = pcall(function() return readfile(file) end)
        return suc and res ~= nil and res ~= ''
    end
    local delfile = delfile or function(file) writefile(file, '') end

    local function downloadFile(path, func)
        if not isfile(path) then
            local suc, res = pcall(function()
                return game:HttpGet('https://raw.githubusercontent.com/' .. EXPECTED_REPO_OWNER .. '/' .. EXPECTED_REPO_NAME .. '/' .. readfile('newvape/profiles/commit.txt') .. '/' .. select(1, path:gsub('newvape/', '')), true)
            end)
            if not suc or res == '404: Not Found' then error(res) end
            if path:find('.lua') then
                res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n' .. res
            end
            writefile(path, res)
        end
        return (func or readfile)(path)
    end

    local function wipeFolder(path)
        if not isfolder(path) then return end
        for _, file in listfiles(path) do
            if file:find('loader') then continue end
            if isfile(file) and select(1, readfile(file):find('--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.')) == 1 then
                delfile(file)
            end
        end
    end

    local function downloadPremadeProfiles(commit)
        local httpService = game:GetService('HttpService')
        if not isfolder('newvape/profiles/premade') then makefolder('newvape/profiles/premade') end
        local success, response = pcall(function()
            return game:HttpGet('https://api.github.com/repos/' .. EXPECTED_REPO_OWNER .. '/' .. EXPECTED_REPO_NAME .. '/contents/profiles/premade?ref=' .. commit)
        end)
        if success and response then
            local ok, files = pcall(function() return httpService:JSONDecode(response) end)
            if ok and type(files) == 'table' then
                for _, file in pairs(files) do
                    if file.name and file.name:find('.txt') and file.name ~= 'commit.txt' then
                        local filePath = 'newvape/profiles/premade/' .. file.name
                        if not isfile(filePath) then
                            local dl = file.download_url or ('https://raw.githubusercontent.com/' .. EXPECTED_REPO_OWNER .. '/' .. EXPECTED_REPO_NAME .. '/' .. commit .. '/profiles/premade/' .. file.name)
                            local ds, dc = pcall(function() return game:HttpGet(dl, true) end)
                            if ds and dc and dc ~= '404: Not Found' then writefile(filePath, dc) end
                        end
                    end
                end
            end
        else
            for _, profileName in ipairs({'aero6872274481.txt', 'aero6872265039.txt'}) do
                local filePath = 'newvape/profiles/premade/' .. profileName
                if not isfile(filePath) then
                    local ds, dc = pcall(function() return game:HttpGet('https://raw.githubusercontent.com/' .. EXPECTED_REPO_OWNER .. '/' .. EXPECTED_REPO_NAME .. '/' .. commit .. '/profiles/premade/' .. profileName, true) end)
                    if ds and dc ~= '404: Not Found' then writefile(filePath, dc) end
                end
            end
        end
    end

    for _, folder in {'newvape', 'newvape/games', 'newvape/profiles', 'newvape/profiles/premade', 'newvape/assets', 'newvape/libraries', 'newvape/guis', 'newvape/security'} do
        if not isfolder(folder) then makefolder(folder) end
    end

    if not shared.VapeDeveloper then
        local _, subbed = pcall(function() return game:HttpGet('https://github.com/' .. EXPECTED_REPO_OWNER .. '/' .. EXPECTED_REPO_NAME) end)
        local commit = subbed:find('currentOid')
        commit = commit and subbed:sub(commit + 13, commit + 52) or nil
        commit = commit and #commit == 40 and commit or 'main'

        local needsUpdate = commit == 'main' or (isfile('newvape/profiles/commit.txt') and readfile('newvape/profiles/commit.txt') or '') ~= commit
        if needsUpdate then
            wipeFolder('newvape')
            wipeFolder('newvape/games')
            wipeFolder('newvape/guis')
            wipeFolder('newvape/libraries')
        end

        downloadPremadeProfiles(commit)
        writefile('newvape/profiles/commit.txt', commit)
    end

    shared.ValidatedUsername = passedArgs.Username
    shared.VapeAccountType = "premium"
    return loadstring(downloadFile('newvape/main.lua'), 'main')()
end

local hasValidation, validatedUsername, accountType = checkExistingValidation()
if hasValidation then
    shared.ValidatedUsername = validatedUsername
    shared.VapeAccountType = accountType

    local isfile = isfile or function(file)
        local suc, res = pcall(function() return readfile(file) end)
        return suc and res ~= nil and res ~= ''
    end
    local delfile = delfile or function(file) writefile(file, '') end

    local function downloadFile(path, func)
        if not isfile(path) then
            local suc, res = pcall(function()
                return game:HttpGet('https://raw.githubusercontent.com/' .. EXPECTED_REPO_OWNER .. '/' .. EXPECTED_REPO_NAME .. '/' .. readfile('newvape/profiles/commit.txt') .. '/' .. select(1, path:gsub('newvape/', '')), true)
            end)
            if not suc or res == '404: Not Found' then error(res) end
            if path:find('.lua') then
                res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n' .. res
            end
            writefile(path, res)
        end
        return (func or readfile)(path)
    end

    local function wipeFolder(path)
        if not isfolder(path) then return end
        for _, file in listfiles(path) do
            if file:find('loader') then continue end
            if isfile(file) and select(1, readfile(file):find('--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.')) == 1 then
                delfile(file)
            end
        end
    end

    local function downloadPremadeProfiles(commit)
        local httpService = game:GetService('HttpService')
        if not isfolder('newvape/profiles/premade') then makefolder('newvape/profiles/premade') end
        local success, response = pcall(function()
            return game:HttpGet('https://api.github.com/repos/' .. EXPECTED_REPO_OWNER .. '/' .. EXPECTED_REPO_NAME .. '/contents/profiles/premade?ref=' .. commit)
        end)
        if success and response then
            local ok, files = pcall(function() return httpService:JSONDecode(response) end)
            if ok and type(files) == 'table' then
                for _, file in pairs(files) do
                    if file.name and file.name:find('.txt') and file.name ~= 'commit.txt' then
                        local filePath = 'newvape/profiles/premade/' .. file.name
                        if not isfile(filePath) then
                            local dl = file.download_url or ('https://raw.githubusercontent.com/' .. EXPECTED_REPO_OWNER .. '/' .. EXPECTED_REPO_NAME .. '/' .. commit .. '/profiles/premade/' .. file.name)
                            local ds, dc = pcall(function() return game:HttpGet(dl, true) end)
                            if ds and dc and dc ~= '404: Not Found' then writefile(filePath, dc) end
                        end
                    end
                end
            end
        else
            for _, profileName in ipairs({'aero6872274481.txt', 'aero6872265039.txt'}) do
                local filePath = 'newvape/profiles/premade/' .. profileName
                if not isfile(filePath) then
                    local ds, dc = pcall(function() return game:HttpGet('https://raw.githubusercontent.com/' .. EXPECTED_REPO_OWNER .. '/' .. EXPECTED_REPO_NAME .. '/' .. commit .. '/profiles/premade/' .. profileName, true) end)
                    if ds and dc ~= '404: Not Found' then writefile(filePath, dc) end
                end
            end
        end
    end

    for _, folder in {'newvape', 'newvape/games', 'newvape/profiles', 'newvape/profiles/premade', 'newvape/assets', 'newvape/libraries', 'newvape/guis', 'newvape/security'} do
        if not isfolder(folder) then makefolder(folder) end
    end

    if not shared.VapeDeveloper then
        local _, subbed = pcall(function() return game:HttpGet('https://github.com/' .. EXPECTED_REPO_OWNER .. '/' .. EXPECTED_REPO_NAME) end)
        local commit = subbed:find('currentOid')
        commit = commit and subbed:sub(commit + 13, commit + 52) or nil
        commit = commit and #commit == 40 and commit or 'main'

        local needsUpdate = commit == 'main' or (isfile('newvape/profiles/commit.txt') and readfile('newvape/profiles/commit.txt') or '') ~= commit
        if needsUpdate then
            wipeFolder('newvape')
            wipeFolder('newvape/games')
            wipeFolder('newvape/guis')
            wipeFolder('newvape/libraries')
        end

        downloadPremadeProfiles(commit)
        writefile('newvape/profiles/commit.txt', commit)
    end

    return loadstring(downloadFile('newvape/main.lua'), 'main')()
end

if passedArgs.Key and type(passedArgs.Key) == "string" then
    local currentHWID = getHWID()
    local valid, reason = validateKey(passedArgs.Key, currentHWID)

    if valid then
        createNotification("key accepted!", "loading aerov4...", 3)
        createValidationFile("free user", currentHWID, "free")
        shared.ValidatedUsername = "free user"
        shared.VapeAccountType = "free"

        local isfile = isfile or function(file)
            local suc, res = pcall(function() return readfile(file) end)
            return suc and res ~= nil and res ~= ''
        end
        local delfile = delfile or function(file) writefile(file, '') end

        local function downloadFile(path, func)
            if not isfile(path) then
                local suc, res = pcall(function()
                    return game:HttpGet('https://raw.githubusercontent.com/' .. EXPECTED_REPO_OWNER .. '/' .. EXPECTED_REPO_NAME .. '/' .. readfile('newvape/profiles/commit.txt') .. '/' .. select(1, path:gsub('newvape/', '')), true)
                end)
                if not suc or res == '404: Not Found' then error(res) end
                if path:find('.lua') then
                    res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n' .. res
                end
                writefile(path, res)
            end
            return (func or readfile)(path)
        end

        local function wipeFolder(path)
            if not isfolder(path) then return end
            for _, file in listfiles(path) do
                if file:find('loader') then continue end
                if isfile(file) and select(1, readfile(file):find('--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.')) == 1 then
                    delfile(file)
                end
            end
        end

        local function downloadPremadeProfiles(commit)
            local httpService = game:GetService('HttpService')
            if not isfolder('newvape/profiles/premade') then makefolder('newvape/profiles/premade') end
            local success, response = pcall(function()
                return game:HttpGet('https://api.github.com/repos/' .. EXPECTED_REPO_OWNER .. '/' .. EXPECTED_REPO_NAME .. '/contents/profiles/premade?ref=' .. commit)
            end)
            if success and response then
                local ok, files = pcall(function() return httpService:JSONDecode(response) end)
                if ok and type(files) == 'table' then
                    for _, file in pairs(files) do
                        if file.name and file.name:find('.txt') and file.name ~= 'commit.txt' then
                            local filePath = 'newvape/profiles/premade/' .. file.name
                            if not isfile(filePath) then
                                local dl = file.download_url or ('https://raw.githubusercontent.com/' .. EXPECTED_REPO_OWNER .. '/' .. EXPECTED_REPO_NAME .. '/' .. commit .. '/profiles/premade/' .. file.name)
                                local ds, dc = pcall(function() return game:HttpGet(dl, true) end)
                                if ds and dc and dc ~= '404: Not Found' then writefile(filePath, dc) end
                            end
                        end
                    end
                end
            else
                for _, profileName in ipairs({'aero6872274481.txt', 'aero6872265039.txt'}) do
                    local filePath = 'newvape/profiles/premade/' .. profileName
                    if not isfile(filePath) then
                        local ds, dc = pcall(function() return game:HttpGet('https://raw.githubusercontent.com/' .. EXPECTED_REPO_OWNER .. '/' .. EXPECTED_REPO_NAME .. '/' .. commit .. '/profiles/premade/' .. profileName, true) end)
                        if ds and dc ~= '404: Not Found' then writefile(filePath, dc) end
                    end
                end
            end
        end

        for _, folder in {'newvape', 'newvape/games', 'newvape/profiles', 'newvape/profiles/premade', 'newvape/assets', 'newvape/libraries', 'newvape/guis', 'newvape/security'} do
            if not isfolder(folder) then makefolder(folder) end
        end

        if not shared.VapeDeveloper then
            local _, subbed = pcall(function() return game:HttpGet('https://github.com/' .. EXPECTED_REPO_OWNER .. '/' .. EXPECTED_REPO_NAME) end)
            local commit = subbed:find('currentOid')
            commit = commit and subbed:sub(commit + 13, commit + 52) or nil
            commit = commit and #commit == 40 and commit or 'main'

            local needsUpdate = commit == 'main' or (isfile('newvape/profiles/commit.txt') and readfile('newvape/profiles/commit.txt') or '') ~= commit
            if needsUpdate then
                wipeFolder('newvape')
                wipeFolder('newvape/games')
                wipeFolder('newvape/guis')
                wipeFolder('newvape/libraries')
            end

            downloadPremadeProfiles(commit)
            writefile('newvape/profiles/commit.txt', commit)
        end

        return loadstring(downloadFile('newvape/main.lua'), 'main')()
    else
        createNotification("invalid key", reason, 5)
        return
    end
end

showKeyUI()
