-- =====================================================================
-- ANIMAL HOSPITAL HUB v3.5 (COMPLETAMENTE REESCRITO)
-- CORRIGIDO: Auto Secretária, NoClip, Auto Shutters
-- Otimizado para Delta Executor - Mobile (Studio Lite Compliant)
-- =====================================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Camera = game:GetService("Workspace").CurrentCamera
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- CONFIGURAÇÕES GLOBAIS
-- ==========================================
if not _G.HospitalConfig then
    _G.HospitalConfig = {
        InstantAction = false,
        AutoProcess = false,
        AutoHeal = false,
        AutoRoom6 = false,
        AutoRoom7 = false,
        AutoRoom8 = false,
        AutoSecretaria = false,
        AutoShutter = false,
        AutoAnomaly = false,
        NoClip = false,
        WalkSpeed = 16,
        JumpPower = 50,
        AutoCameraFocus = true,
        NoFog = false,
        FPSBoost = false,
        FlyEnabled = false,
        FlySpeed = 50,
        HighlightsEnabled = false,
        KeepSanity = true
    }
end
local Config = _G.HospitalConfig
local OriginalCollisions = {}
local ItemDebounce = {}
local ITEM_PICKUP_COOLDOWN = 0.2

-- ==========================================
-- CACHE PARA ITENS
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
-- FUNÇÕES UTILITÁRIAS GLOBAIS
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
    if not root then return end
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
end

local function LookAtPosition(targetPosition)
    local root = GetRootPart()
    if root and targetPosition then
        pcall(function()
            root.CFrame = CFrame.lookAt(root.Position, targetPosition)
            if Config.AutoCameraFocus then
                local character = GetCharacter()
                if character then
                    local head = character:FindFirstChild("Head")
                    if head then
                        local camPos = head.Position - (root.CFrame.LookVector * 4) + Vector3.new(0, 2, 0)
                        Camera.CFrame = CFrame.lookAt(camPos, targetPosition)
                    end
                end
            end
        end)
    end
end

local function GetApproachPosition(targetPosition, distance)
    distance = distance or 3
    local root = GetRootPart()
    if not root or not targetPosition then return targetPosition end
    local diff = root.Position - targetPosition
    local dir
    if diff.Magnitude < 0.5 then
        dir = Vector3.new(0, 0, 1)
    else
        dir = Vector3.new(diff.X, 0, diff.Z)
        if dir.Magnitude < 0.1 then dir = Vector3.new(0, 0, 1) end
        dir = dir.Unit
    end
    return targetPosition + dir * distance
end

