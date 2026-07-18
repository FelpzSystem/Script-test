-- =====================================================================
-- SILVERFOX SCRIPTS | HOSPITAL DE ANIMAIS
-- WindUI Edition - Otimizado para Delta Executor Mobile
-- Funções mescladas com o script base do RodrigoBloxYT
-- =====================================================================

-- Carregar WindUI
local WindUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"
))()

local Window = WindUI:CreateWindow({
    Title = "SILVERFOX SCRIPTS | HOSPITAL DE ANIMAIS",
    Icon = "https://files.catbox.moe/vr0nkt.jpg",
    Theme = "Dark",
    Size = UDim2.fromOffset(650, 550),
})

-- ==========================================
-- SERVIÇOS DO ROBLOX
-- ==========================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ==========================================
-- CONFIGURAÇÕES
-- ==========================================

_G.HospitalConfig = _G.HospitalConfig or {
    InstantAction = false,
    AutoProcess = false,
    AutoHeal = false,
    AutoRoom6 = false,
    AutoRoom7 = false,
    AutoRoom8 = false,
    NoClip = false,
    WalkSpeed = 16,
    Fly = false,
    FlySpeed = 50,
}
local Config = _G.HospitalConfig

local ItemDebounce = {}
local ITEM_PICKUP_COOLDOWN = 0.2

-- ==========================================
-- CACHE DE ITENS (OTIMIZAÇÃO)
-- ==========================================

local ItemPromptCache = {}
local CacheRefreshTime = 0
local CACHE_DURATION = 3

local function RefreshItemCache()
    ItemPromptCache = {}
    CacheRefreshTime = os.clock()
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("ProximityPrompt") and desc.Enabled and desc.ActionText then
            ItemPromptCache[string.lower(desc.ActionText)] = desc
        end
    end
end

local function GetCachedItemPrompt(itemName)
    if not itemName or itemName == "" then return nil end
    if os.clock() - CacheRefreshTime > CACHE_DURATION then RefreshItemCache() end
    local target = string.lower(itemName)
    for key, prompt in pairs(ItemPromptCache) do
        if string.find(key, target) or string.find(target, key) then return prompt end
    end
    return nil
end

-- ==========================================
-- FUNÇÕES UTILITÁRIAS
-- ==========================================

local function GetCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function GetHumanoid()
    local char = GetCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function GetRootPart()
    local char = GetCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function FindBasePartInObject(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    for _, child in ipairs(obj:GetChildren()) do
        if child:IsA("BasePart") then return child end
        if child:IsA("Model") then
            local part = FindBasePartInObject(child)
            if part then return part end
        end
    end
    return nil
end

local function SafeTeleport(position)
    local root = GetRootPart()
    if not root then return false end

    local newPos = position + Vector3.new(0, 2, 0)
    local success = pcall(function()
        root.CFrame = CFrame.new(newPos)
    end)

    if success then
        RunService.Heartbeat:Wait()
        root.Velocity = Vector3.new(0, 0, 0)
        local hum = GetHumanoid()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Running) end
    end
    return success
end

-- Foca a câmera e o personagem no alvo (deixa a interação mais "visual")
local function LookAtPosition(targetPosition)
    local root = GetRootPart()
    if root and targetPosition then
        pcall(function()
            root.CFrame = CFrame.lookAt(root.Position, targetPosition)

            local character = GetCharacter()
            if character then
                local head = character:FindFirstChild("Head")
                if head then
                    local camPos = head.Position - (root.CFrame.LookVector * 4) + Vector3.new(0, 2, 0)
                    Camera.CFrame = CFrame.lookAt(camPos, targetPosition)
                end
            end
        end)
    end
end

-- ==========================================
-- INTERAÇÃO COM PROXIMITY PROMPT
-- ==========================================

