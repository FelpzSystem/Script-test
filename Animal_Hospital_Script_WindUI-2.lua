-- =====================================================================
-- ANIMAL HOSPITAL HUB v2.9.9 (ULTRA FAST - OMNI LOOK-AT TARGET)
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
        NoClip = false,
        WalkSpeed = 16
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
    if hum then hum.WalkSpeed = Config.WalkSpeed end
    if Config.NoClip then
        SaveOriginalCollisions()
        ApplyNoClip()
    else
        RestoreOriginalCollisions()
    end
end)

task.spawn(AutoRoom7Loop)
task.spawn(AutoRoom8Loop)

-- ==========================================
-- AUTO SECRETARIA (CHECK-IN)
-- ==========================================
if Config.AutoSecretaria == nil then Config.AutoSecretaria = false end

-- Ordem real usada manualmente: Form -> Photo -> Computer -> Printer -> pegar crachá impresso -> entregar ao paciente
local SecretariaSteps = {
    "Form",
    "Photo",
    "Computer",
    "Printer",
    "PrintedBadge",
}

local function GetCheckInFolder()
    local misc = Workspace:FindFirstChild("Misc")
    if not misc then return nil end
    return misc:FindFirstChild("CheckIn")
end

local function GetCheckInPrompt(checkIn, stepName)
    local obj = checkIn:FindFirstChild(stepName)
    if not obj then return nil end
    if obj:IsA("ProximityPrompt") then return obj end
    return obj:FindFirstChildOfClass("ProximityPrompt")
end

-- Depois de pegar o crachá impresso, entrega ao NPC/paciente mais próximo do CheckIn
local function DeliverBadgeToPatient()
    local root = GetRootPart()
    if not root then return false end

    local bestPrompt, bestPart, bestDist = nil, nil, math.huge

    local npcsFolder = Workspace:FindFirstChild("NPCs")
    if npcsFolder then
        for _, npc in ipairs(npcsFolder:GetChildren()) do
            for _, desc in ipairs(npc:GetDescendants()) do
                if desc:IsA("ProximityPrompt") and desc.Enabled then
                    local text = string.lower(desc.ActionText or "")
                    if string.find(text, "badge") or string.find(text, "give") or string.find(text, "deliver") or string.find(text, "hand") then
                        local part = FindBasePartInObject(desc.Parent) or FindBasePartInObject(npc)
                        if part then
                            local dist = (part.Position - root.Position).Magnitude
                            if dist < bestDist then
                                bestPrompt, bestPart, bestDist = desc, part, dist
                            end
                        end
                    end
                end
            end
        end
    end

    if bestPrompt and bestPart then
        print("🤝 Entregando crachá ao paciente...")
        SafeTeleport(bestPart.Position)
        FirePromptWithCamera(bestPrompt, bestPart.Position)
        task.wait(0.5)
        return true
    end

    print("⚠️ Nenhum paciente próximo encontrado para entregar o crachá.")
    return false
end

local function AutoSecretariaSequence()
    local checkIn = GetCheckInFolder()
    if not checkIn then
        print("❌ Pasta CheckIn não encontrada!")
        return
    end

    print("🗂️ Iniciando Auto Secretária (Check-In)...")

    for _, stepName in ipairs(SecretariaSteps) do
        if not Config.AutoSecretaria then break end

        local prompt = GetCheckInPrompt(checkIn, stepName)
        if prompt and prompt.Enabled then
            local part = FindBasePartInObject(prompt.Parent)
            if part then
                print("📋 Secretária: " .. stepName .. "...")
                SafeTeleport(part.Position)
                FirePromptWithCamera(prompt, part.Position)
                task.wait(0.6)
            end
        end
    end

    if Config.AutoSecretaria then
        DeliverBadgeToPatient()
    end

    print("✅ Auto Secretária: ciclo concluído!")
end

task.spawn(function()
    while true do
        RunService.Heartbeat:Wait()
        if Config.AutoSecretaria then
            AutoSecretariaSequence()
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
    Author = "v2.9.9 | RodrigoBloxYT",
    Theme = "Dark",
})

-- ==========================================
-- TAB: PRINCIPAL
-- ==========================================
local MainTab = Window:Tab({ Title = "Principal", Icon = "home" })

MainTab:Toggle({
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
    Title = "Auto Atendimento (Heal) v2.9.9",
    Desc = "Com validação, retry e busca automática",
    Value = Config.AutoHeal,
    Callback = function(state)
        Config.AutoHeal = state
        if state then RefreshItemCache() end
    end,
})

-- ==========================================
-- TAB: SECRETARIA
-- ==========================================
local SecretariaTab = Window:Tab({ Title = "Secretária", Icon = "clipboard-list" })

SecretariaTab:Paragraph({
    Title = "🗂️ Check-In Automático",
    Desc = "Executa sozinho: Formulário → Foto → Computador → Impressora → Pegar crachá → Entregar ao paciente",
})

SecretariaTab:Toggle({
    Title = "Auto Secretária",
    Desc = "Completa o check-in de pacientes/visitantes em loop",
    Value = Config.AutoSecretaria,
    Callback = function(state)
        Config.AutoSecretaria = state
        if state then print("🗂️ Auto Secretária ativado!") end
    end,
})

-- ==========================================
-- TAB: LOCALPLAYER
-- ==========================================
local PlayerTab = Window:Tab({ Title = "LocalPlayer", Icon = "user" })

PlayerTab:Input({
    Title = "Velocidade",
    Placeholder = "Digite 1-200",
    Value = tostring(Config.WalkSpeed),
    Callback = function(value)
        local s = tonumber(value)
        if s and s > 0 and s < 200 then Config.WalkSpeed = s end
    end,
})

PlayerTab:Toggle({
    Title = "NoClip",
    Desc = "Atravessar paredes",
    Value = Config.NoClip,
    Callback = function(state)
        Config.NoClip = state
        if not state then RestoreOriginalCollisions() end
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
    Desc = "Versão: v2.9.9\nCriador: RodrigoBloxYT\nExecutor: Delta",
})

AboutTab:Paragraph({
    Title = "⚡ Correções v2.9.9",
    Desc = "• Auto Room 6: Sequência completa corrigida\n"
        .. "• Auto Room 6: Espera 4 botões mudarem de cor\n"
        .. "• Auto Room 6: Aguarda 1.5s antes de clicar\n"
        .. "• Auto Room 6: Procura Print Badge e Collect\n"
        .. "• Auto Heal: Retry e validação de itens\n"
        .. "• Novo: Auto Secretária (Check-In completo)",
})

AboutTab:Paragraph({
    Title = "💬 Nosso Grupo",
    Desc = "Entre pra comunidade, tire dúvidas, sugira ideias e\n"
        .. "fique por dentro de todas as atualizações! 🚀\n\n"
        .. "🔗 https://chat.whatsapp.com/HLYG7uoa4n7576WlnHngFb?s=cl&p=a&ilr=1",
})

AboutTab:Button({
    Title = "📋 Copiar link do grupo",
    Callback = function()
        pcall(function()
            setclipboard("https://chat.whatsapp.com/HLYG7uoa4n7576WlnHngFb?s=cl&p=a&ilr=1")
        end)
    end,
})

AboutTab:Button({
    Title = "🔄 Resetar Velocidade",
    Callback = function()
        Config.WalkSpeed = 16
        local hum = GetHumanoid()
        if hum then hum.WalkSpeed = 16 end
    end,
})

AboutTab:Button({
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
        RestoreOriginalCollisions()
        Config.WalkSpeed = 16
    end,
})

print("🚀 [Hospital Hub v2.9.9] Interface WindUI carregada!")