local function FirePromptDirect(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then return false end

    local targetPart = FindBasePartInObject(prompt.Parent)
    if targetPart then LookAtPosition(targetPart.Position) end

    if Config.InstantAction then prompt.HoldDuration = 0 end

    local success = false
    local s1 = pcall(function() fireproximityprompt(prompt) end)
    if s1 then success = true end

    if not success then
        local s2 = pcall(function()
            prompt:InputHoldStart(LocalPlayer)
            task.wait(0.05)
            prompt:InputHoldEnd(LocalPlayer)
        end)
        if s2 then success = true end
    end

    if not success then
        local s3 = pcall(function()
            local mouse = LocalPlayer:GetMouse()
            if mouse then
                local part = FindBasePartInObject(prompt.Parent)
                if part then mouse.Target = part; mouse.TargetClick:Fire() end
            end
        end)
        if s3 then success = true end
    end

    return success
end

local function ClickButton(buttonPart)
    if not buttonPart then return false end
    local clickDetector = buttonPart:FindFirstChildOfClass("ClickDetector")
    if clickDetector then
        LookAtPosition(buttonPart.Position)
        local success = pcall(function() fireclickdetector(clickDetector) end)
        if success then return true end
    end
    return false
end

local function HasItem(itemName)
    if not itemName or itemName == "" then return false end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and string.find(string.lower(tool.Name), string.lower(itemName)) then return true end
        end
    end
    local char = GetCharacter()
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") and string.find(string.lower(tool.Name), string.lower(itemName)) then return true end
        end
    end
    return false
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
-- FUNÇÕES DE LOCALIZAÇÃO DO MAPA
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

-- ==========================================
-- AUTO ROOM 6
-- ==========================================
local function GetButtonModels(colorsFolder)
    if not colorsFolder then return {} end
    local buttons = {}
    for _, model in ipairs(colorsFolder:GetChildren()) do
        if model:IsA("Model") and model:FindFirstChild("Button") then
            local btn = model:FindFirstChild("Button")
            if btn and btn:IsA("BasePart") then table.insert(buttons, btn) end
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
            if btn and btn:IsA("BasePart") then table.insert(colors, btn.Color) end
        end
    end
    return colors
end

local function CountChangedButtons(colorsFolder, initialColors)
    if not colorsFolder or not initialColors then return 0 end
    local currentColors = GetButtonColors(colorsFolder)
    local changed = 0
    for i = 1, math.min(#initialColors, #currentColors) do
        if initialColors[i] ~= currentColors[i] then changed = changed + 1 end
    end
    return changed
end

local function GetPromptByActionText(actionText, searchRoot)
    if not actionText or actionText == "" then return nil end
    if not searchRoot then searchRoot = Workspace end
    local targetText = string.lower(actionText)
    for _, desc in ipairs(searchRoot:GetDescendants()) do
        if desc:IsA("ProximityPrompt") and desc.Enabled and desc.ActionText then
            local lowerAction = string.lower(desc.ActionText)
            if string.find(lowerAction, targetText) or string.find(targetText, lowerAction) then return desc end
        end
    end
    return nil
end

local function AutoRoom6Sequence()
    local emergency = GetEmergencyRooms()
    if not emergency then return end
    local room6 = emergency:FindFirstChild("Room6")
    if not room6 then return end
    local minigame = room6:FindFirstChild("Minigame")
    if not minigame then return end

    print("[Room6] Iniciando...")

    -- Begin X-Ray
    local xrayMonitor = FindXrayMonitorInMinigame(room6)
    if xrayMonitor then
        local xrayPrompt = xrayMonitor:FindFirstChild("PP")
        if xrayPrompt and xrayPrompt:IsA("ProximityPrompt") and xrayPrompt.Enabled then
            local part = FindBasePartInObject(xrayMonitor)
            if part then
                print("[Room6] X-Ray...")
                SafeTeleport(part.Position)
                FirePromptDirect(xrayPrompt)
                task.wait(0.5)
            end
        end
    end

    -- Aguardar botões mudarem
    local colorsFolder = FindColorsInMinigame(room6)
    if not colorsFolder then print("[Room6] Colors nao encontrado!") return end

    local initialColors = GetButtonColors(colorsFolder)
    local buttons = GetButtonModels(colorsFolder)
    if #buttons < 4 then print("[Room6] Menos de 4 botoes!") return end

    print("[Room6] Aguardando botões mudarem...")
    local timeout = 0
    while timeout < 15 and CountChangedButtons(colorsFolder, initialColors) < 4 do
        task.wait(0.2)
        timeout = timeout + 0.2
    end

    task.wait(1.5)

    -- Clicar botões
    print("[Room6] Clicando botões...")
    for _, btn in ipairs(buttons) do
        if btn and btn:IsA("BasePart") then
            SafeTeleport(btn.Position + Vector3.new(0, 1, 2))
            LookAtPosition(btn.Position)
            task.wait(0.2)
            ClickButton(btn)
            task.wait(0.15)
        end
    end

    -- Process Results
    task.wait(0.5)
    local processPrompt = nil
    for i = 1, 30 do
        processPrompt = GetPromptByActionText("process", minigame)
        if processPrompt then break end
        task.wait(0.3)
    end
    if processPrompt then
        local part = FindBasePartInObject(processPrompt.Parent)
        if part then SafeTeleport(part.Position); FirePromptDirect(processPrompt) end
    end

    task.wait(0.5)

    -- Print Badge
    local printPrompt = nil
    for i = 1, 30 do
        printPrompt = GetPromptByActionText("print", minigame)
        if printPrompt then break end
        task.wait(0.3)
    end
    if printPrompt then
        local part = FindBasePartInObject(printPrompt.Parent)
        if part then SafeTeleport(part.Position); FirePromptDirect(printPrompt) end
    end

    task.wait(0.5)

    -- Collect
    local collectPrompt = nil
    for i = 1, 25 do
        collectPrompt = GetPromptByActionText("collect", Workspace)
        if collectPrompt then break end
        task.wait(0.3)
    end
    if collectPrompt then
        local part = FindBasePartInObject(collectPrompt.Parent)
        if part then SafeTeleport(part.Position); FirePromptDirect(collectPrompt) end
    end

    print("[Room6] Concluido!")
end

task.spawn(function()
    while true do
        RunService.Heartbeat:Wait()
        if Config.AutoRoom6 then AutoRoom6Sequence() task.wait(3) end
    end
end)

-- ==========================================
-- AUTO HEAL
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
                if desc:IsA("ProximityPrompt") and desc.Enabled then promptToDeliver = desc; break end
            end
            if not promptToDeliver then
                for _, desc in ipairs(bedPath.Parent:GetDescendants()) do
                    if desc:IsA("ProximityPrompt") and desc.Enabled then promptToDeliver = desc; break end
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
                    deliverPosition = FindBasePartInObject(npc) and FindBasePartInObject(npc).Position
                    break
                end
            end
        end
    end

    if #itemsNeeded == 0 or not promptToDeliver then return false end

    local holdingAllItems = true
    for _, itemName in ipairs(itemsNeeded) do
        local collected = HasItem(itemName)
        if not collected then
            local retryCount = 0
            while not collected and retryCount < 3 do
                if HasItem(itemName) then collected = true; break end
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
                            if HasItem(itemName) then collected = true; break end
                        end
                    end
                end
                retryCount = retryCount + 1
                task.wait(0.1)
            end
        end
        if not collected then holdingAllItems = false end
    end

    if holdingAllItems and deliverPosition then
        SafeTeleport(deliverPosition + Vector3.new(0, 1, 0))
        for _, itemName in ipairs(itemsNeeded) do
            if HasItem(itemName) then
                EquipToolFast(itemName)
                FirePromptDirect(promptToDeliver)
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
-- AUTO PROCESS GLOBAL
-- ==========================================
task.spawn(function()
    while true do
        RunService.Heartbeat:Wait()
        if Config.AutoProcess then
            for _, desc in ipairs(Workspace:GetDescendants()) do
                if desc:IsA("ProximityPrompt") and desc.Enabled and desc.ActionText then
                    local txt = string.lower(desc.ActionText)
                    if string.find(txt, "dna") or string.find(txt, "analyze") or string.find(txt, "process") then
                        local part = FindBasePartInObject(desc.Parent)
                        if part then SafeTeleport(part.Position); FirePromptDirect(desc) end
                    end
                end
            end
        end
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
                                    if part then SafeTeleport(part.Position); FirePromptDirect(prompt) end
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
                                if part then SafeTeleport(part.Position); FirePromptDirect(prompt) end
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ==========================================
-- HOOK PROMPTS
-- ==========================================
local function HookPrompt(prompt)
    if not prompt:IsA("ProximityPrompt") then return end
    if Config.InstantAction then prompt.HoldDuration = 0 end
end

Workspace.DescendantAdded:Connect(HookPrompt)
for _, p in ipairs(Workspace:GetDescendants()) do HookPrompt(p) end

-- ==========================================
-- NOCLIP CORRIGIDO
-- ==========================================
local function SaveOriginalCollisions()
    local char = GetCharacter()
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then OriginalCollisions[part] = part.CanCollide end
    end
end

local function RestoreOriginalCollisions()
    local char = GetCharacter()
    if not char then return end
    for part, canCollide in pairs(OriginalCollisions) do
        if part and part.Parent then part.CanCollide = canCollide end
    end
    OriginalCollisions = {}
end

local function ApplyNoClip()
    local char = GetCharacter()
    if not char then return end
    -- Salva só se ainda não salvou
    if next(OriginalCollisions) == nil then
        SaveOriginalCollisions()
    end
    -- Desativa colisão de TODAS as partes
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part.CanCollide = false end)
        end
    end
end

local function DisableNoClip()
    RestoreOriginalCollisions()
end

-- Loop de NoClip
task.spawn(function()
    while true do
        RunService.Heartbeat:Wait()
        local hum = GetHumanoid()
        if hum then
            hum.WalkSpeed = Config.WalkSpeed
            hum.UseJumpPower = true
            hum.JumpPower = Config.JumpPower
        end

        if Config.NoClip then
            ApplyNoClip()
        elseif next(OriginalCollisions) ~= nil then
            DisableNoClip()
        end

        if Config.NoFog then
            Lighting.FogEnd = 1e6
            Lighting.FogStart = 0
            for _, obj in ipairs(Lighting:GetChildren()) do
                if obj:IsA("Atmosphere") then
                    obj.Density = 0
                    obj.Offset = 0
                    obj.Glare = 0
                    obj.Haze = 0
                end
            end
        end
    end
end)

-- ==========================================
-- FPS BOOST
-- ==========================================
local FPSBoostCache = { effects = {}, globalShadows = nil }

local function ApplyFPSBoost()
    FPSBoostCache.globalShadows = Lighting.GlobalShadows
    Lighting.GlobalShadows = false
    for _, obj in ipairs(Lighting:GetDescendants()) do
        if obj:IsA("BloomEffect") or obj:IsA("SunRaysEffect")
            or obj:IsA("DepthOfFieldEffect") or obj:IsA("ColorCorrectionEffect")
            or obj:IsA("BlurEffect") then
            FPSBoostCache.effects[obj] = obj.Enabled
            obj.Enabled = false
        end
    end
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
end

local function RestoreFPSBoost()
    if FPSBoostCache.globalShadows ~= nil then Lighting.GlobalShadows = FPSBoostCache.globalShadows end
    for obj, wasEnabled in pairs(FPSBoostCache.effects) do
        if obj and obj.Parent then obj.Enabled = wasEnabled end
    end
    FPSBoostCache.effects = {}
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
end

-- ==========================================
-- FLY
-- ==========================================
local FlyBV, FlyBG, FlyConn = nil, nil, nil

local function GetFlyVelocity()
    local hum = GetHumanoid()
    if not hum then return Vector3.new(0, 0, 0) end
    local moveDir = hum.MoveDirection
    if moveDir.Magnitude < 0.05 then return Vector3.new(0, 0, 0) end
    local pitch = math.asin(math.clamp(Camera.CFrame.LookVector.Y, -1, 1))
    local horizontal = moveDir.Unit * math.cos(pitch)
    local vertical = Vector3.new(0, math.sin(pitch), 0)
    return (horizontal + vertical) * Config.FlySpeed * moveDir.Magnitude
end

local function StartFly()
    local root = GetRootPart()
    local hum = GetHumanoid()
    if not root or not hum then return end
    hum.PlatformStand = true
    FlyBV = Instance.new("BodyVelocity")
    FlyBV.Name = "HospitalHub_FlyBV"
    FlyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    FlyBV.Velocity = Vector3.new(0, 0, 0)
    FlyBV.Parent = root
    FlyBG = Instance.new("BodyGyro")
    FlyBG.Name = "HospitalHub_FlyBG"
    FlyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    FlyBG.D = 50
    FlyBG.P = 3000
    FlyBG.CFrame = root.CFrame
    FlyBG.Parent = root
    FlyConn = RunService.RenderStepped:Connect(function()
        if not Config.FlyEnabled or not FlyBV or not FlyBV.Parent then return end
        FlyBV.Velocity = GetFlyVelocity()
        local flatLook = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
        if flatLook.Magnitude > 0.01 then
            FlyBG.CFrame = CFrame.lookAt(root.Position, root.Position + flatLook)
        end
    end)
end

local function StopFly()
    if FlyConn then FlyConn:Disconnect() FlyConn = nil end
    if FlyBV then FlyBV:Destroy() FlyBV = nil end
    if FlyBG then FlyBG:Destroy() FlyBG = nil end
    local hum = GetHumanoid()
    if hum then hum.PlatformStand = false end
end

LocalPlayer.CharacterAdded:Connect(function()
    Config.FlyEnabled = false
    FlyBV, FlyBG = nil, nil
    OriginalCollisions = {}
end)

-- ==========================================
-- HIGHLIGHTS
-- ==========================================
local NPCHighlights = {}
local ANOMALY_KEYWORDS = {"anomaly", "anomalia", "hollow", "ghost", "shadow", "impostor", "fake", "visitor", "intruder", "threat"}

local HIGHLIGHT_PATIENT_COLOR = Color3.fromRGB(40, 255, 90)
local HIGHLIGHT_ANOMALY_COLOR = Color3.fromRGB(255, 40, 40)

local function IsAnomalyNPC(npc)
    if not npc then return false end
    local okAttr, isAnomalyAttr = pcall(function() return npc:GetAttribute("IsAnomaly") end)
    if okAttr and isAnomalyAttr == true then return true end
    local okType, typeAttr = pcall(function() return npc:GetAttribute("Type") end)
    if okType and typeAttr and string.find(string.lower(tostring(typeAttr)), "anomal") then return true end
    local lname = string.lower(npc.Name)
    for _, kw in ipairs(ANOMALY_KEYWORDS) do
        if string.find(lname, kw) then return true end
    end
    for _, desc in ipairs(npc:GetDescendants()) do
        if desc:IsA("Model") or desc:IsA("BasePart") then
            local dname = string.lower(desc.Name)
            for _, kw in ipairs(ANOMALY_KEYWORDS) do
                if string.find(dname, kw) then return true end
            end
        end
    end
    return false
end

local function ApplyNPCHighlight(npc)
    if not npc or not npc:IsA("Model") then return end
    local isAnomaly = IsAnomalyNPC(npc)
    local color = isAnomaly and HIGHLIGHT_ANOMALY_COLOR or HIGHLIGHT_PATIENT_COLOR
    local hl = NPCHighlights[npc]
    if hl and hl.Parent then
        hl.FillColor = color
        hl.OutlineColor = color
    else
        hl = Instance.new("Highlight")
        hl.Name = "HospitalHub_Highlight"
        hl.FillColor = color
        hl.OutlineColor = color
        hl.FillTransparency = 0.55
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = npc
        NPCHighlights[npc] = hl
    end
end

local function ClearAllHighlights()
    for npc, hl in pairs(NPCHighlights) do
        if hl then pcall(function() hl:Destroy() end) end
    end
    NPCHighlights = {}
end

task.spawn(function()
    while true do
        if Config.HighlightsEnabled then
            local npcsFolder = Workspace:FindFirstChild("NPCs")
            if npcsFolder then
                for _, npc in ipairs(npcsFolder:GetChildren()) do
                    if npc:IsA("Model") then ApplyNPCHighlight(npc) end
                end
            end
            for npc, hl in pairs(NPCHighlights) do
                if not npc.Parent then pcall(function() hl:Destroy() end); NPCHighlights[npc] = nil end
            end
        elseif next(NPCHighlights) then
            ClearAllHighlights()
        end
        task.wait(0.5)
    end
end)

-- ==========================================
-- AUTO SHUTTER (PERSIANAS)
-- ==========================================
task.spawn(function()
    while true do
        RunService.Heartbeat:Wait()
        if Config.AutoShutter then
            -- Procura o botão ShutterButton
            local misc = Workspace:FindFirstChild("Misc")
            if misc then
                local shutterButton = misc:FindFirstChild("ShutterButton")
                if shutterButton then
                    local pp = shutterButton:FindFirstChild("PP")
                    if pp and pp:IsA("ProximityPrompt") and pp.Enabled then
                        local part = FindBasePartInObject(shutterButton)
                        if part then
                            SafeTeleport(GetApproachPosition(part.Position, 3))
                            FirePromptDirect(pp)
                            task.wait(0.5)
                        end
                    else
                        -- Tenta ClickDetector
                        local clickDet = shutterButton:FindFirstChildOfClass("ClickDetector")
                        if clickDet then
                            local part = FindBasePartInObject(shutterButton)
                            if part then
                                SafeTeleport(GetApproachPosition(part.Position, 3))
                                pcall(function() fireclickdetector(clickDet) end)
                                task.wait(0.5)
                            end
                        end
                    end
                end
            end
            task.wait(0.5)
        else
            task.wait(0.5)
        end
    end
end)

-- ==========================================
-- AUTO ANOMALY
-- ==========================================
local function GetAnomalyNPC()
    local npcsFolder = Workspace:FindFirstChild("NPCs")
    if not npcsFolder then return nil, nil end
    local refPart = GetRootPart()
    if not refPart then return nil, nil end
    local bestModel, bestPart, bestDist = nil, nil, math.huge
    for _, npc in ipairs(npcsFolder:GetChildren()) do
        if npc:IsA("Model") and IsAnomalyNPC(npc) then
            local part = FindBasePartInObject(npc)
            if part then
                local hasEnabledPrompt = false
                for _, desc in ipairs(npc:GetDescendants()) do
                    if desc:IsA("ProximityPrompt") and desc.Enabled then hasEnabledPrompt = true; break end
                end
                if hasEnabledPrompt then
                    local dist = (part.Position - refPart.Position).Magnitude
                    if dist < bestDist then bestModel, bestPart, bestDist = npc, part, dist end
                end
            end
        end
    end
    return bestModel, bestPart
end

task.spawn(function()
    while true do
        RunService.Heartbeat:Wait()
        if Config.AutoAnomaly then
            local anomaly, anomalyPart = GetAnomalyNPC()
            if anomaly and anomalyPart then
                SafeTeleport(GetApproachPosition(anomalyPart.Position, 2))
                task.wait(0.2)
                for _, desc in ipairs(anomaly:GetDescendants()) do
                    if desc:IsA("ProximityPrompt") and desc.Enabled then
                        FirePromptDirect(desc)
                        break
                    end
                end
            end
            task.wait(1)
        end
    end
end)

-- ==========================================
-- SANIDADE
-- ==========================================
local SanityLib = nil
pcall(function()
    local libModule = ReplicatedStorage:WaitForChild("Lib", 5)
    if libModule then SanityLib = require(libModule) end
end)

local function KeepSanityFull()
    if not Config.KeepSanity then return end
    pcall(function() LocalPlayer:SetAttribute("Sanity", 100) end)
end

if SanityLib and SanityLib.Inject then
    pcall(function() SanityLib.Inject("PlayerLostSanity", KeepSanityFull) end)
end

LocalPlayer:GetAttributeChangedSignal("Sanity"):Connect(KeepSanityFull)
KeepSanityFull()

-- ==========================================
-- AUTO SECRETARIA v5 - COMPLETAMENTE REESCRITO
-- FLUXO CORRETO:
-- 1. Aguarda NPC com prompt habilitado
-- 2. Interage com NPC (carimba formulário)
-- 3. Camera (tira foto)
-- 4. Computer (registra)
-- 5. Printer (imprime)
-- 6. Pega Badge (VisitorBadgeBase ou PatientBadgeBase)
-- 7. Equipa e entrega badge ao NPC
-- ==========================================
if Config.AutoSecretaria == nil then Config.AutoSecretaria = false end

local RETRIES = 10
local WAIT_TIME = 0.5

-- Procura NPC esperando check-in
local function GetWaitingNPC()
    local npcsFolder = Workspace:FindFirstChild("NPCs")
    if not npcsFolder then return nil, nil end
    for _, npc in ipairs(npcsFolder:GetChildren()) do
        if npc:IsA("Model") then
            for _, desc in ipairs(npc:GetDescendants()) do
                if desc:IsA("ProximityPrompt") and desc.Enabled then
                    local part = FindBasePartInObject(npc)
                    return npc, part
                end
            end
        end
    end
    return nil, nil
end

-- Interage com objeto do CheckIn
local function InteractCheckInObject(objName)
    local misc = Workspace:FindFirstChild("Misc")
    if not misc then return false end
    local checkIn = misc:FindFirstChild("CheckIn")
    if not checkIn then return false end

    local obj = checkIn:FindFirstChild(objName)
    if not obj then return false end

    local pp = obj:FindFirstChildOfClass("ProximityPrompt")
    if not pp then return false end

    -- Espera o prompt ficar enabled
    local attempts = 0
    while not pp.Enabled and attempts < RETRIES do
        task.wait(0.3)
        attempts = attempts + 1
    end

    if not pp.Enabled then return false end

    local part = FindBasePartInObject(obj)
    if not part then return false end

    SafeTeleport(GetApproachPosition(part.Position, 3))
    task.wait(0.2)
    FirePromptDirect(pp)
    task.wait(0.5)
    return true
end

-- Pega o badge impresso
local function PickUpBadge()
    local misc = Workspace:FindFirstChild("Misc")
    if not misc then return false end
    local checkIn = misc:FindFirstChild("CheckIn")
    if not checkIn then return false end

    -- Tenta VisitorBadgeBase ou PatientBadgeBase
    local badgeNames = {"VisitorBadgeBase", "PatientBadgeBase"}
    for _, badgeName in ipairs(badgeNames) do
        local badge = checkIn:FindFirstChild(badgeName)
        if badge then
            local pp = badge:FindFirstChildOfClass("ProximityPrompt")
            if pp and pp.Enabled then
                local part = FindBasePartInObject(badge)
                if part then
                    SafeTeleport(GetApproachPosition(part.Position, 3))
                    task.wait(0.2)
                    FirePromptDirect(pp)
                    task.wait(0.5)
                    return true
                end
            end
        end
    end
    return false
end

-- Verifica se tem badge
local function HasBadge()
    for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") and (string.find(string.lower(tool.Name), "badge") or string.find(string.lower(tool.Name), "id")) then return true, tool.Name end
    end
    local char = GetCharacter()
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") and (string.find(string.lower(tool.Name), "badge") or string.find(string.lower(tool.Name), "id")) then return true, tool.Name end
        end
    end
    return false, nil
end

-- Entrega badge ao NPC
local function DeliverBadgeToNPC(npc)
    local hasBadge, badgeName = HasBadge()
    if not hasBadge then return false end

    -- Equipa o badge
    EquipToolFast(badgeName)
    task.wait(0.3)

    -- Teleporta pro NPC e interage
    local part = FindBasePartInObject(npc)
    if not part then return false end

    SafeTeleport(GetApproachPosition(part.Position, 3))
    task.wait(0.3)

    -- Procura prompt no NPC
    for _, desc in ipairs(npc:GetDescendants()) do
        if desc:IsA("ProximityPrompt") and desc.Enabled then
            FirePromptDirect(desc)
            task.wait(0.5)
            break
        end
    end

    return true
end

-- SEQUENCIA PRINCIPAL
local function AutoSecretariaSequence()
    print("[SECRETARIA] Iniciando ciclo...")

    -- PASSO 1: Aguarda NPC aparecer e interage com ele (carimbar)
    print("[SECRETARIA] 1. Aguardando NPC...")
    local npc, npcPart = nil, nil
    local attempts = 0
    while not npc and attempts < RETRIES do
        npc, npcPart = GetWaitingNPC()
        if not npc then
            task.wait(0.5)
            attempts = attempts + 1
        end
    end

    if not npc or not npcPart then
        print("[SECRETARIA] Nenhum NPC encontrado!")
        return
    end

    print("[SECRETARIA] NPC encontrado: " .. npc.Name)

    -- Teleporta e interage
    SafeTeleport(GetApproachPosition(npcPart.Position, 3))
    task.wait(0.3)

    for _, desc in ipairs(npc:GetDescendants()) do
        if desc:IsA("ProximityPrompt") and desc.Enabled then
            print("[SECRETARIA] 1. Carimbando formulario...")
            FirePromptDirect(desc)
            task.wait(0.5)
            break
        end
    end

    -- PASSO 2: Camera
    print("[SECRETARIA] 2. Tirando foto...")
    if not InteractCheckInObject("Camera") then
        print("[SECRETARIA] Camera falhou!")
    end
    task.wait(0.5)

    -- PASSO 3: Computer
    print("[SECRETARIA] 3. Registrando no computador...")
    if not InteractCheckInObject("Computer") then
        print("[SECRETARIA] Computer falhou!")
    end
    task.wait(0.5)

    -- PASSO 4: Printer
    print("[SECRETARIA] 4. Imprimindo badge...")
    if not InteractCheckInObject("Printer") then
        print("[SECRETARIA] Printer falhou!")
    end
    task.wait(2) -- Espera imprimir

    -- PASSO 5: Pegar Badge
    print("[SECRETARIA] 5. Pegando badge...")
    if not PickUpBadge() then
        print("[SECRETARIA] Falhou ao pegar badge!")
        return
    end
    task.wait(0.5)

    -- PASSO 6: Entregar Badge
    print("[SECRETARIA] 6. Entregando badge ao NPC...")
    if DeliverBadgeToNPC(npc) then
        print("[SECRETARIA] SUCESSO! Ciclo completo!")
    else
        print("[SECRETARIA] Falhou ao entregar badge!")
    end
end

-- Loop principal
task.spawn(function()
    while true do
        RunService.Heartbeat:Wait()
        if Config.AutoSecretaria then
            local ok, err = pcall(AutoSecretariaSequence)
            if not ok then warn("[SECRETARIA] Erro: " .. tostring(err)) end
            if Config.AutoSecretaria then task.wait(2) end
        else
            task.wait(0.5)
        end
    end
end)

-- ==========================================
-- INTERFACE GRÁFICA (WindUI)
-- ==========================================
local WindUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"
))()

