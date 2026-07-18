-- =====================================================================
-- ANIMAL HOSPITAL HUB v3.1 (ULTRA FAST - OMNI LOOK-AT TARGET)
-- Otimizado para Delta Executor - Mobile (Studio Lite Compliant)
-- Cores: Dark, Crimson Red (Vermelho Escuro)
-- SISTEMA DE FOCO VISUAL GLOBAL PARA TODOS OS PROXIMITYPROMPTS
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

-- Configurações Globais
if not _G.HospitalConfig then
    _G.HospitalConfig = {
        InstantAction = false,
        AutoProcess = false,
        AutoHeal = false,
        AutoRoom6 = false,
        AutoRoom7 = false,
        AutoRoom8 = false,
        AutoSecretaria = false,
        NoClip = false,
        WalkSpeed = 16,
        JumpPower = 50,
        AutoCameraFocus = true,
        NoFog = false,
        FPSBoost = false,
        FlyEnabled = false,
        FlySpeed = 50,
        HighlightsEnabled = false
    }
end
local Config = _G.HospitalConfig
local PromptConnections = {}
local OriginalCollisions = {}

-- Estruturas de controle ultra velozes
local ItemDebounce = {}
local ITEM_PICKUP_COOLDOWN = 0.2

-- ==========================================
-- CACHE PARA ITENS (OTIMIZAÇÃO)
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
    local success, err = pcall(function()
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

-- Calcula uma posição de aproximação a alguns studs de distância do alvo,
-- em vez de teleportar exatamente em cima dele (evita colisão/empurrão físico
-- contra NPCs e objetos, que é a causa mais comum de prompts "falharem").
local function GetApproachPosition(targetPosition, distance)
    distance = distance or 3
    local root = GetRootPart()
    if not root or not targetPosition then return targetPosition end

    local diff = root.Position - targetPosition
    local dir
    if diff.Magnitude < 0.5 then
        -- Já muito perto/sobreposto: usa uma direção padrão pra sair de cima do alvo
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
    if targetPart then
        LookAtPosition(targetPart.Position)
    end
    
    if Config.InstantAction then prompt.HoldDuration = 0 end
    
    local success = false
    
    local s1, e1 = pcall(function()
        fireproximityprompt(prompt)
    end)
    if s1 then success = true end
    
    if not success then
        local s2, e2 = pcall(function()
            prompt:InputHoldStart(LocalPlayer)
            task.wait(0.05)
            prompt:InputHoldEnd(LocalPlayer)
        end)
        if s2 then success = true end
    end
    
    if not success then
        local s3, e3 = pcall(function()
            local mouse = LocalPlayer:GetMouse()
            if mouse then
                local part = FindBasePartInObject(prompt.Parent)
                if part then
                    mouse.Target = part
                    mouse.TargetClick:Fire()
                end
            end
        end)
        if s3 then success = true end
    end
    
    return success
end

local function FirePromptWithCamera(prompt, targetPosition)
    if not prompt or not prompt:IsA("ProximityPrompt") then return false end
    if targetPosition then
        LookAtPosition(targetPosition)
    end
    return FirePromptDirect(prompt)
end

local function ClickButton(buttonPart)
    if not buttonPart then return false end
    local clickDetector = buttonPart:FindFirstChildOfClass("ClickDetector")
    if clickDetector then
        LookAtPosition(buttonPart.Position)
        local success, err = pcall(function() fireclickdetector(clickDetector) end)
        if success then return true end
    end
    return false
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
-- FUNÇÕES ESPECÍFICAS PARA ROOM 6
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

-- ==========================================
-- AUTO ROOM 6 CORRIGIDO (SEQUÊNCIA COMPLETA)
-- ==========================================

local function AutoRoom6Sequence()
    local emergency = GetEmergencyRooms()
    if not emergency then return end
    
    local room6 = emergency:FindFirstChild("Room6")
    if not room6 then return end
    
    local minigame = room6:FindFirstChild("Minigame")
    if not minigame then return end
    
    print("🔄 Iniciando Auto Room 6...")
    
    -- ==========================================
    -- PASSO 1: Begin X-Ray
    -- ==========================================
    local xrayMonitor = FindXrayMonitorInMinigame(room6)
    if xrayMonitor then
        local xrayPrompt = xrayMonitor:FindFirstChild("PP")
        if xrayPrompt and xrayPrompt:IsA("ProximityPrompt") and xrayPrompt.Enabled then
            local part = FindBasePartInObject(xrayMonitor)
            if part then
                print("📸 Interagindo com Begin X-Ray...")
                SafeTeleport(part.Position)
                FirePromptWithCamera(xrayPrompt, part.Position)
                wait(0.5)
            end
        end
    end
    
    -- ==========================================
    -- PASSO 2: Aguardar 4 botões mudarem de cor
    -- ==========================================
    local colorsFolder = FindColorsInMinigame(room6)
    if not colorsFolder then
        print("❌ Pasta Colors não encontrada!")
        return
    end
    
    local initialColors = GetButtonColors(colorsFolder)
    local buttons = GetButtonModels(colorsFolder)
    
    if #buttons < 4 then
        print("❌ Menos de 4 botões encontrados!")
        return
    end
    
    print("🎨 Aguardando 4 botões mudarem de cor...")
    local timeout = 0
    local changedCount = 0
    local maxWaitTime = 15 -- 15 segundos de timeout
    
    while timeout < maxWaitTime and changedCount < 4 do
        wait(0.2)
        changedCount = CountChangedButtons(colorsFolder, initialColors)
        timeout = timeout + 0.2
    end
    
    print("✅ " .. changedCount .. " botões mudaram de cor (esperado: 4)")
    
    -- ==========================================
    -- PASSO 3: Esperar 1.5 segundos
    -- ==========================================
    print("⏳ Aguardando 1.5 segundos...")
    wait(1.5)
    
    -- ==========================================
    -- PASSO 4: Clicar nos 4 botões (um por um com foco)
    -- ==========================================
    print("🔘 Clicando nos botões...")
    local clickedCount = 0
    for _, btn in ipairs(buttons) do
        if btn and btn:IsA("BasePart") then
            SafeTeleport(btn.Position + Vector3.new(0, 1, 2))
            LookAtPosition(btn.Position)
            wait(0.2)
            if ClickButton(btn) then
                clickedCount = clickedCount + 1
                print("✅ Botão " .. clickedCount .. " clicado")
            end
            wait(0.15)
        end
    end
    print("✅ " .. clickedCount .. " botões clicados")
    
    -- ==========================================
    -- PASSO 5: Aguardar e interagir com "Process Results"
    -- ==========================================
    print("⏳ Aguardando 'Process Results'...")
    local processPrompt = nil
    local processTimeout = 0
    
    while processTimeout < 10 do
        processPrompt = GetPromptByActionText("process results", minigame)
        if processPrompt then break end
        wait(0.3)
        processTimeout = processTimeout + 0.3
    end
    
    if processPrompt then
        local part = FindBasePartInObject(processPrompt.Parent)
        if part then
            print("📄 Interagindo com Process Results...")
            SafeTeleport(part.Position)
            FirePromptWithCamera(processPrompt, part.Position)
            wait(0.5)
        end
    else
        print("⚠️ 'Process Results' não encontrado!")
    end
    
    -- ==========================================
    -- PASSO 6: Aguardar e interagir com "Print Badge"
    -- ==========================================
    print("⏳ Aguardando 'Print Badge'...")
    local printBadgePrompt = nil
    local badgeTimeout = 0
    
    while badgeTimeout < 10 do
        printBadgePrompt = GetPromptByActionText("print badge", minigame)
        if printBadgePrompt then break end
        wait(0.3)
        badgeTimeout = badgeTimeout + 0.3
    end
    
    if printBadgePrompt then
        local part = FindBasePartInObject(printBadgePrompt.Parent)
        if part then
            print("🖨️ Interagindo com Print Badge...")
            SafeTeleport(part.Position)
            FirePromptWithCamera(printBadgePrompt, part.Position)
            wait(0.5)
        end
    else
        print("⚠️ 'Print Badge' não encontrado!")
    end
    
    -- ==========================================
    -- PASSO 7: Procurar "Collect" no Workspace
    -- ==========================================
    print("🔍 Procurando 'Collect' no Workspace...")
    local collectPrompt = nil
    local collectTimeout = 0
    
    while collectTimeout < 8 do
        collectPrompt = GetPromptByActionText("collect", Workspace)
        if collectPrompt then break end
        wait(0.3)
        collectTimeout = collectTimeout + 0.3
    end
    
    if collectPrompt then
        local part = FindBasePartInObject(collectPrompt.Parent)
        if part then
            print("📦 Interagindo com Collect...")
            SafeTeleport(part.Position)
            FirePromptWithCamera(collectPrompt, part.Position)
            wait(0.3)
        end
    else
        print("⚠️ 'Collect' não encontrado!")
    end
    
    print("✅ Auto Room 6 concluído com sucesso!")
end

-- Loop principal do Auto Room 6
task.spawn(function()
    while true do
        RunService.Heartbeat:Wait()
        if Config.AutoRoom6 then
            AutoRoom6Sequence()
            print("⏳ Aguardando 3 segundos antes de reiniciar...")
            wait(3)
        end
    end
end)

-- ==========================================
-- AUTO HEAL CORRIGIDO (COM VALIDAÇÃO E RETRY)
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
            if not promptToDeliver then
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
                    deliverPosition = FindBasePartInObject(npc) and FindBasePartInObject(npc).Position
                    break
                end
            end
        end
    end

    if #itemsNeeded == 0 or not promptToDeliver then return false end
    
    -- FASE 1: Coleta de itens (com retry e validação)
    local holdingAllItems = true
    local maxRetries = 3
    
    for _, itemName in ipairs(itemsNeeded) do
        local retryCount = 0
        local collected = HasItem(itemName)
        
        while not collected and retryCount < maxRetries do
            if HasItem(itemName) then
                collected = true
                break
            end
            
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
        
        if not collected then
            holdingAllItems = false
        end
    end
    
    -- FASE 2: Entrega ao paciente
    if holdingAllItems and deliverPosition then
        SafeTeleport(deliverPosition + Vector3.new(0, 1, 0))
        
        for _, itemName in ipairs(itemsNeeded) do
            if HasItem(itemName) then
                EquipToolFast(itemName)
                local deliverSuccess = false
                for i = 1, 3 do
                    if FirePromptDirect(promptToDeliver) then
                        deliverSuccess = true
                        break
                    end
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
-- AUTO PROCESS GLOBAL (TODAS AS SALAS)
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
    end
end)

