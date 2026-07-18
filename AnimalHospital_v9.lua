-- =====================================================================
-- SILVERFOX SCRIPTS | HOSPITAL DE ANIMAIS
-- VERSÃO v9.0 — Bugs corrigidos, Secretaria funcional, Rooms completas
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
    Size = UDim2.fromOffset(700, 660),
})

Window:Tag({
    Title = "v9.0",
    Icon = "sparkles",
    Color = Color3.fromHex("#1c1c1c"),
    Border = true,
})

-- ==========================================
-- SERVIÇOS
-- ==========================================

local Players        = game:GetService("Players")
local Workspace      = game:GetService("Workspace")
local RunService     = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService  = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

-- ==========================================
-- CONFIGURAÇÃO
-- ==========================================

_G.HospitalConfig = {
    Secretaria    = false,
    ColorESP      = false,
    InstantAction = false,
    NoClip        = false,
    WalkSpeed     = 16,
    Fly           = false,
    FlySpeed      = 50,
    HighJump      = false,
    AntiAFK       = false,
    SanityLock    = false,

    AutoProcess   = false,
    AutoHeal      = false,
    AutoRoom6     = false,
    AutoRoom7     = false,
    AutoRoom8     = false,
}

local Config = _G.HospitalConfig

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

-- TELEPORTAR sem mutex (função interna, chamada de dentro de contextos já bloqueados)
local function Teleportar(pos)
    local root = GetRoot()
    if not root then return false end
    local ok = pcall(function()
        root.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
    end)
    if ok then
        RunService.Heartbeat:Wait()
        pcall(function() root.Velocity = Vector3.new(0, 0, 0) end)
    end
    return ok
end

-- Busca segura por caminho encadeado
local function Caminho(base, ...)
    local atual = base
    for _, nome in ipairs({...}) do
        if not atual then return nil end
        atual = atual:FindFirstChild(nome)
    end
    return atual
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