pcall(function()
    local soundId
    if getcustomasset then
        local resp = game:HttpGet("https://files.catbox.moe/j4f9lt.mp3")
        writefile("HospitalHub_open.mp3", resp)
        soundId = getcustomasset("HospitalHub_open.mp3")
    end
    if soundId then
        local OpenSound = Instance.new("Sound")
        OpenSound.SoundId = soundId
        OpenSound.Looped = false
        OpenSound.Volume = 1
        OpenSound.Parent = Workspace
        OpenSound:Play()
        game.Debris:AddItem(OpenSound, 15)
    end
end)

local Window = WindUI:CreateWindow({
    Title = "🦊 SILVERFOX | HOSPITAL DE ANIMAIS",
    Icon = "https://files.catbox.moe/0mg5gr.jpg",
    Author = "v3.5 | FelpzSystem",
    Theme = "Dark",
})

-- ==========================================
-- TAB: PRINCIPAL
-- ==========================================
local MainTab = Window:Tab({ Title = "Principal", Icon = "home" })

MainTab:Paragraph({
    Title = "🧠 Sobrevivência",
    Desc = "Mantém sua sanidade sempre no máximo",
})

MainTab:Toggle({
    Title = "Manter Sanidade Cheia",
    Desc = "Já vem ativado — trava a sanidade em 100",
    Value = Config.KeepSanity,
    Callback = function(state)
        Config.KeepSanity = state
        if state then KeepSanityFull() end
    end,
})