-- ==========================================
-- AUTO ROOM 7
-- ==========================================

local function AutoRoom7Loop()
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
end

-- ==========================================
-- AUTO ROOM 8
-- ==========================================

local function AutoRoom8Loop()
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
end

-- ==========================================
-- HOOK PROMPTS & NOCLIP
-- ==========================================

local function HookPrompt(prompt)
    if not prompt:IsA("ProximityPrompt") then return end
    if Config.InstantAction then prompt.HoldDuration = 0 end
end

Workspace.DescendantAdded:Connect(HookPrompt)
for _, p in ipairs(Workspace:GetDescendants()) do HookPrompt(p) end

local function SaveOriginalCollisions()
    local char = GetCharacter()
    if not char or next(OriginalCollisions) ~= nil then return end
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
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.CanCollide = not Config.NoClip
        end
    end
end

RunService.Heartbeat:Connect(function()
    local hum = GetHumanoid()
    if hum then
        hum.WalkSpeed = Config.WalkSpeed
        hum.UseJumpPower = true
        hum.JumpPower = Config.JumpPower
    end
    if Config.NoClip then
        SaveOriginalCollisions()
        ApplyNoClip()
    else
        RestoreOriginalCollisions()
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
end)

task.spawn(AutoRoom7Loop)
task.spawn(AutoRoom8Loop)