-- Dispara ProximityPrompt com câmera
local function FirePromptDirect(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then return false end

    local targetPart = FindBasePartInObject(prompt.Parent)
    if targetPart then
        LookAtPosition(targetPart.Position)
    end

    if Config.InstantAction then pcall(function() prompt.HoldDuration = 0 end) end

    local success = false

    if typeof(fireproximityprompt) == "function" then
        local s = pcall(function() fireproximityprompt(prompt) end)
        if s then success = true end
    end

    if not success then
        local s = pcall(function()
            prompt:InputHoldStart(LocalPlayer)
            task.wait(0.05)
            prompt:InputHoldEnd(LocalPlayer)
        end)
        if s then success = true end
    end

    return success
end

-- Teleporta até o prompt e o dispara
local function Interagir(prompt, semTeleport)
    if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then
        return false
    end

    if not semTeleport then
        local pos = GetPartPos(prompt.Parent)
        if pos then
            Teleportar(pos)
            task.wait(0.2)
        end
    end

    return FirePromptDirect(prompt)
end

-- Dispara ClickDetector com teleporte
local function Clicar(clicker, semTeleport)
    if not clicker or not clicker:IsA("ClickDetector") then return false end

    if not semTeleport then
        local pos = GetPartPos(clicker.Parent)
        if pos then
            Teleportar(pos + Vector3.new(0, 1, 1))
            task.wait(0.2)
        end
    end

    if typeof(fireclickdetector) == "function" then
        local ok = pcall(function() fireclickdetector(clicker) end)
        return ok
    end

    return false
end

-- Espera prompt ficar Enabled e interage
local function EsperarEInteragir(prompt, timeout, semTeleport)
    if not prompt then return false end
    timeout = timeout or 8
    local t = 0
    while not prompt.Enabled and t < timeout do
        task.wait(0.2)
        t = t + 0.2
    end
    if not prompt.Enabled then return false end
    return Interagir(prompt, semTeleport)
end

-- Espera prompt ficar Disabled (servidor processou)
local function EsperarProcessar(prompt, timeout)
    if not prompt then return end
    timeout = timeout or 5
    local t = 0
    while prompt.Enabled and t < timeout do
        task.wait(0.2)
        t = t + 0.2
    end
end

-- ==========================================
-- SECRETARIA (CHECK-IN)
-- Fluxo: Atendimento (AutoHeal) roda separado.
-- Secretaria roda no seu próprio loop, independente.
-- Ordem: Badge → Foto → VisitorBadge → Computador → Teclado → Impressora
-- ==========================================

local SecretariaBusy = false

local function PegarCheckIn()
    local misc = Workspace:FindFirstChild("Misc")
    return misc and misc:FindFirstChild("CheckIn")
end

local function SecretariaSequencia()
    if SecretariaBusy then return end
    SecretariaBusy = true

    local checkIn = PegarCheckIn()
    if not checkIn then
        SecretariaBusy = false
        return
    end

    -- 1) CARIMBAR FORMULÁRIO (PatientBadgeBase)
    if Config.Secretaria then
        local prompt = Caminho(checkIn, "PatientBadgeBase", "PP")
        if prompt and EsperarEInteragir(prompt, 8) then
            EsperarProcessar(prompt)
            task.wait(0.5)
        end
    end

    -- 2) FOTO (Camera)
    if Config.Secretaria then
        local prompt = Caminho(checkIn, "Camera", "PP")
        if prompt and EsperarEInteragir(prompt, 5) then
            EsperarProcessar(prompt)
            task.wait(0.5)
        end
    end

    -- 3) PEGAR EMBLEMA (VisitorBadgeBase)
    if Config.Secretaria then
        local prompt = Caminho(checkIn, "VisitorBadgeBase", "PP")
        if prompt and EsperarEInteragir(prompt, 8) then
            EsperarProcessar(prompt)
            task.wait(0.5)
        end
    end

    -- 4) COMPUTADOR — abrir
    if Config.Secretaria then
        local computer = checkIn:FindFirstChild("Computer")
        local prompt = computer and computer:FindFirstChild("PP")
        if prompt and EsperarEInteragir(prompt, 8) then
            task.wait(0.5)
        end
    end

    -- 5) TECLADO — ClickDetector
    if Config.Secretaria then
        local computer = checkIn:FindFirstChild("Computer")
        if computer then
            local clicker = Caminho(computer, "Keyboard", "Keyboard", "Clicker")
            if clicker then
                Clicar(clicker)
                task.wait(0.5)
            end
        end
    end

    -- 6) IMPRESSORA
    if Config.Secretaria then
        local prompt = Caminho(checkIn, "Printer", "PP")
        if prompt and EsperarEInteragir(prompt, 8) then
            task.wait(0.5)
        end
    end

    SecretariaBusy = false
end

-- Loop da Secretaria — independente dos outros sistemas
task.spawn(function()
    while true do
        if Config.Secretaria then
            SecretariaSequencia()
            task.wait(1.5)
        else
            SecretariaBusy = false
            task.wait(0.5)
        end
    end
end)

-- ==========================================
-- ESP DE COR
-- ==========================================

local EspHighlights = {}

local function CorDoAlvo(npc)
    local nameStr = string.lower(npc.Name or "")
    if string.find(nameStr, "anomaly") or string.find(nameStr, "shadow") or
       string.find(nameStr, "ghost")   or string.find(nameStr, "hollow") then
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
            if next(EspHighlights) then RemoverHighlights() end
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
            if hum.WalkSpeed ~= Config.WalkSpeed then
                hum.WalkSpeed = Config.WalkSpeed
            end
            hum.JumpPower = Config.HighJump and 200 or 50
        end
    end
end)