MainTab:Paragraph({
    Title = "⚙️ Automações",
    Desc = "Ative o que precisar.",
})

MainTab:Toggle({
    Title = "Auto Processamento Global",
    Desc = "Procura DNA/Process/Analyze em todas as salas",
    Value = Config.AutoProcess,
    Callback = function(state) Config.AutoProcess = state end,
})

MainTab:Toggle({
    Title = "Auto Room 6 (X-Ray)",
    Desc = "Sequência completa do Room 6",
    Value = Config.AutoRoom6,
    Callback = function(state) Config.AutoRoom6 = state end,
})

MainTab:Toggle({
    Title = "Auto Room 7",
    Desc = "Auto interações Room 7",
    Value = Config.AutoRoom7,
    Callback = function(state) Config.AutoRoom7 = state end,
})

MainTab:Toggle({
    Title = "Auto Room 8",
    Desc = "Auto interações Room 8",
    Value = Config.AutoRoom8,
    Callback = function(state) Config.AutoRoom8 = state end,
})

MainTab:Toggle({
    Title = "Auto Atendimento (Heal)",
    Desc = "Coleta itens e trata pacientes",
    Value = Config.AutoHeal,
    Callback = function(state)
        Config.AutoHeal = state
        if state then RefreshItemCache() end
    end,
})

