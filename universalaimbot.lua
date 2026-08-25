
## 📄 Полный скрипт для GitHub:

Вот финальная версия скрипта, который нужно загрузить на GitHub:

```lua
--[[
    Universal Aimbot v2.0.0
    GitHub: https://github.com/ваш-username/universal-aimbot
    Описание: Универсальный аимбот с ESP и системой конфигов
]]

-- Проверка на повторную загрузку
if getgenv().UniversalAimbotLoaded then
    print("⚠️ Universal Aimbot уже загружен!")
    return
end
getgenv().UniversalAimbotLoaded = true

-- Версия скрипта
local SCRIPT_VERSION = "2.0.0"
local GITHUB_RAW_URL = "https://raw.githubusercontent.com/ваш-username/universal-aimbot/main/"

-- Загрузка Rayfield
local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua'))()

-- Основные сервисы
local RunService = game:GetService("RunService")
local players = game:GetService("Players")
local workspace = game:GetService("Workspace")
local plr = players.LocalPlayer
local camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")
local mouse = plr:GetMouse()
local HttpService = game:GetService("HttpService")

--> [< Переменные >] <--

local aimbotEnabled = false
local aiming = false
local currentTarget = nil
local menuVisible = true
local scriptRunning = true
local selectedConfig = "default"

-- Настройки аимбота
local settings = {
    fov = 200,
    smoothing = 0.1,
    prediction = 0.065,
    wallCheck = false,
    stickyAim = false,
    teamCheck = false,
    healthCheck = false,
    minHealth = 0,
    aimPart = "Auto",
    fovColor = Color3.fromRGB(255, 0, 0),
    targetedColor = Color3.fromRGB(0, 255, 0),
    rainbowFov = false,
    aimMode = "Hold",
    key = "BackSlash",
    autoEnable = false,
    showFovCircle = true,
    fovThickness = 2,
    fovTransparency = 0,
    fovFilled = false,
    menuKey = "RightControl"
}

-- Настройки ESP
local espSettings = {
    enabled = false,
    boxColor = Color3.fromRGB(0, 255, 0),
    boxThickness = 2,
    transparency = 0.5,
    showName = true,
    showHealth = true,
    showDistance = true,
    showBox = true,
    nameColor = Color3.fromRGB(255, 255, 255),
    healthColor = Color3.fromRGB(255, 0, 0),
    distanceColor = Color3.fromRGB(255, 255, 255)
}

-- Части тела
local BODY_PARTS = {
    "Head", "HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso",
    "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
    "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
    "LeftHand", "RightHand", "LeftFoot", "RightFoot"
}

-- Конфиги
local CONFIG_FOLDER = "UniversalAimbot"
local CONFIGS_FOLDER = "UniversalAimbot/Configs"
local AUTOEXEC_FILE = "autoexec.json"

local hue = 0
local rainbowSpeed = 0.005
local espObjects = {}
local connections = {}

-- Создание FOV круга
local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = settings.fovThickness
fovCircle.Radius = settings.fov
fovCircle.Filled = settings.fovFilled
fovCircle.Color = settings.fovColor
fovCircle.Transparency = settings.fovTransparency / 100
fovCircle.Visible = false

--> [< Функции >] <--

-- Проверка обновлений
local function checkForUpdates()
    local success, result = pcall(function()
        local response = game:HttpGet(GITHUB_RAW_URL .. "version.txt")
        local latestVersion = string.gsub(response, "%s+", "")
        if latestVersion ~= SCRIPT_VERSION then
            print("🔄 Доступна новая версия: " .. latestVersion)
            print("📥 Текущая версия: " .. SCRIPT_VERSION)
            return true, latestVersion
        end
        print("✅ У вас последняя версия: " .. SCRIPT_VERSION)
        return false, SCRIPT_VERSION
    end)
    
    if not success then
        print("⚠️ Не удалось проверить обновления")
        return false, SCRIPT_VERSION
    end
    return success, SCRIPT_VERSION
end

-- Очистка
local function fullCleanup()
    print("🧹 Очистка...")
    
    for _, connection in ipairs(connections) do
        pcall(function() connection:Disconnect() end)
    end
    connections = {}
    
    pcall(function()
        fovCircle.Visible = false
        fovCircle:Remove()
    end)
    
    for _, esp in pairs(espObjects) do
        pcall(function()
            esp.box.Visible = false
            esp.box:Remove()
            esp.name.Visible = false
            esp.name:Remove()
            esp.health.Visible = false
            esp.health:Remove()
            esp.distance.Visible = false
            esp.distance:Remove()
            esp.healthBg.Visible = false
            esp.healthBg:Remove()
            esp.healthFill.Visible = false
            esp.healthFill:Remove()
        end)
    end
    espObjects = {}
    
    pcall(function() Window:Destroy() end)
    print("✅ Очистка завершена!")
end

-- Закрытие скрипта
local function closeScript()
    print("🔴 Закрытие Universal Aimbot...")
    scriptRunning = false
    aimbotEnabled = false
    aiming = false
    currentTarget = nil
    fullCleanup()
    getgenv().UniversalAimbotLoaded = false
    print("✅ Скрипт закрыт!")
    error("Script closed by user")
end

-- Скрыть/показать меню
local function toggleMenu()
    menuVisible = not menuVisible
    if menuVisible then
        Window:Show()
    else
        Window:Hide()
    end
end

-- Конвертация Color3
local function color3ToTable(color)
    return { R = color.R, G = color.G, B = color.B }
end

local function tableToColor3(tbl)
    if not tbl then return Color3.fromRGB(255, 255, 255) end
    return Color3.fromRGB(tbl.R * 255, tbl.G * 255, tbl.B * 255)
end

-- Сохранение конфига
local function saveConfig(name)
    if not name then name = selectedConfig end
    
    local success, result = pcall(function()
        if not isfolder(CONFIGS_FOLDER) then
            makefolder(CONFIGS_FOLDER)
        end
        
        local config = {
            name = name,
            version = SCRIPT_VERSION,
            settings = {
                fov = settings.fov,
                smoothing = settings.smoothing,
                prediction = settings.prediction,
                wallCheck = settings.wallCheck,
                stickyAim = settings.stickyAim,
                teamCheck = settings.teamCheck,
                healthCheck = settings.healthCheck,
                minHealth = settings.minHealth,
                aimPart = settings.aimPart,
                fovColor = color3ToTable(settings.fovColor),
                targetedColor = color3ToTable(settings.targetedColor),
                rainbowFov = settings.rainbowFov,
                aimMode = settings.aimMode,
                key = settings.key,
                showFovCircle = settings.showFovCircle,
                fovThickness = settings.fovThickness,
                fovTransparency = settings.fovTransparency,
                fovFilled = settings.fovFilled,
                menuKey = settings.menuKey
            },
            esp = {
                enabled = espSettings.enabled,
                boxColor = color3ToTable(espSettings.boxColor),
                boxThickness = espSettings.boxThickness,
                transparency = espSettings.transparency,
                showName = espSettings.showName,
                showHealth = espSettings.showHealth,
                showDistance = espSettings.showDistance,
                showBox = espSettings.showBox,
                nameColor = color3ToTable(espSettings.nameColor),
                healthColor = color3ToTable(espSettings.healthColor),
                distanceColor = color3ToTable(espSettings.distanceColor)
            }
        }
        
        local jsonData = HttpService:JSONEncode(config)
        writefile(CONFIGS_FOLDER .. "/" .. name .. ".json")
        print("✅ Конфиг '" .. name .. "' сохранен!")
        return true
    end)
    
    if not success then
        print("❌ Ошибка сохранения: " .. tostring(result))
        return false
    end
    return true
end

-- Загрузка конфига
local function loadConfig(name)
    if not name then name = selectedConfig end
    
    local success, result = pcall(function()
        if not isfile(CONFIGS_FOLDER .. "/" .. name .. ".json") then
            print("❌ Конфиг '" .. name .. "' не найден!")
            return false
        end
        
        local jsonData = readfile(CONFIGS_FOLDER .. "/" .. name .. ".json")
        local config = HttpService:JSONDecode(jsonData)
        
        if not config.settings then
            print("❌ Неверный формат конфига!")
            return false
        end
        
        local s = config.settings
        settings.fov = s.fov or 200
        settings.smoothing = s.smoothing or 0.1
        settings.prediction = s.prediction or 0.065
        settings.wallCheck = (s.wallCheck ~= nil) and s.wallCheck or false
        settings.stickyAim = (s.stickyAim ~= nil) and s.stickyAim or false
        settings.teamCheck = (s.teamCheck ~= nil) and s.teamCheck or false
        settings.healthCheck = (s.healthCheck ~= nil) and s.healthCheck or false
        settings.minHealth = s.minHealth or 0
        settings.aimPart = s.aimPart or "Auto"
        settings.rainbowFov = (s.rainbowFov ~= nil) and s.rainbowFov or false
        settings.aimMode = s.aimMode or "Hold"
        settings.key = s.key or "BackSlash"
        settings.showFovCircle = (s.showFovCircle ~= nil) and s.showFovCircle or true
        settings.fovThickness = s.fovThickness or 2
        settings.fovTransparency = s.fovTransparency or 0
        settings.fovFilled = (s.fovFilled ~= nil) and s.fovFilled or false
        settings.menuKey = s.menuKey or "RightControl"
        
        settings.fovColor = tableToColor3(s.fovColor)
        settings.targetedColor = tableToColor3(s.targetedColor)
        
        local e = config.esp
        if e then
            espSettings.enabled = (e.enabled ~= nil) and e.enabled or false
            espSettings.boxThickness = e.boxThickness or 2
            espSettings.transparency = e.transparency or 0.5
            espSettings.showName = (e.showName ~= nil) and e.showName or true
            espSettings.showHealth = (e.showHealth ~= nil) and e.showHealth or true
            espSettings.showDistance = (e.showDistance ~= nil) and e.showDistance or true
            espSettings.showBox = (e.showBox ~= nil) and e.showBox or true
            
            espSettings.boxColor = tableToColor3(e.boxColor)
            espSettings.nameColor = tableToColor3(e.nameColor)
            espSettings.healthColor = tableToColor3(e.healthColor)
            espSettings.distanceColor = tableToColor3(e.distanceColor)
        end
        
        fovCircle.Radius = settings.fov
        fovCircle.Color = settings.fovColor
        fovCircle.Thickness = settings.fovThickness
        fovCircle.Transparency = settings.fovTransparency / 100
        fovCircle.Filled = settings.fovFilled
        
        print("✅ Конфиг '" .. name .. "' загружен!")
        return true
    end)
    
    if not success then
        print("❌ Ошибка загрузки: " .. tostring(result))
        return false
    end
    return true
end

-- Список конфигов
local function getConfigList()
    local configs = {"default"}
    pcall(function()
        if isfolder(CONFIGS_FOLDER) then
            local files = listfiles(CONFIGS_FOLDER)
            for _, file in ipairs(files) do
                local name = file:match("([^/]+)%.json$")
                if name and name ~= "default" then
                    table.insert(configs, name)
                end
            end
        end
    end)
    return configs
end

-- Авто-загрузка
local function saveAutoExec(configName, autoEnable)
    pcall(function()
        if not isfolder(CONFIG_FOLDER) then
            makefolder(CONFIG_FOLDER)
        end
        
        local autoexec = {
            configName = configName or selectedConfig,
            autoEnable = autoEnable ~= nil and autoEnable or settings.autoEnable,
            version = SCRIPT_VERSION
        }
        
        local jsonData = HttpService:JSONEncode(autoexec)
        writefile(CONFIG_FOLDER .. "/" .. AUTOEXEC_FILE, jsonData)
    end)
end

local function loadAutoExec()
    pcall(function()
        if not isfile(CONFIG_FOLDER .. "/" .. AUTOEXEC_FILE) then
            return
        end
        
        local jsonData = readfile(CONFIG_FOLDER .. "/" .. AUTOEXEC_FILE)
        local autoexec = HttpService:JSONDecode(jsonData)
        
        if autoexec.configName then
            selectedConfig = autoexec.configName
        end
        
        if autoexec.autoEnable ~= nil then
            settings.autoEnable = autoexec.autoEnable
        end
    end)
end

-- Создание папок
local function ensureConfigFolder()
    pcall(function()
        if not isfolder(CONFIG_FOLDER) then
            makefolder(CONFIG_FOLDER)
        end
        if not isfolder(CONFIGS_FOLDER) then
            makefolder(CONFIGS_FOLDER)
        end
    end)
end

-- ESP
local function createEspObject(player)
    local esp = {}
    
    esp.box = Drawing.new("Square")
    esp.box.Thickness = espSettings.boxThickness
    esp.box.Color = espSettings.boxColor
    esp.box.Transparency = espSettings.transparency
    esp.box.Filled = false
    esp.box.Visible = false
    
    esp.name = Drawing.new("Text")
    esp.name.Color = espSettings.nameColor
    esp.name.Size = 14
    esp.name.Center = true
    esp.name.Visible = false
    
    esp.health = Drawing.new("Text")
    esp.health.Color = espSettings.healthColor
    esp.health.Size = 12
    esp.health.Center = true
    esp.health.Visible = false
    
    esp.distance = Drawing.new("Text")
    esp.distance.Color = espSettings.distanceColor
    esp.distance.Size = 12
    esp.distance.Center = true
    esp.distance.Visible = false
    
    esp.healthBg = Drawing.new("Square")
    esp.healthBg.Color = Color3.fromRGB(50, 50, 50)
    esp.healthBg.Thickness = 1
    esp.healthBg.Filled = true
    esp.healthBg.Transparency = 0.5
    esp.healthBg.Visible = false
    
    esp.healthFill = Drawing.new("Square")
    esp.healthFill.Color = Color3.fromRGB(0, 255, 0)
    esp.healthFill.Thickness = 0
    esp.healthFill.Filled = true
    esp.healthFill.Transparency = 0.5
    esp.healthFill.Visible = false
    
    espObjects[player] = esp
    return esp
end

local function updateEsp()
    if not espSettings.enabled then
        for _, esp in pairs(espObjects) do
            esp.box.Visible = false
            esp.name.Visible = false
            esp.health.Visible = false
            esp.distance.Visible = false
            esp.healthBg.Visible = false
            esp.healthFill.Visible = false
        end
        return
    end
    
    local cameraPos = camera.CFrame.Position
    
    for _, player in ipairs(players:GetPlayers()) do
        if player == plr then continue end
        
        local character = player.Character
        if not character then continue end
        
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        
        local head = character:FindFirstChild("Head")
        if not head then continue end
        
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not rootPart then continue end
        
        local esp = espObjects[player]
        if not esp then
            esp = createEspObject(player)
        end
        
        local headPos, onScreen2 = camera:WorldToViewportPoint(head.Position)
        local footPos, onScreen3 = camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 2, 0))
        
        if not onScreen2 or not onScreen3 then
            esp.box.Visible = false
            esp.name.Visible = false
            esp.health.Visible = false
            esp.distance.Visible = false
            esp.healthBg.Visible = false
            esp.healthFill.Visible = false
            continue
        end
        
        local height = math.abs(headPos.Y - footPos.Y) + 10
        local width = height * 0.4
        local pos = Vector2.new(footPos.X - width/2, footPos.Y - height)
        
        if espSettings.showBox then
            esp.box.Position = pos
            esp.box.Size = Vector2.new(width, height)
            esp.box.Color = espSettings.boxColor
            esp.box.Thickness = espSettings.boxThickness
            esp.box.Transparency = espSettings.transparency
            esp.box.Visible = true
        else
            esp.box.Visible = false
        end
        
        if espSettings.showName then
            esp.name.Text = player.Name
            esp.name.Position = Vector2.new(headPos.X, headPos.Y - height - 20)
            esp.name.Color = espSettings.nameColor
            esp.name.Visible = true
        else
            esp.name.Visible = false
        end
        
        if espSettings.showDistance then
            local distance = (rootPart.Position - cameraPos).Magnitude
            esp.distance.Text = string.format("%.1fm", distance)
            esp.distance.Position = Vector2.new(headPos.X, headPos.Y + 5)
            esp.distance.Color = espSettings.distanceColor
            esp.distance.Visible = true
        else
            esp.distance.Visible = false
        end
        
        if espSettings.showHealth then
            local healthPercent = humanoid.Health / humanoid.MaxHealth
            local healthColor = Color3.fromRGB(
                255 * (1 - healthPercent),
                255 * healthPercent,
                0
            )
            
            esp.health.Text = string.format("%.0f%%", healthPercent * 100)
            esp.health.Position = Vector2.new(headPos.X, headPos.Y - height - 35)
            esp.health.Color = healthColor
            esp.health.Visible = true
            
            local barWidth = width
            local barHeight = 4
            esp.healthBg.Position = Vector2.new(pos.X, pos.Y + height)
            esp.healthBg.Size = Vector2.new(barWidth, barHeight)
            esp.healthBg.Visible = true
            
            esp.healthFill.Position = Vector2.new(pos.X, pos.Y + height)
            esp.healthFill.Size = Vector2.new(barWidth * healthPercent, barHeight)
            esp.healthFill.Color = healthColor
            esp.healthFill.Visible = true
        else
            esp.health.Visible = false
            esp.healthBg.Visible = false
            esp.healthFill.Visible = false
        end
    end
    
    for player, esp in pairs(espObjects) do
        if not player.Parent then
            esp.box.Visible = false
            esp.name.Visible = false
            esp.health.Visible = false
            esp.distance.Visible = false
            esp.healthBg.Visible = false
            esp.healthFill.Visible = false
            espObjects[player] = nil
        end
    end
end

-- Получение части тела
local function getBestAimPart(character)
    if not character then return nil end
    
    if settings.aimPart ~= "Auto" then
        local part = character:FindFirstChild(settings.aimPart)
        if part and part:IsA("BasePart") then
            return part
        end
    end
    
    local cameraPos = camera.CFrame.Position
    local bestPart = nil
    local bestDistance = math.huge
    
    for _, partName in ipairs(BODY_PARTS) do
        local part = character:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            local distance = (part.Position - cameraPos).Magnitude
            if distance < bestDistance then
                bestDistance = distance
                bestPart = part
            end
        end
    end
    
    if not bestPart then
        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("BasePart") then
                local distance = (child.Position - cameraPos).Magnitude
                if distance < bestDistance then
                    bestDistance = distance
                    bestPart = child
                end
            end
        end
    end
    
    return bestPart
end

-- Core функции
local function isSameTeam(player)
    if not settings.teamCheck then return false end
    if not player.Team or not plr.Team then return false end
    return player.Team == plr.Team
end

local function isVisible(targetCharacter)
    if not settings.wallCheck then return true end
    
    local targetPart = getBestAimPart(targetCharacter)
    if not targetPart then return false end
    
    local origin = camera.CFrame.Position
    local direction = (targetPart.Position - origin).unit * 500
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {plr.Character, targetCharacter}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    
    local result = workspace:Raycast(origin, direction, raycastParams)
    return not result or result.Instance:IsDescendantOf(targetCharacter)
end

local function getTarget()
    local bestTarget = nil
    local bestScore = math.huge
    local cameraPos = camera.CFrame.Position
    local mousePos = Vector2.new(mouse.X, mouse.Y)
    
    for _, player in ipairs(players:GetPlayers()) do
        if player == plr then continue end
        if isSameTeam(player) then continue end
        
        local character = player.Character
        if not character then continue end
        
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid then continue end
        
        if settings.healthCheck and humanoid.Health < settings.minHealth then
            continue
        end
        
        if humanoid.Health <= 0 then continue end
        
        local targetPart = getBestAimPart(character)
        if not targetPart then continue end
        
        if not isVisible(character) then continue end
        
        local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
        if not onScreen then continue end
        
        local cursorDist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
        
        if cursorDist > settings.fov then continue end
        
        local distance = (targetPart.Position - cameraPos).Magnitude
        local score = cursorDist + (distance / 1000)
        
        if score < bestScore then
            bestScore = score
            bestTarget = player
        end
    end
    
    return bestTarget
end

local function getPredictedPosition(player)
    if not player or not player.Character then return nil end
    
    local targetPart = getBestAimPart(player.Character)
    local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
    if not targetPart or not rootPart then return nil end
    
    local velocity = rootPart.Velocity
    local prediction = targetPart.Position + (velocity * settings.prediction)
    
    return prediction
end

local function smoothAim(targetPosition)
    local currentCFrame = camera.CFrame
    local targetCFrame = CFrame.new(currentCFrame.Position, targetPosition)
    
    local lerpFactor = math.clamp(1 - settings.smoothing, 0.01, 1)
    camera.CFrame = currentCFrame:Lerp(targetCFrame, lerpFactor)
end

local function aimAtTarget(player)
    if not player or not player.Character then return end
    
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    
    local targetPos = getPredictedPosition(player)
    if targetPos then
        smoothAim(targetPos)
    end
end

--> [< GUI >] <--

local Window = Rayfield:CreateWindow({
    Name = "▶ Universal Aimbot v" .. SCRIPT_VERSION .. " ◀",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "by Agreed 🥵",
    ConfigurationSaving = {
        Enabled = false,
        FolderName = "UniversalAimbot",
        FileName = "byAgreed"
    },
})

Window.OnClose = function()
    closeScript()
end

-- Вкладки
local AimbotTab = Window:CreateTab("Aimbot 🎯")
local VisualTab = Window:CreateTab("Visual 👁️")
local ESPTab = Window:CreateTab("ESP 📡")
local ConfigTab = Window:CreateTab("Config ⚙️")
local GitHubTab = Window:CreateTab("GitHub 📦")

--> [< Aimbot Tab >] <--

AimbotTab:CreateToggle({
    Name = "Enable Aimbot",
    CurrentValue = false,
    Flag = "AimbotEnabled",
    Callback = function(Value)
        aimbotEnabled = Value
        if settings.showFovCircle then
            fovCircle.Visible = Value
        end
        if not Value then
            aiming = false
            currentTarget = nil
        end
    end
})

AimbotTab:CreateDropdown({
    Name = "Toggle Menu Key",
    Options = {"RightControl", "RightShift", "LeftControl", "LeftShift", "F1", "F2", "F3", "Insert"},
    CurrentOption = "RightControl",
    Flag = "MenuKey",
    Callback = function(Option)
        settings.menuKey = Option
        if Option == "RightControl" then
            settings.menuKey = Enum.KeyCode.RightControl
        elseif Option == "RightShift" then
            settings.menuKey = Enum.KeyCode.RightShift
        elseif Option == "LeftControl" then
            settings.menuKey = Enum.KeyCode.LeftControl
        elseif Option == "LeftShift" then
            settings.menuKey = Enum.KeyCode.LeftShift
        elseif Option == "F1" then
            settings.menuKey = Enum.KeyCode.F1
        elseif Option == "F2" then
            settings.menuKey = Enum.KeyCode.F2
        elseif Option == "F3" then
            settings.menuKey = Enum.KeyCode.F3
        elseif Option == "Insert" then
            settings.menuKey = Enum.KeyCode.Insert
        end
    end
})

AimbotTab:CreateButton({
    Name = "👁️ Hide Menu",
    Callback = function()
        toggleMenu()
    end
})

AimbotTab:CreateButton({
    Name = "🔴 Close Script",
    Callback = function()
        closeScript()
    end
})

AimbotTab:CreateDropdown({
    Name = "Activation Key",
    Options = {"BackSlash", "LeftControl", "LeftShift", "F", "RMB"},
    CurrentOption = "BackSlash",
    Flag = "ActivationKey",
    Callback = function(Option)
        settings.key = Option
        if Option == "BackSlash" then
            settings.key = Enum.KeyCode.BackSlash
        elseif Option == "LeftControl" then
            settings.key = Enum.KeyCode.LeftControl
        elseif Option == "LeftShift" then
            settings.key = Enum.KeyCode.LeftShift
        elseif Option == "F" then
            settings.key = Enum.KeyCode.F
        elseif Option == "RMB" then
            settings.key = nil
        end
    end
})

AimbotTab:CreateDropdown({
    Name = "Aim Part",
    Options = {
        "Auto (Best Available)",
        "Head",
        "HumanoidRootPart",
        "UpperTorso",
        "Torso",
        "LowerTorso",
        "LeftUpperArm",
        "RightUpperArm",
        "LeftLowerArm",
        "RightLowerArm",
        "LeftUpperLeg",
        "RightUpperLeg",
        "LeftLowerLeg",
        "RightLowerLeg",
        "LeftHand",
        "RightHand",
        "LeftFoot",
        "RightFoot"
    },
    CurrentOption = "Auto (Best Available)",
    Flag = "AimPart",
    Callback = function(Option)
        if Option == "Auto (Best Available)" then
            settings.aimPart = "Auto"
        else
            settings.aimPart = Option
        end
    end
})

AimbotTab:CreateToggle({
    Name = "Toggle Mode (ON = Toggle, OFF = Hold)",
    CurrentValue = false,
    Flag = "AimMode",
    Callback = function(Value)
        settings.aimMode = Value and "Toggle" or "Hold"
    end
})

AimbotTab:CreateSlider({
    Name = "FOV Size",
    Range = {0, 500},
    Increment = 1,
    CurrentValue = 200,
    Flag = "FOVSize",
    Callback = function(Value)
        settings.fov = Value
        fovCircle.Radius = Value
    end
})

AimbotTab:CreateSlider({
    Name = "Smoothing",
    Range = {0, 100},
    Increment = 1,
    CurrentValue = 10,
    Flag = "Smoothing",
    Callback = function(Value)
        settings.smoothing = Value / 100
    end
})

AimbotTab:CreateSlider({
    Name = "Prediction Strength",
    Range = {0, 0.3},
    Increment = 0.001,
    CurrentValue = 0.065,
    Flag = "Prediction",
    Callback = function(Value)
        settings.prediction = Value
    end
})

AimbotTab:CreateToggle({
    Name = "Wall Check",
    CurrentValue = false,
    Flag = "WallCheck",
    Callback = function(Value)
        settings.wallCheck = Value
    end
})

AimbotTab:CreateToggle({
    Name = "Sticky Aim",
    CurrentValue = false,
    Flag = "StickyAim",
    Callback = function(Value)
        settings.stickyAim = Value
    end
})

AimbotTab:CreateToggle({
    Name = "Team Check",
    CurrentValue = false,
    Flag = "TeamCheck",
    Callback = function(Value)
        settings.teamCheck = Value
    end
})

AimbotTab:CreateToggle({
    Name = "Health Check",
    CurrentValue = false,
    Flag = "HealthCheck",
    Callback = function(Value)
        settings.healthCheck = Value
    end
})

AimbotTab:CreateSlider({
    Name = "Min Health",
    Range = {0, 100},
    Increment = 1,
    CurrentValue = 0,
    Flag = "MinHealth",
    Callback = function(Value)
        settings.minHealth = Value
    end
})

AimbotTab:CreateButton({
    Name = "Show Available Parts",
    Callback = function()
        local character = plr.Character
        if character then
            local parts = {}
            for _, partName in ipairs(BODY_PARTS) do
                if character:FindFirstChild(partName) then
                    table.insert(parts, partName)
                end
            end
            if #parts > 0 then
                print("📋 Available parts:")
                for i, part in ipairs(parts) do
                    print(i .. ". " .. part)
                end
            else
                print("❌ No parts found!")
            end
        end
    end
})

--> [< Visual Tab >] <--

VisualTab:CreateToggle({
    Name = "Show FOV Circle",
    CurrentValue = true,
    Flag = "ShowFovCircle",
    Callback = function(Value)
        settings.showFovCircle = Value
        if not Value then
            fovCircle.Visible = false
        elseif aimbotEnabled then
            fovCircle.Visible = true
        end
    end
})

VisualTab:CreateColorPicker({
    Name = "FOV Color",
    Color = settings.fovColor,
    Callback = function(Color)
        settings.fovColor = Color
        if not settings.rainbowFov then
            fovCircle.Color = Color
        end
    end
})

VisualTab:CreateColorPicker({
    Name = "Targeted FOV Color",
    Color = settings.targetedColor,
    Callback = function(Color)
        settings.targetedColor = Color
    end
})

VisualTab:CreateToggle({
    Name = "Rainbow FOV",
    CurrentValue = false,
    Flag = "RainbowFOV",
    Callback = function(Value)
        settings.rainbowFov = Value
    end
})

VisualTab:CreateSlider({
    Name = "FOV Circle Thickness",
    Range = {1, 10},
    Increment = 1,
    CurrentValue = 2,
    Flag = "FOVThickness",
    Callback = function(Value)
        settings.fovThickness = Value
        fovCircle.Thickness = Value
    end
})

VisualTab:CreateSlider({
    Name = "FOV Circle Transparency",
    Range = {0, 100},
    Increment = 1,
    CurrentValue = 0,
    Flag = "FOVTransparency",
    Callback = function(Value)
        settings.fovTransparency = Value
        fovCircle.Transparency = Value / 100
    end
})

VisualTab:CreateToggle({
    Name = "Fill FOV Circle",
    CurrentValue = false,
    Flag = "FOVFilled",
    Callback = function(Value)
        settings.fovFilled = Value
        fovCircle.Filled = Value
    end
})

--> [< ESP Tab >] <--

ESPTab:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = false,
    Flag = "ESPEnabled",
    Callback = function(Value)
        espSettings.enabled = Value
        if not Value then
            for _, esp in pairs(espObjects) do
                esp.box.Visible = false
                esp.name.Visible = false
                esp.health.Visible = false
                esp.distance.Visible = false
                esp.healthBg.Visible = false
                esp.healthFill.Visible = false
            end
        end
    end
})

ESPTab:CreateToggle({
    Name = "Show Box",
    CurrentValue = true,
    Flag = "ESPShowBox",
    Callback = function(Value)
        espSettings.showBox = Value
    end
})

ESPTab:CreateToggle({
    Name = "Show Name",
    CurrentValue = true,
    Flag = "ESPShowName",
    Callback = function(Value)
        espSettings.showName = Value
    end
})

ESPTab:CreateToggle({
    Name = "Show Health",
    CurrentValue = true,
    Flag = "ESPShowHealth",
    Callback = function(Value)
        espSettings.showHealth = Value
    end
})

ESPTab:CreateToggle({
    Name = "Show Distance",
    CurrentValue = true,
    Flag = "ESPShowDistance",
    Callback = function(Value)
        espSettings.showDistance = Value
    end
})

ESPTab:CreateColorPicker({
    Name = "Box Color",
    Color = espSettings.boxColor,
    Callback = function(Color)
        espSettings.boxColor = Color
    end
})

ESPTab:CreateColorPicker({
    Name = "Name Color",
    Color = espSettings.nameColor,
    Callback = function(Color)
        espSettings.nameColor = Color
    end
})

ESPTab:CreateColorPicker({
    Name = "Distance Color",
    Color = espSettings.distanceColor,
    Callback = function(Color)
        espSettings.distanceColor = Color
    end
})

ESPTab:CreateSlider({
    Name = "Box Thickness",
    Range = {1, 5},
    Increment = 1,
    CurrentValue = 2,
    Flag = "ESPBoxThickness",
    Callback = function(Value)
        espSettings.boxThickness = Value
    end
})

ESPTab:CreateSlider({
    Name = "Box Transparency",
    Range = {0, 100},
    Increment = 1,
    CurrentValue = 50,
    Flag = "ESPTransparency",
    Callback = function(Value)
        espSettings.transparency = Value / 100
    end
})

--> [< Config Tab >] <--

local configDropdown = ConfigTab:CreateDropdown({
    Name = "Select Config",
    Options = getConfigList(),
    CurrentOption = "default",
    Flag = "SelectConfig",
    Callback = function(Option)
        selectedConfig = Option
        print("Selected: " .. Option)
    end
})

ConfigTab:CreateButton({
    Name = "💾 Save Current Config",
    Callback = function()
        ensureConfigFolder()
        saveConfig(selectedConfig)
        configDropdown:Refresh(getConfigList(), selectedConfig)
    end
})

ConfigTab:CreateButton({
    Name = "💾 Save As New Config",
    Callback = function()
        local name = "config_" .. os.time()
        ensureConfigFolder()
        saveConfig(name)
        selectedConfig = name
        configDropdown:Refresh(getConfigList(), selectedConfig)
        print("✅ Saved as: " .. name)
    end
})

ConfigTab:CreateButton({
    Name = "📂 Load Selected Config",
    Callback = function()
        ensureConfigFolder()
        loadConfig(selectedConfig)
        print("✅ Config loaded!")
    end
})

ConfigTab:CreateButton({
    Name = "🗑️ Delete Selected Config",
    Callback = function()
        if selectedConfig == "default" then
            print("❌ Cannot delete default!")
            return
        end
        
        pcall(function()
            if isfile(CONFIGS_FOLDER .. "/" .. selectedConfig .. ".json") then
                delfile(CONFIGS_FOLDER .. "/" .. selectedConfig .. ".json")
                print("🗑️ Deleted: " .. selectedConfig)
                selectedConfig = "default"
                configDropdown:Refresh(getConfigList(), "default")
            end
        end)
    end
})

ConfigTab:CreateToggle({
    Name = "🚀 Auto-Enable on Load",
    CurrentValue = false,
    Flag = "AutoEnable",
    Callback = function(Value)
        settings.autoEnable = Value
        saveAutoExec(selectedConfig, Value)
    end
})

ConfigTab:CreateToggle({
    Name = "📂 Auto-Load Selected Config",
    CurrentValue = false,
    Flag = "AutoLoadConfig",
    Callback = function(Value)
        saveAutoExec(selectedConfig, settings.autoEnable)
        print(Value and "✅ Auto-load enabled" or "❌ Auto-load disabled")
    end
})

ConfigTab:CreateButton({
    Name = "🔄 Reset to Defaults",
    Callback = function()
        settings.fov = 200
        settings.smoothing = 0.1
        settings.prediction = 0.065
        settings.wallCheck = false
        settings.stickyAim = false
        settings.teamCheck = false
        settings.healthCheck = false
        settings.minHealth = 0
        settings.aimPart = "Auto"
        settings.fovColor = Color3.fromRGB(255, 0, 0)
        settings.targetedColor = Color3.fromRGB(0, 255, 0)
        settings.rainbowFov = false
        settings.aimMode = "Hold"
        settings.key = "BackSlash"
        settings.showFovCircle = true
        settings.fovThickness = 2
        settings.fovTransparency = 0
        settings.fovFilled = false
        
        espSettings.enabled = false
        espSettings.boxColor = Color3.fromRGB(0, 255, 0)
        espSettings.boxThickness = 2
        espSettings.transparency = 0.5
        espSettings.showName = true
        espSettings.showHealth = true
        espSettings.showDistance = true
        espSettings.showBox = true
        
        fovCircle.Radius = settings.fov
        fovCircle.Color = settings.fovColor
        fovCircle.Thickness = settings.fovThickness
        fovCircle.Transparency = settings.fovTransparency / 100
        fovCircle.Filled = settings.fovFilled
        
        print("✅ Reset to defaults!")
    end
})

--> [< GitHub Tab >] <--

GitHubTab:CreateButton({
    Name = "🔄 Check for Updates",
    Callback = function()
        local hasUpdate, version = checkForUpdates()
        if hasUpdate then
            print("📥 New version: " .. version)
            print("📥 Download from: " .. GITHUB_RAW_URL .. "aimbot.lua")
        end
    end
})

GitHubTab:CreateButton({
    Name = "📋 Copy GitHub URL",
    Callback = function()
        setclipboard("https://github.com/ваш-username/universal-aimbot")
        print("✅ URL copied to clipboard!")
    end
})

GitHubTab:CreateButton({
    Name = "📋 Copy Loadstring",
    Callback = function()
        local loadstring = 'loadstring(game:HttpGet("' .. GITHUB_RAW_URL .. 'aimbot.lua"))()'
        setclipboard(loadstring)
        print("✅ Loadstring copied to clipboard!")
    end
})

GitHubTab:CreateLabel({
    Name = "📌 Version: " .. SCRIPT_VERSION
})

GitHubTab:CreateLabel({
    Name = "📌 Repository: universal-aimbot"
})

--> [< Input Handling >] <--

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if settings.menuKey and input.KeyCode == settings.menuKey then
        toggleMenu()
    end
    
    if not aimbotEnabled then return end
    
    if settings.key and input.KeyCode == settings.key then
        if settings.aimMode == "Hold" then
            aiming = true
        elseif settings.aimMode == "Toggle" then
            aiming = not aiming
            if not aiming then
                currentTarget = nil
            end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed or not aimbotEnabled then return end
    
    if settings.key and input.KeyCode == settings.key and settings.aimMode == "Hold" then
        aiming = false
        currentTarget = nil
    end
end)

mouse.Button2Down:Connect(function()
    if aimbotEnabled then
        aiming = true
    end
end)

mouse.Button2Up:Connect(function()
    if aimbotEnabled and (not settings.key or settings.aimMode == "Hold") then
        aiming = false
        currentTarget = nil
    end
end)

--> [< Main Loop >] <--

RunService.RenderStepped:Connect(function()
    updateEsp()
    
    if not aimbotEnabled then
        fovCircle.Visible = false
        return
    end
    
    if settings.showFovCircle then
        fovCircle.Position = Vector2.new(mouse.X, mouse.Y + 50)
        fovCircle.Visible = true
        
        if settings.rainbowFov then
            hue = (hue + rainbowSpeed) % 1
            fovCircle.Color = Color3.fromHSV(hue, 1, 1)
        elseif aiming and currentTarget then
            fovCircle.Color = settings.targetedColor
        else
            fovCircle.Color = settings.fovColor
        end
    else
        fovCircle.Visible = false
    end
    
    if aiming then
        if settings.stickyAim and currentTarget then
            local character = currentTarget.Character
            if character then
                local targetPart = getBestAimPart(character)
                if targetPart then
                    local screenPos = camera:WorldToViewportPoint(targetPart.Position)
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(mouse.X, mouse.Y)).Magnitude
                    
                    if dist > settings.fov * 1.5 or not isVisible(character) then
                        currentTarget = nil
                    end
                else
                    currentTarget = nil
                end
            else
                currentTarget = nil
            end
        end
        
        if not settings.stickyAim or not currentTarget then
            currentTarget = getTarget()
        end
        
        if currentTarget then
            aimAtTarget(currentTarget)
        end
    else
        currentTarget = nil
    end
end)

--> [< Init >] <--

print("====================================")
print("🎯 Universal Aimbot v" .. SCRIPT_VERSION)
print("====================================")

ensureConfigFolder()
loadAutoExec()

if selectedConfig then
    loadConfig(selectedConfig)
end

if settings.autoEnable then
    task.wait(1)
    if aimbotEnabled ~= true then
        aimbotEnabled = true
        if settings.showFovCircle then
            fovCircle.Visible = true
        end
        print("🚀 Auto-exec enabled!")
    end
end

-- Создаем ESP для существующих игроков
for _, player in ipairs(players:GetPlayers()) do
    if player ~= plr then
        createEspObject(player)
    end
end

players.PlayerAdded:Connect(function(player)
    if player ~= plr then
        createEspObject(player)
    end
end)

-- Проверяем обновления
checkForUpdates()

print("====================================")
print("✅ Aimbot loaded successfully!")
print("📌 Press '\\' (BackSlash) or RMB to aim")
print("📌 Press RightControl to hide/show menu")
print("📌 Click X or 'Close Script' to close")
print("====================================")
