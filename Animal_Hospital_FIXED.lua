-- =====================================================================
-- SILVERFOX SCRIPTS | HOSPITAL DE ANIMAIS
-- VERSÃO v8.0 — Sistema de Rooms substituído pelo Animal Hospital Hub v2.9.9 (RodrigoBloxYT)
-- =====================================================================

local WindUI = loadstring(game:HttpGet(
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
))()

local Window = WindUI:CreateWindow({
    Title = "SILVERFOX SCRIPTS | HOSPITAL",
    Icon = "https://files.catbox.moe/vr0nkt.jpg",
    Author = "by Silverfox Scripts",
    Folder = "SilverfoxHospital",
    Theme = "Dark",
    Size = UDim2.fromOffset(620, 580),
})

Window:Tag({
    Title = "v8.0 ROOMS-HUB",
    Icon = "sparkles",
    Color = Color3.fromHex("#1c1c1c"),
    Border = true,
})

-- ==========================================
-- SERVIÇOS
-- ==========================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ==========================================
-- CONFIGURAÇÃO
-- ==========================================

_G.HospitalConfig = {
    Secretaria = false,
    ColorESP = false,
    InstantAction = false,
    NoClip = false,
    WalkSpeed = 16,
    Fly = false,
    FlySpeed = 50,
    HighJump = false,
    AntiAFK = false,
    SanityLock = false,

    -- Sistema de Rooms (portado do Animal Hospital Hub v2.9.9 - RodrigoBloxYT)
    AutoProcess = false,
    AutoHeal = false,
    AutoRoom6 = false,
    AutoRoom7 = false,
    AutoRoom8 = false,
}

local Config = _G.HospitalConfig

-- ==========================================
-- CONTROLE - ANTI-BUGS SYSTEM
-- ==========================================

local Mutex = false
local SecretariaBusy = false

local function LockMutex()
    while Mutex do task.wait(0.05) end
    Mutex = true
end

local function UnlockMutex()
    Mutex = false
end

-- Sistema Anti-Bugs pra não bugar com outras funções
local function IsOtherFunctionActive()
    return Config.AutoProcess or Config.AutoHeal or Config.AutoRoom6 or 
           Config.AutoRoom7 or Config.AutoRoom8 or Config.NoClip or 
           Config.Fly or Config.HighJump
end

-- ==========================================
-- FUNÇÕES UTILITÁRIAS
-- ==========================================