MainTab:Paragraph({
    Title = "🗂️ SECRETARIA (Check-In)",
    Desc = "Fluxo completo: NPC → Camera → Computer → Printer → Badge → Entregar",
})

MainTab:Toggle({
    Title = "Auto Secretária",
    Desc = "Check-in automático de pacientes",
    Value = Config.AutoSecretaria,
    Callback = function(state) Config.AutoSecretaria = state end,
})

MainTab:Paragraph({
    Title = "🚪 Persianas & Anomalias",
    Desc = "Controle de shutters e anomalias",
})

MainTab:Toggle({
    Title = "Auto Fechar Persianas",
    Desc = "Fecha as persianas automaticamente (ShutterButton)",
    Value = Config.AutoShutter,
    Callback = function(state) Config.AutoShutter = state end,
})

MainTab:Toggle({
    Title = "Auto Anomalia",
    Desc = "Encontra e trata anomalias automaticamente",
    Value = Config.AutoAnomaly,
    Callback = function(state) Config.AutoAnomaly = state end,
})

-- ==========================================
-- TAB: UTILIDADES
-- ==========================================
local UtilitiesTab = Window:Tab({ Title = "Utilidades", Icon = "wrench" })

UtilitiesTab:Paragraph({
    Title = "🏃 Movimentação",
    Desc = "Velocidade e NoClip",
})