task.spawn(function()
    while task.wait(55) do
        if Config.AntiAFK then
            pcall(function()
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
            if sanidade then sanidade.Value = 100 end
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
            if bodyVelocity and bodyVelocity.Parent then bodyVelocity:Destroy() end
            if FlyingConnection then FlyingConnection:Disconnect(); FlyingConnection = nil end
            return
        end

        local input = Vector3.new(0, 0, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then input = input + Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then input = input - Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then input = input - Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then input = input + Camera.CFrame.RightVector end

        local up = Vector3.new(0, 1, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.Space)       then input = input + up end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then input = input - up end

        if input.Magnitude > 0 then input = input.Unit end
        bodyVelocity.Velocity = input * (Config.FlySpeed or 50)
    end)
end

-- ==========================================
-- SISTEMA DE ROOMS
-- ==========================================

local ItemDebounce    = {}
local ITEM_COOLDOWN   = 0.2

local ItemPromptCache   = {}
local CacheRefreshTime  = 0
local CACHE_DURATION    = 3

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
        if string.find(key, target, 1, true) or string.find(target, key, 1, true) then
            return prompt
        end
    end
    return nil
end

local function HasItem(itemName)
    if not itemName or itemName == "" then return false end
    local low = string.lower(itemName)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and string.find(string.lower(tool.Name), low, 1, true) then
                return true
            end
        end
    end
    local char = GetChar()
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") and string.find(string.lower(tool.Name), low, 1, true) then
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
            if tool:IsA("Tool") and string.find(string.lower(tool.Name), string.lower(itemName), 1, true) then
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
            local ui = Caminho(tv, "Screen", "UI", "Report")
            if ui then
                local inv = ui:FindFirstChild("inv")
                if inv then return inv end
            end
        end
    end
    return room:FindFirstChild("inv", true)
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
-- AUTO ROOM 6 (X-Ray → Botões → xresult → Impressora)
-- ==========================================

local function GetButtonModels(colorsFolder)
    if not colorsFolder then return {} end
    local buttons = {}
    for _, model in ipairs(colorsFolder:GetChildren()) do
        if model:IsA("Model") then
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
        if model:IsA("Model") then
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
        if initialColors[i] ~= currentColors[i] then changed = changed + 1 end
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

    -- PASSO 1: Acionar X-Ray Monitor (xrayMonitor.PP)
    local xrayMonitor = minigame:FindFirstChild("xrayMonitor")
    if xrayMonitor then
        local xrayPrompt = xrayMonitor:FindFirstChild("PP")
        if xrayPrompt and xrayPrompt:IsA("ProximityPrompt") and xrayPrompt.Enabled then
            local part = FindBasePartInObject(xrayMonitor)
            if part then
                Teleportar(part.Position)
                task.wait(0.2)
                FirePromptDirect(xrayPrompt)
                task.wait(0.5)
            end
        end
    end

    -- PASSO 2: Aguardar 4 botões mudarem de cor (Colors folder)
    local colorsFolder = minigame:FindFirstChild("Colors")
    if not colorsFolder then return end

    local initialColors = GetButtonColors(colorsFolder)
    local buttons = GetButtonModels(colorsFolder)
    if #buttons < 4 then return end

    local timeout = 0
    while timeout < 15 and CountChangedButtons(colorsFolder, initialColors) < 4 do
        task.wait(0.2)
        timeout = timeout + 0.2
    end

    -- PASSO 3: Aguardar 1.5s
    task.wait(1.5)

    -- PASSO 4: Clicar nos botões (ClickDetector)
    for _, btn in ipairs(buttons) do
        if btn and btn:IsA("BasePart") then
            Teleportar(btn.Position + Vector3.new(0, 1, 2))
            LookAtPosition(btn.Position)
            task.wait(0.2)
            local cd = btn:FindFirstChildOfClass("ClickDetector")
            if cd then
                pcall(function() fireclickdetector(cd) end)
            else
                -- fallback: PP no mesmo model
                local pp = btn.Parent and btn.Parent:FindFirstChild("PP")
                if pp then FirePromptDirect(pp) end
            end
            task.wait(0.2)
        end
    end

    -- PASSO 5: xresult.PP (resultado do X-Ray)
    local xresult = minigame:FindFirstChild("xresult")
    if xresult then
        local xresultPrompt = xresult:FindFirstChild("PP")
        local xresultTimeout = 0
        while xresultTimeout < 10 do
            if xresultPrompt and xresultPrompt.Enabled then break end
            task.wait(0.3)
            xresultTimeout = xresultTimeout + 0.3
        end
        if xresultPrompt and xresultPrompt.Enabled then
            local part = FindBasePartInObject(xresult)
            if part then
                Teleportar(part.Position)
                task.wait(0.2)
                FirePromptDirect(xresultPrompt)
                task.wait(0.5)
            end
        end
    end

    -- PASSO 6: Printer.PP
    local printer = minigame:FindFirstChild("Printer")
    if printer then
        local printerPrompt = printer:FindFirstChild("PP")
        local printerTimeout = 0
        while printerTimeout < 10 do
            if printerPrompt and printerPrompt.Enabled then break end
            task.wait(0.3)
            printerTimeout = printerTimeout + 0.3
        end
        if printerPrompt and printerPrompt.Enabled then
            local part = FindBasePartInObject(printer)
            if part then
                Teleportar(part.Position)
                task.wait(0.2)
                FirePromptDirect(printerPrompt)
                task.wait(0.5)
            end
        end
    end

    -- PASSO 7: Collect (itens dropados no workspace)
    local collectTimeout = 0
    while collectTimeout < 8 do
        for _, desc in ipairs(Workspace:GetDescendants()) do
            if desc:IsA("ProximityPrompt") and desc.Enabled then
                local txt = string.lower(desc.ActionText or "")
                if string.find(txt, "collect") then
                    local part = FindBasePartInObject(desc.Parent)
                    if part then
                        Teleportar(part.Position)
                        task.wait(0.2)
                        FirePromptDirect(desc)
                    end
                end
            end
        end
        task.wait(0.3)
        collectTimeout = collectTimeout + 0.3
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
-- AUTO HEAL (Rooms 1-5 + Room6 itens)
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

        local inBed = FindInBedInRoom(room)
        if inBed then
            for _, desc in ipairs(inBed:GetDescendants()) do
                if desc:IsA("ProximityPrompt") and desc.Enabled then
                    promptToDeliver = desc
                    break
                end
            end
            if not promptToDeliver then
                for _, desc in ipairs(inBed.Parent:GetDescendants()) do
                    if desc:IsA("ProximityPrompt") and desc.Enabled then
                        promptToDeliver = desc
                        break
                    end
                end
            end
            deliverPosition = inBed.Position
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
                if pp and pp:IsA("ProximityPrompt") and pp.Enabled then
                    local txt = string.lower(pp.ActionText or "")
                    if string.find(txt, "treatment") then
                        promptToDeliver = pp
                        local bp = FindBasePartInObject(npc)
                        deliverPosition = bp and bp.Position
                        break
                    end
                end
            end
        end
    end

    if #itemsNeeded == 0 or not promptToDeliver then return false end

    -- Fase 1: Coletar itens
    local holdingAll = true
    local maxRetries = 3

    for _, itemName in ipairs(itemsNeeded) do
        local retries = 0
        local collected = HasItem(itemName)

        while not collected and retries < maxRetries do
            if HasItem(itemName) then collected = true; break end
            local prompt = GetCachedItemPrompt(itemName)
            if prompt and prompt.Enabled then
                local lastPickup = ItemDebounce[prompt] or 0
                if os.clock() - lastPickup >= ITEM_COOLDOWN then
                    local part = FindBasePartInObject(prompt.Parent)
                    if part then
                        ItemDebounce[prompt] = os.clock()
                        Teleportar(part.Position)
                        task.wait(0.1)
                        FirePromptDirect(prompt)
                        task.wait(0.2)
                        if HasItem(itemName) then collected = true; break end
                    end
                end
            end
            retries = retries + 1
            task.wait(0.1)
        end

        if not collected then holdingAll = false end
    end

    -- Fase 2: Entregar
    if holdingAll and deliverPosition then
        Teleportar(deliverPosition + Vector3.new(0, 1, 0))
        task.wait(0.2)
        for _, itemName in ipairs(itemsNeeded) do
            if HasItem(itemName) then
                EquipToolFast(itemName)
                for _ = 1, 3 do
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
                task.wait(0.2)
            end
        end
    end
end)

-- ==========================================
-- AUTO PROCESS GLOBAL
-- ==========================================

local function ProcessGlobalRooms()
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if not Config.AutoProcess then break end
        if desc:IsA("ProximityPrompt") and desc.Enabled and desc.ActionText then
            local txt = string.lower(desc.ActionText)
            if string.find(txt, "dna") or string.find(txt, "analyz") or string.find(txt, "process") then
                local part = FindBasePartInObject(desc.Parent)
                if part then
                    Teleportar(part.Position)
                    task.wait(0.1)
                    FirePromptDirect(desc)
                    task.wait(0.1)
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
            task.wait(0.5)
        end
    end
end)