-- ==========================================
-- REMOVER FOG (mantém estado original pra restaurar ao desativar)
-- ==========================================
local FogOriginal = nil

local function EnableNoFog()
    if not FogOriginal then
        FogOriginal = { FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart }
    end
    Config.NoFog = true
end

local function DisableNoFog()
    Config.NoFog = false
    if FogOriginal then
        Lighting.FogEnd = FogOriginal.FogEnd
        Lighting.FogStart = FogOriginal.FogStart
    end
end

-- ==========================================
-- FPS BOOST (desliga efeitos pesados de Lighting, reversível)
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
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
end

local function RestoreFPSBoost()
    if FPSBoostCache.globalShadows ~= nil then
        Lighting.GlobalShadows = FPSBoostCache.globalShadows
    end
    for obj, wasEnabled in pairs(FPSBoostCache.effects) do
        if obj and obj.Parent then obj.Enabled = wasEnabled end
    end
    FPSBoostCache.effects = {}
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
    end)
end

-- ==========================================
-- FLY (voo) — usa a direção do analógico/WASD relativa à câmera, e o ângulo
-- vertical da câmera pra subir/descer (funciona em PC, mobile e gamepad
-- sem precisar de tecla extra pra "subir")
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
end)

-- ==========================================
-- HIGHLIGHTS — verde no paciente, vermelho na anomalia/visitor
-- OBS: o jogo não expõe uma flag clara de "anomalia" nos dumps que recebi,
-- então a detecção abaixo usa Attributes comuns (IsAnomaly / Type) OU
-- palavras-chave no nome do NPC. Se sua anomalia tiver outro nome/atributo,
-- me diga o nome exato (ou o Attribute usado) que eu ajusto a lista.
-- ==========================================
local NPCHighlights = {}
local ANOMALY_KEYWORDS = { "anomaly", "anomalia", "hollow", "ghost", "shadow", "impostor", "imposter", "fake" }