local function FirePromptDirect(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then return false end

    local targetPart = FindBasePartInObject(prompt.Parent)
    if targetPart then
        LookAtPosition(targetPart.Position)
    end

    if Config.InstantAction then
        pcall(function() prompt.HoldDuration = 0 end)
    end

    local success = false

    -- Método 1: fireproximityprompt (mais rápido, depende do executor)
    if typeof(fireproximityprompt) == "function" then
        local s1 = pcall(function()
            fireproximityprompt(prompt)
        end)
        if s1 then success = true end
    end

    -- Método 2: simulação de hold
    if not success then
        local s2 = pcall(function()
            prompt:InputHoldStart(LocalPlayer)
            task.wait(prompt.HoldDuration or 0.05)
            prompt:InputHoldEnd(LocalPlayer)
        end)
        if s2 then success = true end
    end

    -- Método 3: via mouse target
    if not success then
        local s3 = pcall(function()
            local mouse = LocalPlayer:GetMouse()
            if mouse and targetPart then
                mouse.Target = targetPart
                mouse.TargetClick:Fire()
            end
        end)
        if s3 then success = true end
    end

    return success
end

local function FirePromptWithCamera(prompt, targetPosition)
    if not prompt or not prompt:IsA("ProximityPrompt") then return false end
    if targetPosition then LookAtPosition(targetPosition) end
    return FirePromptDirect(prompt)
end

local function ClickButton(buttonPart)
    if not buttonPart then return false end
    local clickDetector = buttonPart:FindFirstChildOfClass("ClickDetector")
    if clickDetector then
        LookAtPosition(buttonPart.Position)
        local success = pcall(function()
            if typeof(fireclickdetector) == "function" then
                fireclickdetector(clickDetector)
            else
                clickDetector.MaxActivationDistance = 100
                clickDetector:Activate()
            end
        end)
        return success
    end
    return false
end

-- ==========================================
-- FUNÇÕES DE BUSCA
-- ==========================================

local function GetPromptByActionText(actionText, searchRoot)
    if not actionText or actionText == "" then return nil end
    if not searchRoot then searchRoot = Workspace end

    local targetText = string.lower(actionText)
    for _, desc in ipairs(searchRoot:GetDescendants()) do
        if desc:IsA("ProximityPrompt") and desc.Enabled and desc.ActionText then
            local lowerAction = string.lower(desc.ActionText)
            if string.find(lowerAction, targetText) or string.find(targetText, lowerAction) then
                return desc
            end
        end
    end
    return nil
end

local function HasItem(itemName)
    if not itemName or itemName == "" then return false end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and string.find(string.lower(tool.Name), string.lower(itemName)) then
                return true
            end
        end
    end
    local char = GetCharacter()
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") and string.find(string.lower(tool.Name), string.lower(itemName)) then
                return true
            end
        end
    end
    return false
end

local function HasCheck(item)
    if not item then return false end
    local check = item:FindFirstChild("check")
    if check and check:IsA("ImageLabel") then return check.Visible == true end
    return false
end

local function GetItemsFromInv(invFolder)
    local itemsNeeded = {}
    if not invFolder then return itemsNeeded end
    for _, child in ipairs(invFolder:GetChildren()) do
        if not child:IsA("UIGridLayout") and not child:IsA("UIListLayout") then
            if child.Name and child.Name ~= "" and not HasCheck(child) then
                table.insert(itemsNeeded, child.Name)
            end
        end
    end
    return itemsNeeded
end

local function EquipToolFast(itemName)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local hum = GetHumanoid()
    if backpack and hum then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and string.find(string.lower(tool.Name), string.lower(itemName)) then
                hum:EquipTool(tool)
                task.wait(0.05)
                return true
            end
        end
    end
    return false
end

-- ==========================================
-- LOCALIZAÇÃO DO MAPA
-- ==========================================

local function GetMedicalRooms()
    local rooms = Workspace:FindFirstChild("Rooms")
    if rooms then return rooms:FindFirstChild("Medical") end
    return Workspace:FindFirstChild("Medical")
end

local function GetEmergencyRooms()
    local rooms = Workspace:FindFirstChild("Rooms")
    if rooms then return rooms:FindFirstChild("Emergency") end
    return Workspace:FindFirstChild("Emergency")
end

local function FindInBedInRoom(room)
    if not room then return nil end
    local minigame = room:FindFirstChild("Minigame")
    if minigame then
        local bed = minigame:FindFirstChild("Bed")
        if bed then return bed:FindFirstChild("InBed") end
    end
    return room:FindFirstChild("InBed")
end

local function FindInvInRoom(room)
    if not room then return nil end
    local minigame = room:FindFirstChild("Minigame")
    if minigame then
        local tv = minigame:FindFirstChild("TV")
        if tv then
            local screen = tv:FindFirstChild("Screen")
            if screen then
                local ui = screen:FindFirstChild("UI")
                if ui then
                    local report = ui:FindFirstChild("Report")
                    if report then return report:FindFirstChild("inv") end
                end
            end
        end
    end
    return room:FindFirstChild("inv", true)
end

local function FindColorsInMinigame(room)
    if not room then return nil end
    local minigame = room:FindFirstChild("Minigame")
    if not minigame then return nil end
    for _, desc in ipairs(minigame:GetDescendants()) do
        if desc.Name == "Colors" and desc:IsA("Folder") then return desc end
    end
    return nil
end

local function FindXrayMonitorInMinigame(room)
    if not room then return nil end
    local minigame = room:FindFirstChild("Minigame")
    if not minigame then return nil end
    for _, desc in ipairs(minigame:GetDescendants()) do
        if desc.Name == "xrayMonitor" and desc:IsA("Model") then return desc end
    end
    return nil
end

-- ==========================================
-- FUNÇÕES ESPECÍFICAS DA ROOM 6
-- ==========================================

local function GetButtonModels(colorsFolder)
    if not colorsFolder then return {} end
    local buttons = {}
    for _, model in ipairs(colorsFolder:GetChildren()) do
        if model:IsA("Model") and model:FindFirstChild("Button") then
            local btn = model:FindFirstChild("Button")
            if btn and btn:IsA("BasePart") then
                table.insert(buttons, btn)
            end
        end
    end
    return buttons
end

local function GetButtonColors(colorsFolder)
    if not colorsFolder then return {} end
    local colors = {}
    for _, model in ipairs(colorsFolder:GetChildren()) do
        if model:IsA("Model") and model:FindFirstChild("Button") then
            local btn = model:FindFirstChild("Button")
            if btn and btn:IsA("BasePart") then
                table.insert(colors, btn.Color)
            end
        end
    end
    return colors
end

local function CountChangedButtons(colorsFolder, initialColors)
    if not colorsFolder or not initialColors then return 0 end
    local currentColors = GetButtonColors(colorsFolder)
    local changed = 0
    for i = 1, math.min(#initialColors, #currentColors) do
        if initialColors[i] ~= currentColors[i] then
            changed = changed + 1
        end
    end
    return changed
end

local function AutoRoom6Sequence()
    local emergency = GetEmergencyRooms()
    if not emergency then return end

    local room6 = emergency:FindFirstChild("Room6")
    if not room6 then return end

    local minigame = room6:FindFirstChild("Minigame")
    if not minigame then return end

    -- Passo 1: Begin X-Ray
    local xrayMonitor = FindXrayMonitorInMinigame(room6)
    if xrayMonitor then
        local xrayPrompt = xrayMonitor:FindFirstChild("PP")
        if xrayPrompt and xrayPrompt:IsA("ProximityPrompt") and xrayPrompt.Enabled then
            local part = FindBasePartInObject(xrayMonitor)
            if part then
                SafeTeleport(part.Position)
                FirePromptWithCamera(xrayPrompt, part.Position)
                task.wait(0.5)
            end
        end
    end

    -- Passo 2: aguardar 4 botões mudarem de cor
    local colorsFolder = FindColorsInMinigame(room6)
    if not colorsFolder then return end

    local initialColors = GetButtonColors(colorsFolder)
    local buttons = GetButtonModels(colorsFolder)
    if #buttons < 4 then return end

    local timeout = 0
    local changedCount = 0
    local maxWaitTime = 15

    while timeout < maxWaitTime and changedCount < 4 do
        task.wait(0.2)
        changedCount = CountChangedButtons(colorsFolder, initialColors)
        timeout = timeout + 0.2
        if not Config.AutoRoom6 then return end
    end

    -- Passo 3: esperar 1.5s
    task.wait(1.5)

    -- Passo 4: clicar nos 4 botões
    for _, btn in ipairs(buttons) do
        if not Config.AutoRoom6 then return end
        if btn and btn:IsA("BasePart") then
            SafeTeleport(btn.Position + Vector3.new(0, 1, 2))
            LookAtPosition(btn.Position)
            task.wait(0.2)
            ClickButton(btn)
            task.wait(0.15)
        end
    end

    -- Passo 5: Process Results
    local processPrompt = nil
    local processTimeout = 0
    while processTimeout < 10 do
        processPrompt = GetPromptByActionText("process results", minigame)
        if processPrompt then break end
        task.wait(0.3)
        processTimeout = processTimeout + 0.3
    end
    if processPrompt then
        local part = FindBasePartInObject(processPrompt.Parent)
        if part then
            SafeTeleport(part.Position)
            FirePromptWithCamera(processPrompt, part.Position)
            task.wait(0.5)
        end
    end

    -- Passo 6: Print Badge
    local printBadgePrompt = nil
    local badgeTimeout = 0
    while badgeTimeout < 10 do
        printBadgePrompt = GetPromptByActionText("print badge", minigame)
        if printBadgePrompt then break end
        task.wait(0.3)
        badgeTimeout = badgeTimeout + 0.3
    end
    if printBadgePrompt then
        local part = FindBasePartInObject(printBadgePrompt.Parent)
        if part then
            SafeTeleport(part.Position)
            FirePromptWithCamera(printBadgePrompt, part.Position)
            task.wait(0.5)
        end
    end

    -- Passo 7: Collect
    local collectPrompt = nil
    local collectTimeout = 0
    while collectTimeout < 8 do
        collectPrompt = GetPromptByActionText("collect", Workspace)
        if collectPrompt then break end
        task.wait(0.3)
        collectTimeout = collectTimeout + 0.3
    end
    if collectPrompt then
        local part = FindBasePartInObject(collectPrompt.Parent)
        if part then
            SafeTeleport(part.Position)
            FirePromptWithCamera(collectPrompt, part.Position)
            task.wait(0.3)
        end
    end
end

task.spawn(function()
    while true do
        RunService.Heartbeat:Wait()
        if Config.AutoRoom6 then
            AutoRoom6Sequence()
            task.wait(3)
        end
    end
end)

-- ==========================================
-- AUTO HEAL (com retry e validação)
-- ==========================================

local function HealRoomFast(roomNum)
    local room = nil
    local itemsNeeded = {}
    local promptToDeliver = nil
    local deliverPosition = nil

    if roomNum <= 5 then
        local medical = GetMedicalRooms()
        if medical then room = medical:FindFirstChild("Room" .. roomNum) end
        if not room then return false end

        local invPath = FindInvInRoom(room)
        if not invPath then return false end
        itemsNeeded = GetItemsFromInv(invPath)

        local bedPath = FindInBedInRoom(room)
        if bedPath then
            for _, desc in ipairs(bedPath:GetDescendants()) do
                if desc:IsA("ProximityPrompt") and desc.Enabled then
                    promptToDeliver = desc
                    break
                end
            end
            if not promptToDeliver and bedPath.Parent then
                for _, desc in ipairs(bedPath.Parent:GetDescendants()) do
                    if desc:IsA("ProximityPrompt") and desc.Enabled then
                        promptToDeliver = desc
                        break
                    end
                end
            end
            deliverPosition = bedPath.Position
        end
    elseif roomNum == 6 then
        local emergency = GetEmergencyRooms()
        if emergency then room = emergency:FindFirstChild("Room6") end
        if not room then return false end

        local invPath = FindInvInRoom(room)
        if not invPath then return false end
        itemsNeeded = GetItemsFromInv(invPath)

        local npcsFolder = Workspace:FindFirstChild("NPCs")
        if npcsFolder then
            for _, npc in ipairs(npcsFolder:GetChildren()) do
                local pp = npc:FindFirstChild("PP")
                if pp and pp:IsA("ProximityPrompt") and pp.Enabled and string.find(string.lower(pp.ActionText or ""), "treatment") then
                    promptToDeliver = pp
                    local part = FindBasePartInObject(npc)
                    deliverPosition = part and part.Position
                    break
                end
            end
        end
    end

    if #itemsNeeded == 0 or not promptToDeliver then return false end

    -- Fase 1: coleta de itens (com retry e validação)
    local holdingAllItems = true
    local maxRetries = 3

    for _, itemName in ipairs(itemsNeeded) do
        local retryCount = 0
        local collected = HasItem(itemName)

        while not collected and retryCount < maxRetries do
            local prompt = GetCachedItemPrompt(itemName)
            if prompt and prompt.Enabled then
                local lastPickup = ItemDebounce[prompt] or 0
                if os.clock() - lastPickup >= ITEM_PICKUP_COOLDOWN then
                    local part = FindBasePartInObject(prompt.Parent)
                    if part then
                        ItemDebounce[prompt] = os.clock()
                        SafeTeleport(part.Position)
                        FirePromptDirect(prompt)
                        task.wait(0.2)
                        if HasItem(itemName) then
                            collected = true
                            break
                        end
                    end
                end
            end
            retryCount = retryCount + 1
            task.wait(0.1)
        end

        if not collected then holdingAllItems = false end
    end

    -- Fase 2: entrega ao paciente
    if holdingAllItems and deliverPosition then
        SafeTeleport(deliverPosition + Vector3.new(0, 1, 0))
        for _, itemName in ipairs(itemsNeeded) do
            if HasItem(itemName) then
                EquipToolFast(itemName)
                for i = 1, 3 do
                    if FirePromptDirect(promptToDeliver) then break end
                    task.wait(0.1)
                end
                task.wait(0.1)
            end
        end
    end

    return true
end

task.spawn(function()
    while true do
        RunService.Heartbeat:Wait()
        if Config.AutoHeal then
            for roomNum = 1, 6 do
                if not Config.AutoHeal then break end
                HealRoomFast(roomNum)
                task.wait(0.1)
            end
        end
    end
end)

-- ==========================================
-- AUTO PROCESS (DNA/ANALYZE GLOBAL)
-- ==========================================

local function ProcessGlobalRooms()
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if not Config.AutoProcess then break end
        if desc:IsA("ProximityPrompt") and desc.Enabled and desc.ActionText then
            local txt = string.lower(desc.ActionText)
            if string.find(txt, "dna") or string.find(txt, "analyze") or string.find(txt, "process") then
                local part = FindBasePartInObject(desc.Parent)
                if part then
                    SafeTeleport(part.Position)
                    FirePromptDirect(desc)
                end
            end
        end
    end
end

task.spawn(function()
    while true do
        RunService.Heartbeat:Wait()
        if Config.AutoProcess then
            ProcessGlobalRooms()
        end
        task.wait(0.5)
    end
end)

-- ==========================================
-- AUTO ROOM 7
-- ==========================================

task.spawn(function()
    while true do
        RunService.Heartbeat:Wait()
        if Config.AutoRoom7 then
            local emergency = GetEmergencyRooms()
            local room7 = emergency and emergency:FindFirstChild("Room7")
            if room7 then
                local inBed = FindInBedInRoom(room7)
                if inBed then
                    for _, prompt in ipairs(inBed:GetDescendants()) do
                        if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                            local text = string.lower(prompt.ActionText or "")
                            local targets = {"sleep", "prepare", "set up", "turn on", "begin", "collect"}
                            for _, target in ipairs(targets) do
                                if string.find(text, target) then
                                    local part = FindBasePartInObject(prompt.Parent)
                                    if part then
                                        SafeTeleport(part.Position)
                                        FirePromptDirect(prompt)
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ==========================================
-- AUTO ROOM 8
-- ==========================================

task.spawn(function()
    while true do
        RunService.Heartbeat:Wait()
        if Config.AutoRoom8 then
            local emergency = GetEmergencyRooms()
            local room8 = emergency and emergency:FindFirstChild("Room8")
            if room8 then
                local inBed = FindInBedInRoom(room8)
                if inBed then
                    for _, prompt in ipairs(inBed:GetDescendants()) do
                        if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                            local text = string.lower(prompt.ActionText or "")
                            if string.find(text, "sleep") or string.find(text, "patient") then
                                local part = FindBasePartInObject(prompt.Parent)
                                if part then
                                    SafeTeleport(part.Position)
                                    FirePromptDirect(prompt)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ==========================================
-- HOOK DE PROMPTS (Instant Action)
-- ==========================================

local function HookPrompt(prompt)
    if not prompt:IsA("ProximityPrompt") then return end
    if Config.InstantAction then pcall(function() prompt.HoldDuration = 0 end) end
end

Workspace.DescendantAdded:Connect(HookPrompt)
for _, p in ipairs(Workspace:GetDescendants()) do HookPrompt(p) end

-- ==========================================
-- NOCLIP
-- ==========================================

RunService.Stepped:Connect(function()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = Config.WalkSpeed end

    if Config.NoClip and char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)

-- Garante que partes novas (respawn, acessórios, etc.) também fiquem sem colisão
Players.LocalPlayer.CharacterAdded:Connect(function(char)
    char.DescendantAdded:Connect(function(part)
        if Config.NoClip and part:IsA("BasePart") then
            part.CanCollide = false
        end
    end)
end)

if LocalPlayer.Character then
    LocalPlayer.Character.DescendantAdded:Connect(function(part)
        if Config.NoClip and part:IsA("BasePart") then
            part.CanCollide = false
        end
    end)
end

-- ==========================================
-- FLY
-- ==========================================

local FlyBV, FlyGyro
local FlyLoopConn

local function StopFly()
    Config.Fly = false
    if FlyLoopConn then
        FlyLoopConn:Disconnect()
        FlyLoopConn = nil
    end
    if FlyBV then FlyBV:Destroy() FlyBV = nil end
    if FlyGyro then FlyGyro:Destroy() FlyGyro = nil end
    local hum = GetHumanoid()
    if hum then hum.PlatformStand = false end
end

local function StartFly()
    local hum = GetHumanoid()
    local root = GetRootPart()
    if not hum or not root then return end

    Config.Fly = true
    hum.PlatformStand = true

    FlyBV = Instance.new("BodyVelocity")
    FlyBV.MaxForce = Vector3.new(1, 1, 1) * math.huge
    FlyBV.Velocity = Vector3.new(0, 0, 0)
    FlyBV.Parent = root

    FlyGyro = Instance.new("BodyGyro")
    FlyGyro.MaxTorque = Vector3.new(1, 1, 1) * math.huge
    FlyGyro.P = 10000
    FlyGyro.CFrame = root.CFrame
    FlyGyro.Parent = root

    FlyLoopConn = RunService.Heartbeat:Connect(function()
        if not Config.Fly then return end
        local h = GetHumanoid()
        local r = GetRootPart()
        if not h or not r or not FlyBV or not FlyGyro then return end

        local camera = Workspace.CurrentCamera
        local moveVector = h.MoveDirection

        local flatLook = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
        local flatRight = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)
        if flatLook.Magnitude > 0 then flatLook = flatLook.Unit end
        if flatRight.Magnitude > 0 then flatRight = flatRight.Unit end

        local forwardAmount = moveVector:Dot(flatLook)
        local rightAmount = moveVector:Dot(flatRight)

        local direction = (camera.CFrame.LookVector * forwardAmount) + (camera.CFrame.RightVector * rightAmount)

        FlyBV.Velocity = direction * Config.FlySpeed
        if direction.Magnitude > 0.05 then
            FlyGyro.CFrame = CFrame.new(r.Position, r.Position + direction)
        end
    end)
end

Players.LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if Config.Fly then
        StopFly()
        StartFly()
    end
end)

-- ==========================================
-- WINDUI - TABS E CONTROLES
-- ==========================================

-- Tab Principal
local MainTab = Window:Tab({
    Title = "Principal",
    Icon = "home"
})

MainTab:Toggle({
    Title = "Auto Heal",
    Description = "Coleta itens e trata pacientes automaticamente (Rooms 1-6)",
    Value = false,
    Callback = function(state)
        Config.AutoHeal = state
        if state then RefreshItemCache() end
    end,
})

MainTab:Toggle({
    Title = "Auto Process",
    Description = "Processa DNA e analisa automaticamente em todo o mapa",
    Value = false,
    Callback = function(state)
        Config.AutoProcess = state
    end,
})

MainTab:Toggle({
    Title = "Instant Action",
    Description = "Remove tempo de espera dos prompts",
    Value = false,
    Callback = function(state)
        Config.InstantAction = state
        if state then
            for _, prompt in ipairs(Workspace:GetDescendants()) do
                if prompt:IsA("ProximityPrompt") then
                    pcall(function() prompt.HoldDuration = 0 end)
                end
            end
        end
    end,
})

MainTab:Toggle({
    Title = "Auto Room 6 (X-Ray)",
    Description = "Sequência: X-Ray -> 4 botões -> Process -> Badge -> Collect",
    Value = false,
    Callback = function(state)
        Config.AutoRoom6 = state
    end,
})

MainTab:Toggle({
    Title = "Auto Room 7",
    Description = "Interações automáticas no InBed da Room 7",
    Value = false,
    Callback = function(state)
        Config.AutoRoom7 = state
    end,
})

MainTab:Toggle({
    Title = "Auto Room 8",
    Description = "Sleep Patient automático no InBed da Room 8",
    Value = false,
    Callback = function(state)
        Config.AutoRoom8 = state
    end,
})

-- Tab Player
local PlayerTab = Window:Tab({
    Title = "Player",
    Icon = "user"
})

PlayerTab:Toggle({
    Title = "NoClip",
    Description = "Atravessa paredes e objetos",
    Value = false,
    Callback = function(state)
        Config.NoClip = state
    end,
})

PlayerTab:Slider({
    Title = "WalkSpeed",
    Description = "Velocidade do personagem",
    Value = 16,
    Min = 1,
    Max = 200,
    Callback = function(value)
        Config.WalkSpeed = value
    end,
})

PlayerTab:Toggle({
    Title = "Fly",
    Description = "Voar livremente pelo mapa",
    Value = false,
    Callback = function(state)
        if state then
            StartFly()
        else
            StopFly()
        end
    end,
})

PlayerTab:Slider({
    Title = "Fly Speed",
    Description = "Velocidade do voo",
    Value = 50,
    Min = 10,
    Max = 300,
    Callback = function(value)
        Config.FlySpeed = value
    end,
})

-- Tab Info
local InfoTab = Window:Tab({
    Title = "Info",
    Icon = "info"
})

InfoTab:Label("Silverfox Scripts | Hospital de Animais")
InfoTab:Label("Versao: v2.9.9")
InfoTab:Label("Executor: Delta Mobile")
InfoTab:Label("UI: WindUI")

InfoTab:Button({
    Title = "Resetar Velocidade",
    Description = "Volta para 16",
    Callback = function()
        Config.WalkSpeed = 16
        local hum = GetHumanoid()
        if hum then hum.WalkSpeed = 16 end
    end,
})

InfoTab:Button({
    Title = "Desativar Tudo",
    Description = "Desliga todas as funcoes",
    Callback = function()
        Config.AutoHeal = false
        Config.AutoProcess = false
        Config.InstantAction = false
        Config.AutoRoom6 = false
        Config.AutoRoom7 = false
        Config.AutoRoom8 = false
        Config.NoClip = false
        Config.WalkSpeed = 16
        StopFly()
        local hum = GetHumanoid()
        if hum then hum.WalkSpeed = 16 end
    end,
})

-- ==========================================
-- INICIALIZAÇÃO
-- ==========================================

print("=================================")
print("Silverfox Scripts | Hospital de Animais")
print("Versao: v2.9.9 Delta Mobile")
print("=================================")