UtilitiesTab:Input({
    Title = "Velocidade",
    Placeholder = "Digite 1-200",
    Value = tostring(Config.WalkSpeed),
    Callback = function(value)
        local s = tonumber(value)
        if s and s > 0 and s < 200 then
            Config.WalkSpeed = s
            local hum = GetHumanoid()
            if hum then hum.WalkSpeed = s end
        end
    end,
})

UtilitiesTab:Toggle({
    Title = "NoClip",
    Desc = "Atravessa paredes - CORRIGIDO!",
    Value = Config.NoClip,
    Callback = function(state)
        Config.NoClip = state
        if not state then DisableNoClip() end
    end,
})

UtilitiesTab:Input({
    Title = "Força do Pulo",
    Placeholder = "Digite 1-300",
    Value = tostring(Config.JumpPower),
    Callback = function(value)
        local j = tonumber(value)
        if j and j > 0 and j < 300 then
            Config.JumpPower = j
            local hum = GetHumanoid()
            if hum then hum.JumpPower = j end
        end
    end,
})

UtilitiesTab:Button({
    Title = "🔄 Resetar Velocidade",
    Callback = function()
        Config.WalkSpeed = 16
        local hum = GetHumanoid()
        if hum then hum.WalkSpeed = 16 end
    end,
})