local HIGHLIGHT_PATIENT_COLOR = Color3.fromRGB(40, 255, 90)   -- verde
local HIGHLIGHT_ANOMALY_COLOR = Color3.fromRGB(255, 40, 40)   -- vermelho

local function IsAnomalyNPC(npc)
    local okAttr, isAnomalyAttr = pcall(function() return npc:GetAttribute("IsAnomaly") end)
    if okAttr and isAnomalyAttr == true then return true end

    local okType, typeAttr = pcall(function() return npc:GetAttribute("Type") end)
    if okType and typeAttr and string.find(string.lower(tostring(typeAttr)), "anomal") then return true end

    local lname = string.lower(npc.Name)
    for _, kw in ipairs(ANOMALY_KEYWORDS) do
        if string.find(lname, kw) then return true end
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
                    if npc:IsA("Model") then
                        ApplyNPCHighlight(npc)
                    end
                end
            end
            -- limpa highlights de NPCs que já saíram do jogo
            for npc, hl in pairs(NPCHighlights) do
                if not npc.Parent then
                    pcall(function() hl:Destroy() end)
                    NPCHighlights[npc] = nil
                end
            end
        elseif next(NPCHighlights) then
            ClearAllHighlights()
        end
        task.wait(0.5)
    end
end)

-- ==========================================
-- AUTO SECRETARIA (CHECK-IN) v3 - baseado na estrutura REAL do jogo
-- (Workspace.Misc.CheckIn): Camera -> Computer -> Printer (aguarda 1.5s) ->
-- Pegar Crachá (VisitorBadgeBase / PatientBadgeBase) -> Entregar ao NPC
-- ==========================================
if Config.AutoSecretaria == nil then Config.AutoSecretaria = false end

local PRINTER_WAIT_TIME = 1.5    -- tempo pra impressora terminar de imprimir
local STEP_RETRIES = 5           -- tentativas por etapa antes de desistir
local BADGE_ITEM_NAMES = { "badge", "crachá", "cracha", "id" }
local BADGE_BASE_NAMES = { "VisitorBadgeBase", "PatientBadgeBase" } -- nomes reais no jogo

local function GetCheckInFolder()
    local misc = Workspace:FindFirstChild("Misc")
    if not misc then return nil end
    return misc:FindFirstChild("CheckIn")
end

-- Sempre busca de novo (não guarda referência velha) pra pegar o prompt atualizado a cada tentativa
local function GetCheckInPrompt(stepName)
    local checkIn = GetCheckInFolder()
    if not checkIn then return nil end
    local obj = checkIn:FindFirstChild(stepName)
    if not obj then return nil end
    if obj:IsA("ProximityPrompt") then return obj end
    return obj:FindFirstChildOfClass("ProximityPrompt")
end

-- Interage repetidamente com uma etapa do check-in até funcionar (ou esgotar tentativas)
local function DoCheckInStep(stepName, label, waitAfter)
    waitAfter = waitAfter or 0.6
    for attempt = 1, STEP_RETRIES do
        if not Config.AutoSecretaria then return false end

        local prompt = GetCheckInPrompt(stepName)
        if prompt and prompt.Enabled then
            local part = FindBasePartInObject(prompt.Parent)
            if part then
                print("📋 Secretária: " .. label .. " (tentativa " .. attempt .. ")...")
                SafeTeleport(GetApproachPosition(part.Position, 3))
                local ok = FirePromptWithCamera(prompt, part.Position)
                task.wait(waitAfter)
                if ok then return true end
            end
        else
            -- Prompt pode já ter sido consumido por outra tentativa; considera concluído
            if attempt > 1 then return true end
        end

        task.wait(0.3)
    end
    print("⚠️ Secretária: não foi possível concluir '" .. label .. "' após " .. STEP_RETRIES .. " tentativas.")
    return false