local function GetChar()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function GetHum()
    local char = GetChar()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function GetRoot()
    local char = GetChar()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function GetPartPos(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj.Position end
    local part = obj:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position or nil
end

local function Teleportar(pos)
    local root = GetRoot()
    if not root then return false end
    LockMutex()
    local ok = pcall(function()
        root.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
    end)
    if ok then
        RunService.Heartbeat:Wait()
        root.Velocity = Vector3.new(0, 0, 0)
    end
    UnlockMutex()
    return ok
end

-- Teleporta até a peça alvo (se possível) e dispara um ProximityPrompt
-- Com proteção anti-bugs pra não conflitar com outras funções
local function Interagir(prompt, semTeleport)
    if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then
        return false
    end

    LockMutex()
    
    local sucesso = false
    
    if not semTeleport then
        local pos = GetPartPos(prompt.Parent)
        if pos then
            Teleportar(pos)
            task.wait(0.15)
        end
    end

    if Config.InstantAction then
        pcall(function() prompt.HoldDuration = 0 end)
    end

    if typeof(fireproximityprompt) == "function" then
        pcall(function()
            fireproximityprompt(prompt)
            sucesso = true
        end)
    end

    if not sucesso then
        pcall(function()
            prompt:InputHoldStart(LocalPlayer)
            task.wait((prompt.HoldDuration or 0) + 0.05)
            prompt:InputHoldEnd(LocalPlayer)
            sucesso = true
        end)
    end

    UnlockMutex()
    return sucesso
end

-- Teleporta até e dispara um ClickDetector
local function Clicar(clicker, semTeleport)
    if not clicker or not clicker:IsA("ClickDetector") then return false end

    if not semTeleport then
        local pos = GetPartPos(clicker.Parent)
        if pos then
            Teleportar(pos + Vector3.new(0, 1, 1))
            task.wait(0.15)
        end
    end

    if typeof(fireclickdetector) == "function" then
        return pcall(function() fireclickdetector(clicker) end)
    end

    return false
end

-- Busca segura por caminho, tolera nomes com espaço/variação e não quebra se não existir
local function Caminho(base, ...)
    local atual = base
    for _, nome in ipairs({...}) do
        if not atual then return nil end
        atual = atual:FindFirstChild(nome)
    end
    return atual
end

-- ==========================================
-- CHECK-IN (Secretaria) — paths reais do dump
-- ==========================================

local function PegarCheckIn()
    local misc = Workspace:FindFirstChild("Misc")
    return misc and misc:FindFirstChild("CheckIn")
end

-- Espera um ProximityPrompt ficar Enabled (ex.: liberado pelo servidor após
-- a etapa anterior) e o dispara. Retorna true se conseguiu interagir.
-- timeout em segundos; passos de 0.2s.
local function EsperarEInteragir(prompt, timeout, semTeleport)
    if not prompt then return false end
    timeout = timeout or 8
    local esperado = 0
    while not prompt.Enabled and esperado < timeout do
        if not Config.Secretaria then return false end
        task.wait(0.2)
        esperado = esperado + 0.2
    end
    if not prompt.Enabled then return false end
    return Interagir(prompt, semTeleport)
end

-- Espera o prompt ficar Disabled de novo (sinal de que o servidor processou
-- a interação) antes de seguir pra próxima etapa. Evita disparar o mesmo
-- prompt várias vezes seguidas enquanto o servidor ainda está processando.
local function EsperarProcessar(prompt, timeout)
    if not prompt then return end
    timeout = timeout or 5
    local esperado = 0
    while prompt.Enabled and esperado < timeout do
        task.wait(0.2)
        esperado = esperado + 0.2
    end
end

local function SecretariaSequencia()
    -- Sistema Anti-Bugs: não executa se outra função estiver ativa
    if SecretariaBusy then return end
    if IsOtherFunctionActive() then return end
    
    SecretariaBusy = true
    
    local checkIn = PegarCheckIn()
    if not checkIn then 
        SecretariaBusy = false
        return 
    end

    -- 1️⃣ CARIMBAR FORMULÁRIO (PatientBadgeBase) - PRIMEIRO AGORA
    if Config.Secretaria then
        local badgePrompt = Caminho(checkIn, "PatientBadgeBase", "PP")
        if badgePrompt then
            if EsperarEInteragir(badgePrompt, 8) then
                EsperarProcessar(badgePrompt)
                task.wait(0.5)
            end
        end
    end

    -- 2️⃣ FOTO (Câmera) - DEPOIS
    if Config.Secretaria then
        local camPrompt = Caminho(checkIn, "Camera", "PP")
        if camPrompt and camPrompt.Enabled then
            if EsperarEInteragir(camPrompt, 3) then
                EsperarProcessar(camPrompt)
                task.wait(0.5)
            end
        end
    end

    -- 3️⃣ Pegar o Emblema/Crachá de Visitante (VisitorBadgeBase)
    if Config.Secretaria then
        local visitorPrompt = Caminho(checkIn, "VisitorBadgeBase", "PP")
        if visitorPrompt then
            if EsperarEInteragir(visitorPrompt, 8) then
                EsperarProcessar(visitorPrompt)
                task.wait(0.5)
            end
        end
    end

    -- 4️⃣ Computador (abrir/usar)
    if Config.Secretaria then
        local computer = checkIn:FindFirstChild("Computer")
        local computerPrompt = computer and computer:FindFirstChild("PP")
        if computerPrompt then
            if EsperarEInteragir(computerPrompt, 8) then
                task.wait(0.5)
            end
        end
    end

    -- 5️⃣ Teclado do computador (clicker)
    if Config.Secretaria then
        local computer = checkIn:FindFirstChild("Computer")
        if computer then
            local teclado = Caminho(computer, "Keyboard", "Keyboard")
            local clicker = teclado and teclado:FindFirstChild("Clicker")
            if clicker then
                Clicar(clicker)
                task.wait(0.5)
            end
        end
    end

    -- 6️⃣ Impressora
    if Config.Secretaria then
        local printerPrompt = Caminho(checkIn, "Printer", "PP")
        if printerPrompt then
            EsperarEInteragir(printerPrompt, 8)
            task.wait(0.5)
        end
    end
    
    SecretariaBusy = false
end

-- LOOP SECRETÁRIA com Sistema Anti-Bugs
task.spawn(function()
    while true do
        if Config.Secretaria then
            -- Verifica se não há outras funções ativas pra evitar conflito
            if not IsOtherFunctionActive() then
                SecretariaSequencia()
            end
            task.wait(1) -- Executa a cada 1 segundo
        else
            task.wait(0.5) -- Se desativado, espera menos
            SecretariaBusy = false -- Reset do busy flag
        end
    end
end)

-- ==========================================
-- ESP DE COR (Highlight verde/vermelho no personagem)
-- ==========================================

local EspHighlights = {}

local function CorDoAlvo(npc)
    local nameStr = string.lower(npc.Name or "")
    if string.find(nameStr, "anomaly") or string.find(nameStr, "shadow") or
       string.find(nameStr, "ghost") or string.find(nameStr, "hollow") then
        return Color3.fromRGB(255, 0, 0)
    end
    return Color3.fromRGB(0, 255, 0)
end

local function AplicarHighlight(npc)
    if EspHighlights[npc] then return end

    local hl = Instance.new("Highlight")
    hl.Name = "ColorESP"
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0
    local cor = CorDoAlvo(npc)
    hl.FillColor = cor
    hl.OutlineColor = cor
    hl.Parent = npc

    EspHighlights[npc] = hl
end

local function RemoverHighlights()
    for npc, hl in pairs(EspHighlights) do
        if hl then hl:Destroy() end
    end
    EspHighlights = {}
end

task.spawn(function()
    while task.wait(0.8) do
        if Config.ColorESP then
            local npcs = Workspace:FindFirstChild("NPCs")
            if npcs then
                for _, npc in ipairs(npcs:GetChildren()) do
                    if npc:FindFirstChildOfClass("Humanoid") then
                        AplicarHighlight(npc)
                    end
                end
            end
        else
            if next(EspHighlights) then
                RemoverHighlights()
            end
        end
    end
end)

-- ==========================================
-- NOCLIP / WALKSPEED / HIGHJUMP / ANTI-AFK / SANIDADE
-- ==========================================

task.spawn(function()
    while task.wait(0.3) do
        if Config.NoClip then
            local char = GetChar()
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(0.2) do
        local hum = GetHum()
        if hum then
            if Config.WalkSpeed and hum.WalkSpeed ~= Config.WalkSpeed then
                hum.WalkSpeed = Config.WalkSpeed
            end
            hum.JumpPower = Config.HighJump and 200 or 50
        end
    end
end)

task.spawn(function()
    while task.wait(60) do
        if Config.AntiAFK then
            pcall(function()
                LocalPlayer.Idled:Wait()
                local vk = game:GetService("VirtualUser")
                vk:CaptureController()
                vk:ClickButton2(Vector2.new())
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        if Config.SanityLock then
            local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
            local sanidade = leaderstats and leaderstats:FindFirstChild("Sanidade")
            if sanidade then
                sanidade.Value = 100
            end
        end
    end
end)

-- ==========================================
-- FLY
-- ==========================================

local FlyingConnection = nil

local function ToggleFly(enabled)
    Config.Fly = enabled

    if FlyingConnection then
        FlyingConnection:Disconnect()
        FlyingConnection = nil
    end

    if not enabled then return end

    local root = GetRoot()
    if not root then return end

    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVelocity.Parent = root

    FlyingConnection = RunService.Heartbeat:Connect(function()
        if not Config.Fly or not root or not root.Parent then
            if bodyVelocity and bodyVelocity.Parent then
                bodyVelocity:Destroy()
            end
            if FlyingConnection then
                FlyingConnection:Disconnect()
                FlyingConnection = nil
            end
            return
        end

        local input = Vector3.new(0, 0, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then input = input + Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then input = input - Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then input = input - Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then input = input + Camera.CFrame.RightVector end

        local up = Vector3.new(0, 1, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then input = input + up end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then input = input - up end

        if input.Magnitude > 0 then
            input = input.Unit
        end

        bodyVelocity.Velocity = input * (Config.FlySpeed or 50)
    end)
end

-- =====================================================================
-- SISTEMA DE ROOMS (portado do "Animal Hospital Hub v2.9.9" - RodrigoBloxYT)
-- Inclui: foco visual (look-at) em cada prompt, cache de itens,
-- Auto Room 6 (sequência completa X-Ray), Auto Heal (Rooms 1-6 com
-- inventário), Auto Process Global, Auto Room 7 e Auto Room 8.
-- =====================================================================

local ItemDebounce = {}
local ITEM_PICKUP_COOLDOWN = 0.2

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

local function LookAtPosition(targetPosition)
    local root = GetRoot()
    if root and targetPosition then
        pcall(function()
            root.CFrame = CFrame.lookAt(root.Position, targetPosition)

            local character = GetChar()
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

    local s1 = pcall(function()
        fireproximityprompt(prompt)
    end)
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
            if tool:IsA("Tool") and string.find(string.lower(tool.Name), string.lower(itemName)) then
                return true
            end
        end
    end
    local char = GetChar()
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
    local hum = GetHum()
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
-- AUTO ROOM 6 (SEQUÊNCIA COMPLETA: X-Ray → 4 botões → Process → Badge → Collect)
-- ==========================================

local function AutoRoom6Sequence()
    local emergency = GetEmergencyRooms()
    if not emergency then return end

    local room6 = emergency:FindFirstChild("Room6")
    if not room6 then return end

    local minigame = room6:FindFirstChild("Minigame")
    if not minigame then return end

    -- PASSO 1: Begin X-Ray
    local xrayMonitor = FindXrayMonitorInMinigame(room6)
    if xrayMonitor then
        local xrayPrompt = xrayMonitor:FindFirstChild("PP")
        if xrayPrompt and xrayPrompt:IsA("ProximityPrompt") and xrayPrompt.Enabled then
            local part = FindBasePartInObject(xrayMonitor)
            if part then
                Teleportar(part.Position)
                FirePromptWithCamera(xrayPrompt, part.Position)
                task.wait(0.5)
            end
        end
    end

    -- PASSO 2: Aguardar 4 botões mudarem de cor
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
    end

    -- PASSO 3: Esperar 1.5 segundos
    task.wait(1.5)

    -- PASSO 4: Clicar nos 4 botões (um por um com foco)
    for _, btn in ipairs(buttons) do
        if btn and btn:IsA("BasePart") then
            Teleportar(btn.Position + Vector3.new(0, 1, 2))
            LookAtPosition(btn.Position)
            task.wait(0.2)
            ClickButton(btn)
            task.wait(0.15)
        end
    end

    -- PASSO 5: "Process Results"
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
            Teleportar(part.Position)
            FirePromptWithCamera(processPrompt, part.Position)
            task.wait(0.5)
        end
    end

    -- PASSO 6: "Print Badge"
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
            Teleportar(part.Position)
            FirePromptWithCamera(printBadgePrompt, part.Position)
            task.wait(0.5)
        end
    end

    -- PASSO 7: "Collect" no Workspace
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
            Teleportar(part.Position)
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
-- AUTO HEAL (Rooms 1-6, com validação, retry e busca automática de itens)
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
                    local bp = FindBasePartInObject(npc)
                    deliverPosition = bp and bp.Position
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
                        Teleportar(part.Position)
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
        Teleportar(deliverPosition + Vector3.new(0, 1, 0))

        for _, itemName in ipairs(itemsNeeded) do
            if HasItem(itemName) then
                EquipToolFast(itemName)
                for i = 1, 3 do
                    if FirePromptDirect(promptToDeliver) then
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
                    Teleportar(part.Position)
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
                                        Teleportar(part.Position)
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
                                    Teleportar(part.Position)
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

task.spawn(AutoRoom7Loop)
task.spawn(AutoRoom8Loop)

-- ==========================================
-- SERVER HOP
-- ==========================================

local function ServerHop()
    local HttpService = game:GetService("HttpService")
    local servers = {}
    local cursor = ""

    for i = 1, 3 do
        local ok, response = pcall(function()
            local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
            if cursor ~= "" then url = url .. "&cursor=" .. cursor end
            return HttpService:GetAsync(url)
        end)

        if ok then
            local data = HttpService:JSONDecode(response)
            for _, server in ipairs(data.data) do
                if server.id ~= game.JobId and server.playing < server.maxPlayers then
                    table.insert(servers, server.id)
                end
            end
            if data.nextPageCursor then cursor = data.nextPageCursor else break end
        end
    end

    if #servers > 0 then
        TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], LocalPlayer)
    end
end

-- ==========================================
-- INTERFACE
-- ==========================================

-- TAB 1: ATENDIMENTO
local Tab1 = Window:Tab({Title = "Atendimento", Icon = "home"})

Tab1:Paragraph({ Title = "Hospital - Funcoes de Atendimento" })

Tab1:Toggle({
    Title = "Secretaria (Foto, Formulario, Computador, Impressora)",
    Value = false,
    Callback = function(v) Config.Secretaria = v end,
})

Tab1:Paragraph({ Title = "Sistema de Rooms (Animal Hospital Hub v2.9.9)" })

Tab1:Toggle({
    Title = "Auto Processamento Global",
    Desc = "Procura ativa em todas as salas do mapa (DNA/Analyze/Process)",
    Value = false,
    Callback = function(v) Config.AutoProcess = v end,
})

Tab1:Toggle({
    Title = "Auto Atendimento (Heal) - Rooms 1-6",
    Desc = "Coleta itens do inventario e entrega ao paciente, com retry",
    Value = false,
    Callback = function(v)
        Config.AutoHeal = v
        if v then RefreshItemCache() end
    end,
})

Tab1:Toggle({
    Title = "Auto Room 6 (X-Ray)",
    Desc = "Sequencia: X-Ray -> 4 botoes -> Process -> Badge -> Collect",
    Value = false,
    Callback = function(v) Config.AutoRoom6 = v end,
})

Tab1:Toggle({
    Title = "Auto Room 7",
    Desc = "Interacoes automaticas no InBed da Room 7",
    Value = false,
    Callback = function(v) Config.AutoRoom7 = v end,
})

Tab1:Toggle({
    Title = "Auto Room 8",
    Desc = "Sleep Patient no InBed da Room 8",
    Value = false,
    Callback = function(v) Config.AutoRoom8 = v end,
})

-- TAB 2: VISUAL
local Tab2 = Window:Tab({Title = "Visual", Icon = "eye"})

Tab2:Paragraph({ Title = "Recursos Visuais" })

Tab2:Toggle({
    Title = "Color ESP",
    Desc = "Personagem fica Vermelho (Anomaly) ou Verde (Normal)",
    Value = false,
    Callback = function(v) Config.ColorESP = v end,
})

Tab2:Toggle({
    Title = "Instant Action",
    Desc = "Remove delay dos prompts",
    Value = false,
    Callback = function(v) Config.InstantAction = v end,
})

-- TAB 3: UTILIDADES
local Tab3 = Window:Tab({Title = "Utilidades", Icon = "user"})

Tab3:Paragraph({ Title = "Controles do Personagem" })

Tab3:Toggle({
    Title = "NoClip",
    Value = false,
    Callback = function(v) Config.NoClip = v end,
})

Tab3:Slider({
    Title = "WalkSpeed",
    Step = 1,
    Value = {Min = 16, Max = 200, Default = 16},
    Callback = function(v) Config.WalkSpeed = v end,
})

Tab3:Toggle({
    Title = "High Jump",
    Value = false,
    Callback = function(v) Config.HighJump = v end,
})

Tab3:Toggle({
    Title = "Fly (WASD+Space+Ctrl)",
    Value = false,
    Callback = function(v) ToggleFly(v) end,
})

Tab3:Slider({
    Title = "Fly Speed",
    Step = 5,
    Value = {Min = 10, Max = 200, Default = 50},
    Callback = function(v) Config.FlySpeed = v end,
})

Tab3:Toggle({
    Title = "Anti AFK",
    Value = false,
    Callback = function(v) Config.AntiAFK = v end,
})

Tab3:Toggle({
    Title = "Sanidade Infinita",
    Value = false,
    Callback = function(v) Config.SanityLock = v end,
})

-- TAB 4: SERVIDOR
local Tab4 = Window:Tab({Title = "Servidor", Icon = "globe"})

Tab4:Paragraph({ Title = "Opcoes de Servidor" })

Tab4:Button({
    Title = "Server Hop",
    Desc = "Troca para outro servidor",
    Callback = function()
        WindUI:Notify({Title = "Server Hop", Content = "Trocando servidor...", Duration = 3})
        task.wait(1)
        ServerHop()
    end,
})

local execName = "Desconhecido"
if identifyexecutor then
    local ok, name = pcall(identifyexecutor)
    if ok then execName = name or "Desconhecido" end
end

Tab4:Paragraph({
    Title = "Info do Executor",
    Desc = "Executor: " .. execName .. "\nVersao: v8.0\nby Silverfox Scripts",
})

-- TAB 5: RESET
local Tab5 = Window:Tab({Title = "Reset", Icon = "settings"})

Tab5:Paragraph({ Title = "Resetar Configuracoes" })

Tab5:Button({
    Title = "Resetar Velocidade",
    Desc = "Volta pra 16",
    Callback = function()
        Config.WalkSpeed = 16
        local hum = GetHum()
        if hum then hum.WalkSpeed = 16 end
    end,
})

Tab5:Button({
    Title = "DESATIVAR TUDO",
    Desc = "Desliga todas as funcoes",
    Callback = function()
        for k in pairs(Config) do
            if type(Config[k]) == "boolean" then
                Config[k] = false
            end
        end
        Config.WalkSpeed = 16
        ToggleFly(false)
        RemoverHighlights()
        local hum = GetHum()
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
        end
    end,
})

-- ==========================================
-- INIT
-- ==========================================

print("Silverfox Scripts | Hospital v8.0 - Rooms Hub")

WindUI:Notify({
    Title = "Silverfox Scripts",
    Content = "Script carregado!\nVersao: v8.0",
    Duration = 5,
    Icon = "check-circle",
})