UtilitiesTab:Paragraph({
    Title = "🕊️ Voo",
    Desc = "Fly - olhe pra cima/baixo com a câmera",
})

UtilitiesTab:Toggle({
    Title = "Fly (Voar)",
    Desc = "Modo de voo livre",
    Value = Config.FlyEnabled,
    Callback = function(state)
        Config.FlyEnabled = state
        if state then StartFly() else StopFly() end
    end,
})

UtilitiesTab:Input({
    Title = "Velocidade de Voo",
    Placeholder = "10-300",
    Value = tostring(Config.FlySpeed),
    Callback = function(value)
        local s = tonumber(value)
        if s and s > 0 then Config.FlySpeed = s end
    end,
})

-- ==========================================
-- TAB: VISUAL
-- ==========================================
local VisualTab = Window:Tab({ Title = "Visual", Icon = "eye" })

VisualTab:Paragraph({
    Title = "🎥 Câmera & Interação",
    Desc = "Configurações de câmera",
})

VisualTab:Toggle({
    Title = "Interação Instantânea",
    Desc = "HoldDuration = 0 em todos os prompts",
    Value = Config.InstantAction,
    Callback = function(state)
        Config.InstantAction = state
        if state then
            for _, prompt in ipairs(Workspace:GetDescendants()) do
                if prompt:IsA("ProximityPrompt") then prompt.HoldDuration = 0 end
            end
        end
    end,
})