end

-- Acha o paciente que está esperando check-in: prioriza NPCs próximos do balcão com prompt habilitado
local function GetWaitingPatient()
    local checkIn = GetCheckInFolder()
    local refPart = checkIn and FindBasePartInObject(checkIn)
    if not refPart then refPart = GetRootPart() end
    if not refPart then return nil end

    local npcsFolder = Workspace:FindFirstChild("NPCs")
    if not npcsFolder then return nil end

    local bestModel, bestPart, bestDist = nil, nil, math.huge
    for _, npc in ipairs(npcsFolder:GetChildren()) do
        if npc:IsA("Model") then
            local hasEnabledPrompt = false
            for _, desc in ipairs(npc:GetDescendants()) do
                if desc:IsA("ProximityPrompt") and desc.Enabled then
                    hasEnabledPrompt = true
                    break
                end
            end
            if hasEnabledPrompt then
                local part = FindBasePartInObject(npc)
                if part then
                    local dist = (part.Position - refPart.Position).Magnitude
                    if dist < bestDist then
                        bestModel, bestPart, bestDist = npc, part, dist
                    end
                end
            end
        end
    end

    return bestModel, bestPart
end

local function HasBadgeItem()
    for _, name in ipairs(BADGE_ITEM_NAMES) do
        if HasItem(name) then return true, name end
    end
    return false, nil
end

-- Acha o prompt de pegar o crachá já impresso, testando os dois nomes reais
-- que o jogo usa (visitante ou paciente, dependendo do tipo de check-in atual)
local function GetPrintedBadgePrompt()
    for _, baseName in ipairs(BADGE_BASE_NAMES) do
        local prompt = GetCheckInPrompt(baseName)
        if prompt and prompt.Enabled then return prompt end
    end
    return nil
end

-- Pega o crachá impresso, validando que o item realmente foi pro inventário (com retry)
local function PickUpPrintedBadge()
    local already, _ = HasBadgeItem()
    if already then return true end

    for attempt = 1, STEP_RETRIES do
        if not Config.AutoSecretaria then return false end

        local prompt = GetPrintedBadgePrompt()
        if prompt then
            local part = FindBasePartInObject(prompt.Parent)
            if part then
                print("🪪 Secretária: pegando crachá (" .. prompt.Parent.Name .. ") tentativa " .. attempt .. "...")
                SafeTeleport(GetApproachPosition(part.Position, 3))
                FirePromptWithCamera(prompt, part.Position)
                task.wait(0.4)
            end
        end

        local got, _ = HasBadgeItem()
        if got then return true end
        task.wait(0.3)
    end

    print("⚠️ Secretária: crachá impresso não encontrado no inventário após tentativas.")
    return false
end

-- Entrega o crachá ao paciente que está esperando (equipa o item e interage com o NPC)
local function DeliverBadgeToPatient()
    -- Equipa o crachá ANTES de se aproximar: em muitos jogos o prompt de entrega
    -- só fica Enabled no NPC quando o jogador já está com o item na mão
    local hasBadge, badgeName = HasBadgeItem()
    if hasBadge and badgeName then
        EquipToolFast(badgeName)
        task.wait(0.15)
    end

    for attempt = 1, STEP_RETRIES do
        if not Config.AutoSecretaria then return false end

        -- Busca de novo a cada tentativa: o NPC "esperando" pode mudar,
        -- e o prompt só existe/habilita perto do jogador com o crachá equipado
        local npcModel, patientPart = GetWaitingPatient()
        if not npcModel or not patientPart then
            print("⚠️ Secretária: procurando paciente aguardando... (tentativa " .. attempt .. ")")
            task.wait(0.4)
        else
            -- Aproxima a poucos studs do NPC em vez de teleportar em cima dele:
            -- teleportar exatamente na posição do NPC causa colisão física e
            -- empurra o jogador para longe antes do prompt disparar (bug comum)
            SafeTeleport(GetApproachPosition(patientPart.Position, 3))
            LookAtPosition(patientPart.Position)
            task.wait(0.25)

            local bestPrompt = nil
            for _, desc in ipairs(npcModel:GetDescendants()) do
                if desc:IsA("ProximityPrompt") and desc.Enabled then
                    bestPrompt = desc
                    break
                end
            end

            if bestPrompt then
                print("🤝 Secretária: entregando crachá a " .. npcModel.Name .. " (tentativa " .. attempt .. ")...")
                local ok = FirePromptWithCamera(bestPrompt, patientPart.Position)
                task.wait(0.5)
                local stillHasBadge = HasBadgeItem()
                if ok and not stillHasBadge then return true end
                if ok and attempt >= 2 then return true end
            else
                print("⏳ Secretária: prompt de entrega ainda não habilitado, aguardando...")
            end
        end

        task.wait(0.3)
    end

    print("⚠️ Secretária: não conseguiu confirmar a entrega do crachá.")
    return false