-- ==========================================
-- AUTO ROOM 7 — Sequência completa
-- Prompts: Machine, Monitor, HeartMonitor, StandIV, InBed, Printer, xresult, Curtains
-- ==========================================

local function AutoRoom7Sequence()
    local emergency = GetEmergencyRooms()
    local room7 = emergency and emergency:FindFirstChild("Room7")
    if not room7 then return end

    local minigame = room7:FindFirstChild("Minigame")
    if not minigame then return end

    -- Lista de itens a acionar por ordem de prioridade
    local targets = {
        -- InBed primeiro
        {path = {"Bed", "InBed"}, promptName = "PP"},
        {path = {"Bed", "InBed"}, promptName = "PP2"},
        -- Máquinas e equipamentos
        {path = {"Machine"}, promptName = "PP"},
        {path = {"Monitor"}, promptName = "PP"},
        {path = {"Monitor"}, promptName = "PP2"},
        {path = {"HeartMonitor"}, promptName = "PP"},
        {path = {"StandIV"}, promptName = "PP"},
        {path = {"xresult"}, promptName = "PP"},
        {path = {"Printer"}, promptName = "PP"},
    }

    for _, target in ipairs(targets) do
        if not Config.AutoRoom7 then return end

        local obj = minigame
        for _, name in ipairs(target.path) do
            obj = obj and obj:FindFirstChild(name)
        end
        if not obj then continue end

        local prompt = obj:FindFirstChild(target.promptName)
        if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled then
            local part = FindBasePartInObject(obj)
            if part then
                Teleportar(part.Position)
                task.wait(0.2)
                FirePromptDirect(prompt)
                task.wait(0.3)
            end
        end
    end

    -- Cortinas
    local curtains = room7:FindFirstChild("Curtains")
    if curtains then
        local open = curtains:FindFirstChild("Open")
        if open then
            for _, pp in ipairs(open:GetChildren()) do
                if pp:IsA("ProximityPrompt") and pp.Enabled then
                    local part = FindBasePartInObject(open)
                    if part then
                        Teleportar(part.Position)
                        task.wait(0.2)
                        FirePromptDirect(pp)
                        task.wait(0.3)
                    end
                end
            end
        end
    end