VisualTab:Toggle({
    Title = "Foco de Câmera Automático",
    Desc = "Move a câmera pro alvo",
    Value = Config.AutoCameraFocus,
    Callback = function(state) Config.AutoCameraFocus = state end,
})

VisualTab:Paragraph({
    Title = "🌫️ Renderização",
    Desc = "Visibilidade e performance",
})

VisualTab:Toggle({
    Title = "Remover Fog",
    Desc = "Remove névoa",
    Value = Config.NoFog,
    Callback = function(state)
        Config.NoFog = state
    end,
})

VisualTab:Toggle({
    Title = "FPS Boost",
    Desc = "Melhora performance",
    Value = Config.FPSBoost,
    Callback = function(state)
        Config.FPSBoost = state
        if state then ApplyFPSBoost() else RestoreFPSBoost() end
    end,
})

VisualTab:Paragraph({
    Title = "🎯 Highlights",
    Desc = "Verde = paciente | Vermelho = anomalia",
})

VisualTab:Toggle({
    Title = "Highlights de NPC",
    Desc = "Contorna NPCs com cor",
    Value = Config.HighlightsEnabled,
    Callback = function(state)
        Config.HighlightsEnabled = state
        if not state then ClearAllHighlights() end
    end,
})

-- ==========================================
-- TAB: MISC
-- ==========================================
local MiscTab = Window:Tab({ Title = "Misc", Icon = "more-horizontal" })

MiscTab:Button({
    Title = "📋 Copiar link do grupo",
    Callback = function()
        pcall(function() setclipboard("https://chat.whatsapp.com/HLYG7uoa4n7576WlnHngFb") end)
    end,
})

MiscTab:Button({
    Title = "🛑 Desativar Tudo",
    Callback = function()
        Config.InstantAction = false
        Config.AutoProcess = false
        Config.AutoRoom6 = false
        Config.AutoRoom7 = false
        Config.AutoRoom8 = false
        Config.AutoHeal = false
        Config.AutoSecretaria = false
        Config.AutoShutter = false
        Config.AutoAnomaly = false
        Config.NoClip = false
        Config.HighlightsEnabled = false
        Config.NoFog = false
        Config.FPSBoost = false
        Config.FlyEnabled = false
        DisableNoClip()
        RestoreFPSBoost()
        StopFly()
        ClearAllHighlights()
        Config.WalkSpeed = 16
        Config.JumpPower = 50
        local hum = GetHumanoid()
        if hum then hum.WalkSpeed = 16; hum.JumpPower = 50 end
        print("🛑 Todas as automações foram desativadas.")
    end,
})

-- ==========================================
-- TAB: SOBRE
-- ==========================================
local AboutTab = Window:Tab({ Title = "Sobre", Icon = "info" })

AboutTab:Paragraph({
    Title = "🦊 SILVERFOX | HOSPITAL DE ANIMAIS",
    Desc = "Obrigado por confiar no nosso trabalho!\n\nHub feito com carinho para Animal Hospital.",
})

AboutTab:Paragraph({
    Title = "✨ Versão & Créditos",
    Desc = "Versão: v3.5\nCriador: FelpzSystem\nExecutor: Delta",
})

AboutTab:Paragraph({
    Title = "⚡ Novidades v3.5",
    Desc = "✅ COMPLETAMENTE REESCRITO: Auto Secretária\n"
        .. "✅ NOCLIP CORRIGIDO - agora funciona!\n"
        .. "✅ AUTO SHUTTERS - fecha persianas\n"
        .. "✅ Auto Rooms 6, 7, 8\n"
        .. "✅ Highlights, Fly, FPS Boost\n"
        .. "✅ Manter Sanidade Cheia",
})

print("🚀 [SILVERFOX | HOSPITAL DE ANIMAIS v3.5] Carregado!")