end

local function AutoSecretariaSequence()
    local checkIn = GetCheckInFolder()
    if not checkIn then
        print("❌ Pasta CheckIn não encontrada!")
        return
    end

    print("🗂️ Iniciando Auto Secretária (Check-In)...")

    -- 1) Tirar a foto do paciente (Camera.PP)
    if not DoCheckInStep("Camera", "Tirando Foto") then return end
    if not Config.AutoSecretaria then return end

    -- 2) Registrar no computador (Computer.PP)
    if not DoCheckInStep("Computer", "Registrando no Computador") then return end
    if not Config.AutoSecretaria then return end

    -- 3) Imprimir o crachá (Printer.PP, aguarda 1.5s pra impressora terminar)
    if not DoCheckInStep("Printer", "Imprimindo Crachá", PRINTER_WAIT_TIME) then return end
    if not Config.AutoSecretaria then return end

    -- 4) Pegar o crachá impresso (VisitorBadgeBase / PatientBadgeBase, com validação de inventário)
    if not PickUpPrintedBadge() then return end
    if not Config.AutoSecretaria then return end

    -- 5) Entregar o crachá ao paciente que está esperando (NPC.PP)
    DeliverBadgeToPatient()

    print("✅ Auto Secretária: ciclo concluído!")
end

task.spawn(function()
    while true do
        RunService.Heartbeat:Wait()
        if Config.AutoSecretaria then
            local ok, err = pcall(AutoSecretariaSequence)
            if not ok then warn("[Auto Secretária] Erro: " .. tostring(err)) end
            print("⏳ Auto Secretária: aguardando 2 segundos antes de reiniciar...")
            wait(2)
        end
    end
end)

-- ==========================================
-- INTERFACE GRÁFICA (GUI PRESERVAÇÃO)
-- ==========================================

-- ==========================================
-- INTERFACE GRÁFICA (WindUI)
-- ==========================================

local WindUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"
))()

-- Toca o som de abertura uma única vez (sem loop)
-- OBS: o Roblox não aceita URL externa direto em Sound.SoundId (só rbxassetid://).
-- getcustomasset baixa o arquivo e gera um id local de asset que o Sound consegue tocar.
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
    else
        warn("[Hospital Hub] Executor sem suporte a getcustomasset — não foi possível tocar o áudio externo.")
    end
end)

local Window = WindUI:CreateWindow({
    Title = "🏥 Animal Hospital Hub",
    Icon = "https://files.catbox.moe/0mg5gr.jpg",
    Author = "v3.1 | RodrigoBloxYT",
    Theme = "Dark",
})

-- ==========================================
-- TAB: PRINCIPAL — todas as automações do hub
-- ==========================================
local MainTab = Window:Tab({ Title = "Principal", Icon = "home" })

MainTab:Paragraph({
    Title = "⚙️ Automações",
    Desc = "Ative o que precisar. Pode ligar mais de uma ao mesmo tempo.",
})

MainTab:Toggle({
    Title = "Auto Processamento Global",
    Desc = "Procura ativa em todas as salas do mapa",
    Value = Config.AutoProcess,
    Callback = function(state)
        Config.AutoProcess = state
    end,
})