end

task.spawn(function()
    while true do
        RunService.Heartbeat:Wait()
        if Config.AutoRoom7 then
            AutoRoom7Sequence()
            task.wait(2)
        end
    end
end)

-- ==========================================
-- AUTO ROOM 8 — InBed + Medicine + Monitor + Printer
-- ==========================================

local function AutoRoom8Sequence()
    local emergency = GetEmergencyRooms()
    local room8 = emergency and emergency:FindFirstChild("Room8")
    if not room8 then return end

    local minigame = room8:FindFirstChild("Minigame")
    if not minigame then return end

    -- InBed prompts
    local inBed = FindInBedInRoom(room8)
    if inBed then
        for _, prompt in ipairs(inBed:GetDescendants()) do
            if not Config.AutoRoom8 then return end
            if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                local part = FindBasePartInObject(prompt.Parent)
                if part then
                    Teleportar(part.Position)
                    task.wait(0.2)
                    FirePromptDirect(prompt)
                    task.wait(0.3)
                end
            end
        end
    end

    -- Medicine — acionar cada item de medicine
    local medicine = minigame:FindFirstChild("Medicine")
    if medicine then
        for _, model in ipairs(medicine:GetDescendants()) do
            if not Config.AutoRoom8 then return end
            if model:IsA("ProximityPrompt") and model.Enabled then
                local part = FindBasePartInObject(model.Parent)
                if part then
                    Teleportar(part.Position)
                    task.wait(0.15)
                    FirePromptDirect(model)
                    task.wait(0.2)
                end
            end
        end
    end

    -- Monitor
    local monitor = minigame:FindFirstChild("Monitor")
    if monitor then
        for _, prompt in ipairs(monitor:GetChildren()) do
            if not Config.AutoRoom8 then return end
            if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                local part = FindBasePartInObject(monitor)
                if part then
                    Teleportar(part.Position)
                    task.wait(0.2)
                    FirePromptDirect(prompt)
                    task.wait(0.3)
                end
            end
        end
    end

    -- Printer
    local printer = minigame:FindFirstChild("Printer")
    if printer then
        local pp = printer:FindFirstChild("PP")
        if pp and pp.Enabled then
            local part = FindBasePartInObject(printer)
            if part then
                Teleportar(part.Position)
                task.wait(0.2)
                FirePromptDirect(pp)
                task.wait(0.3)
            end
        end
    end