MainTab:Toggle({
    Title = "Auto Room 6 (X-Ray)",
    Desc = "Sequência: X-Ray → 4 botões → Process → Badge → Collect",
    Value = Config.AutoRoom6,
    Callback = function(state)
        Config.AutoRoom6 = state
        if state then print("🔄 Auto Room 6 ativado!") end
    end,
})

MainTab:Toggle({
    Title = "Auto Room 7",
    Desc = "Interações no InBed da Room 7",
    Value = Config.AutoRoom7,
    Callback = function(state)
        Config.AutoRoom7 = state
    end,
})

MainTab:Toggle({
    Title = "Auto Room 8",
    Desc = "Sleep Patient no InBed da Room 8",
    Value = Config.AutoRoom8,
    Callback = function(state)
        Config.AutoRoom8 = state
    end,
})

MainTab:Toggle({
    Title = "Auto Atendimento (Heal)",
    Desc = "Com validação, retry e busca automática",
    Value = Config.AutoHeal,
    Callback = function(state)
        Config.AutoHeal = state
        if state then RefreshItemCache() end
    end,
})

MainTab:Paragraph({
    Title = "🗂️ Check-In (Secretária)",
    Desc = "Tira Foto → Registra no Computador → Imprime Crachá → Pega Crachá → Entrega ao paciente",
})

MainTab:Toggle({
    Title = "Auto Secretária",
    Desc = "Completa o check-in de pacientes/visitantes em loop",
    Value = Config.AutoSecretaria,
    Callback = function(state)
        Config.AutoSecretaria = state
        if state then print("🗂️ Auto Secretária ativado!") end
    end,
})

-- ==========================================
-- TAB: UTILIDADES — movimentação e ferramentas do jogador
-- ==========================================
local UtilitiesTab = Window:Tab({ Title = "Utilidades", Icon = "wrench" })

UtilitiesTab:Paragraph({
    Title = "🏃 Movimentação",
    Desc = "Ajustes de velocidade e colisão do seu personagem",
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
    Desc = "Atravessar paredes",
    Value = Config.NoClip,
    Callback = function(state)
        Config.NoClip = state
        if not state then RestoreOriginalCollisions() end
    end,
})

UtilitiesTab:Input({
    Title = "Força do Pulo (Jump Power)",
    Placeholder = "Digite 1-300",
    Value = tostring(Config.JumpPower),
    Callback = function(value)
        local j = tonumber(value)
        if j and j > 0 and j < 300 then
            Config.JumpPower = j
            local hum = GetHumanoid()
            if hum then
                hum.UseJumpPower = true
                hum.JumpPower = j
            end
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
    Desc = "Mova o analógico/WASD pra voar. Olhe pra cima ou pra baixo com a câmera pra subir ou descer.",
})

UtilitiesTab:Toggle({
    Title = "Fly (Voar)",
    Desc = "Ativa o modo de voo livre",
    Value = Config.FlyEnabled,
    Callback = function(state)
        Config.FlyEnabled = state
        if state then StartFly() else StopFly() end
    end,
})

UtilitiesTab:Input({
    Title = "Velocidade de Voo",
    Placeholder = "Digite 10-300",
    Value = tostring(Config.FlySpeed),
    Callback = function(value)
        local s = tonumber(value)
        if s and s > 0 and s < 300 then Config.FlySpeed = s end
    end,
})

-- ==========================================
-- TAB: VISUAL — câmera e interação
-- ==========================================
local VisualTab = Window:Tab({ Title = "Visual", Icon = "eye" })

VisualTab:Paragraph({
    Title = "🎥 Câmera & Interação",
    Desc = "Controle como o hub interage visualmente com o jogo",
})

VisualTab:Toggle({
    Title = "Interação Instantânea",
    Desc = "HoldDuration = 0 em todos os prompts (ativa na hora, sem segurar)",
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
    Desc = "Move a câmera pro alvo a cada ação (desative se preferir manter sua própria câmera)",
    Value = Config.AutoCameraFocus,
    Callback = function(state)
        Config.AutoCameraFocus = state
    end,
})

VisualTab:Paragraph({
    Title = "🌫️ Renderização",
    Desc = "Ajustes de visibilidade e performance",
})

VisualTab:Toggle({
    Title = "Remover Fog (Névoa)",
    Desc = "Deixa a visão limpa, sem neblina/atmosfera",
    Value = Config.NoFog,
    Callback = function(state)
        if state then EnableNoFog() else DisableNoFog() end
    end,
})

VisualTab:Toggle({
    Title = "FPS Boost",
    Desc = "Desliga Bloom, SunRays, DOF, Blur e sombras pra rodar mais leve",
    Value = Config.FPSBoost,
    Callback = function(state)
        Config.FPSBoost = state
        if state then ApplyFPSBoost() else RestoreFPSBoost() end
    end,
})

VisualTab:Paragraph({
    Title = "🎯 Highlights",
    Desc = "Verde = paciente | Vermelho = anomalia/visitor suspeito\n"
        .. "(detecção por Attribute ou nome do NPC — me avise o nome exato\n"
        .. "da anomalia se ela não ficar vermelha corretamente)",
})

VisualTab:Toggle({
    Title = "Highlights de NPC",
    Desc = "Contorna pacientes e anomalias com cor pra identificar de longe",
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

MiscTab:Paragraph({
    Title = "💬 Nosso Grupo",
    Desc = "Entre pra comunidade, tire dúvidas, sugira ideias e\n"
        .. "fique por dentro de todas as atualizações! 🚀",
})

MiscTab:Button({
    Title = "📋 Copiar link do grupo",
    Callback = function()
        pcall(function()
            setclipboard("https://chat.whatsapp.com/HLYG7uoa4n7576WlnHngFb?s=cl&p=a&ilr=1")
        end)
    end,
})

MiscTab:Paragraph({
    Title = "🛑 Emergência",
    Desc = "Desliga todas as automações e restaura o personagem ao normal",
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
        Config.NoClip = false
        Config.AutoCameraFocus = true
        RestoreOriginalCollisions()
        Config.WalkSpeed = 16
        Config.JumpPower = 50
        local hum = GetHumanoid()
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
        end

        if Config.FlyEnabled then
            Config.FlyEnabled = false
            StopFly()
        end

        if Config.NoFog then DisableNoFog() end
        if Config.FPSBoost then
            Config.FPSBoost = false
            RestoreFPSBoost()
        end
        if Config.HighlightsEnabled then
            Config.HighlightsEnabled = false
            ClearAllHighlights()
        end

        print("🛑 Todas as automações foram desativadas.")
    end,
})

-- ==========================================
-- TAB: SOBRE
-- ==========================================
local AboutTab = Window:Tab({ Title = "Sobre", Icon = "info" })

AboutTab:Paragraph({
    Title = "🏥 Animal Hospital Hub",
    Desc = "Obrigado por confiar no nosso trabalho! ❤️\n\n"
        .. "Esse hub nasceu pra tornar sua experiência no Animal Hospital\n"
        .. "mais leve, rápida e divertida — sem perder a magia do jogo.\n\n"
        .. "Cada função foi pensada com carinho e testada de verdade,\n"
        .. "pra você focar no que importa: se divertir com os amigos. 🐾",
})

AboutTab:Paragraph({
    Title = "✨ Versão & Créditos",
    Desc = "Versão: v3.1\nCriador: RodrigoBloxYT\nExecutor: Delta",
})

AboutTab:Paragraph({
    Title = "⚡ Novidades v3.1",
    Desc = "• Novo: Remover Fog (aba Visual)\n"
        .. "• Novo: FPS Boost (aba Visual)\n"
        .. "• Novo: Força do Pulo / Jump Power (aba Utilidades)\n"
        .. "• Novo: Fly / Voo com controle por câmera (aba Utilidades)\n"
        .. "• Novo: Highlights — verde no paciente, vermelho na anomalia\n"
        .. "   (aba Visual)\n"
        .. "• Abas reorganizadas: Principal, Utilidades, Visual, Misc, Sobre\n"
        .. "• Auto Secretária: fluxo corrigido pra estrutura real do jogo\n"
        .. "   (Camera → Computer → Printer → Crachá → Entrega ao NPC)\n"
        .. "• Corrigido: entrega de crachá ao paciente não funcionava\n"
        .. "   (teleporte em cima do NPC causava colisão/empurrão físico)",
})

AboutTab:Paragraph({
    Title = "💬 Nosso Grupo",
    Desc = "Entre pra comunidade, tire dúvidas, sugira ideias e\n"
        .. "fique por dentro de todas as atualizações! 🚀\n\n"
        .. "🔗 Link disponível na aba Misc",
})

print("🚀 [Hospital Hub v3.1] Interface WindUI carregada!")