end

task.spawn(function()
    while true do
        RunService.Heartbeat:Wait()
        if Config.AutoRoom8 then
            AutoRoom8Sequence()
            task.wait(2)
        end
    end
end)

-- ==========================================
-- SERVER HOP
-- ==========================================

local function ServerHop()
    local HttpService = game:GetService("HttpService")
    local servers = {}
    local cursor = ""

    for _ = 1, 3 do
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
local Tab1 = Window:Tab({ Title = "Atendimento", Icon = "home" })

Tab1:Paragraph({ Title = "Secretaria (Check-In)", Desc = "Sistema de check-in do paciente: Badge, Foto, Computador e Impressora" })

Tab1:Toggle({
    Title = "Secretaria Auto",
    Desc = "Automatiza: Formulario → Foto → Emblema → Computador → Teclado → Impressora",
    Value = false,
    Callback = function(v)
        Config.Secretaria = v
        if not v then SecretariaBusy = false end
    end,
})

Tab1:Separator()
Tab1:Paragraph({ Title = "Sistema de Rooms", Desc = "Atendimento automatico dos pacientes nas salas" })

Tab1:Toggle({
    Title = "Auto Processamento Global",
    Desc = "DNA / Analyze / Process em todas as salas",
    Value = false,
    Callback = function(v) Config.AutoProcess = v end,
})

Tab1:Toggle({
    Title = "Auto Atendimento (Heal) — Rooms 1 a 6",
    Desc = "Coleta itens e entrega ao paciente com retry automatico",
    Value = false,
    Callback = function(v)
        Config.AutoHeal = v
        if v then RefreshItemCache() end
    end,
})

Tab1:Toggle({
    Title = "Auto Room 6 (X-Ray)",
    Desc = "X-Ray → 4 botoes → xresult → Impressora → Collect",
    Value = false,
    Callback = function(v) Config.AutoRoom6 = v end,
})

Tab1:Toggle({
    Title = "Auto Room 7",
    Desc = "Machine, Monitor, HeartMonitor, StandIV, InBed, Printer, xresult, Curtinas",
    Value = false,
    Callback = function(v) Config.AutoRoom7 = v end,
})

Tab1:Toggle({
    Title = "Auto Room 8",
    Desc = "InBed, todos os Medicines, Monitor e Impressora",
    Value = false,
    Callback = function(v) Config.AutoRoom8 = v end,
})

-- TAB 2: VISUAL
local Tab2 = Window:Tab({ Title = "Visual", Icon = "eye" })

Tab2:Paragraph({ Title = "Recursos Visuais", Desc = "ESP e interacoes visuais" })

Tab2:Toggle({
    Title = "Color ESP",
    Desc = "Verde = Normal | Vermelho = Anomaly/Shadow/Ghost/Hollow",
    Value = false,
    Callback = function(v) Config.ColorESP = v end,
})

Tab2:Toggle({
    Title = "Instant Action",
    Desc = "Remove o tempo de espera dos ProximityPrompts",
    Value = false,
    Callback = function(v) Config.InstantAction = v end,
})

-- TAB 3: UTILIDADES
local Tab3 = Window:Tab({ Title = "Utilidades", Icon = "user" })

Tab3:Paragraph({ Title = "Controles do Personagem", Desc = "Movimentacao e habilidades extras" })

Tab3:Toggle({
    Title = "NoClip",
    Desc = "Atravessa paredes e obstaculos",
    Value = false,
    Callback = function(v) Config.NoClip = v end,
})

Tab3:Slider({
    Title = "WalkSpeed",
    Desc = "Velocidade de caminhada (padrao: 16)",
    Step = 1,
    Value = { Min = 16, Max = 200, Default = 16 },
    Callback = function(v) Config.WalkSpeed = v end,
})

Tab3:Toggle({
    Title = "High Jump",
    Desc = "Pulo alto (JumpPower 200)",
    Value = false,
    Callback = function(v) Config.HighJump = v end,
})

Tab3:Toggle({
    Title = "Fly (WASD + Space + Ctrl)",
    Desc = "Voar livremente com controle de camera",
    Value = false,
    Callback = function(v) ToggleFly(v) end,
})

Tab3:Slider({
    Title = "Fly Speed",
    Desc = "Velocidade do voo",
    Step = 5,
    Value = { Min = 10, Max = 200, Default = 50 },
    Callback = function(v) Config.FlySpeed = v end,
})

Tab3:Toggle({
    Title = "Anti AFK",
    Desc = "Previne desconexao por inatividade",
    Value = false,
    Callback = function(v) Config.AntiAFK = v end,
})

Tab3:Toggle({
    Title = "Sanidade Infinita",
    Desc = "Mantem sanidade em 100",
    Value = false,
    Callback = function(v) Config.SanityLock = v end,
})

-- TAB 4: SERVIDOR
local Tab4 = Window:Tab({ Title = "Servidor", Icon = "globe" })

Tab4:Paragraph({ Title = "Opcoes de Servidor", Desc = "Gerenciar servidor atual" })

Tab4:Button({
    Title = "Server Hop",
    Desc = "Troca para outro servidor disponivel",
    Callback = function()
        WindUI:Notify({ Title = "Server Hop", Content = "Procurando servidor...", Duration = 3 })
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
    Title = "Informacoes",
    Desc = "Executor: " .. execName .. "\nVersao: v9.0\nby Silverfox Scripts",
})

-- TAB 5: RESET
local Tab5 = Window:Tab({ Title = "Reset", Icon = "settings" })

Tab5:Paragraph({ Title = "Resetar Configuracoes", Desc = "Restaurar valores padrao" })

Tab5:Button({
    Title = "Resetar Velocidade",
    Desc = "Volta WalkSpeed para 16",
    Callback = function()
        Config.WalkSpeed = 16
        local hum = GetHum()
        if hum then hum.WalkSpeed = 16 end
    end,
})

Tab5:Button({
    Title = "DESATIVAR TUDO",
    Desc = "Desliga todas as funcoes de uma vez",
    Callback = function()
        for k in pairs(Config) do
            if type(Config[k]) == "boolean" then Config[k] = false end
        end
        Config.WalkSpeed = 16
        SecretariaBusy = false
        ToggleFly(false)
        RemoverHighlights()
        local hum = GetHum()
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
        end
        WindUI:Notify({ Title = "Reset", Content = "Tudo desativado!", Duration = 3 })
    end,
})

-- ==========================================
-- INIT
-- ==========================================

print("Silverfox Scripts | Hospital v9.0 — carregado com sucesso!")

WindUI:Notify({
    Title  = "Silverfox Scripts",
    Content = "Script carregado! v9.0\nSecretaria, Rooms e Fly corrigidos.",
    Duration = 6,
    Icon   = "check-circle",
})
