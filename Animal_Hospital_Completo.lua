-- =====================================================================
-- SILVERFOX SCRIPTS | HOSPITAL DE ANIMAIS
-- VERSÃO COMPLETA - TODAS AS FUNÇÕES
-- v6.0 | by Silverfox Scripts
-- =====================================================================

local WindUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"
))()

local Window = WindUI:CreateWindow({
    Title = "SILVERFOX SCRIPTS | HOSPITAL",
    Icon = "https://files.catbox.moe/vr0nkt.jpg",
    Author = "by Silverfox Scripts",
    Folder = "SilverfoxHospital",
    Theme = "Dark",
    Size = UDim2.fromOffset(650, 600),
})

Window:Tag({
    Title = "v6.0 COMPLETO",
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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ==========================================
-- CONFIGURAÇÃO
-- ==========================================

_G.HospitalConfig = _G.HospitalConfig or {
    -- ATENDIMENTO
    Secretaria = false,
    Room1 = false, Room2 = false, Room3 = false, Room4 = false, Room5 = false,
    Room6 = false, Room7 = false, Room8 = false,

    -- AUTO FUNÇÕES
    AutoAcceptPatient = false,
    AutoStampClipboard = false,
    AutoCheckIn = false,
    AutoCloseBlinds = false,
    AutoDetectAnomaly = false,
    AutoRejectAnomaly = false,
    AutoBuyUpgrades = false,

    -- VISUAL
    NameESP = false,
    TracerESP = false,

    -- UTILIDADES
    InstantAction = false,
    NoClip = false,
    WalkSpeed = 16,
    Fly = false,
    FlySpeed = 50,
    HighJump = false,
    AntiAFK = false,
    SanityLock = false,
    ServerHop = false,
}

local Config = _G.HospitalConfig

-- ==========================================
-- STATUS DO SCRIPT
-- ==========================================

local ScriptStatus = {
    Ativo = true,
    UltimoLog = os.date("%H:%M:%S"),
    FuncoesAtivas = 0,
}

-- ==========================================
-- CONTROLE DE CONCORRÊNCIA
-- ==========================================

local Mutex = false
local Room8Ativo = false

local function LockMutex()
    while Mutex do task.wait(0.05) end
    Mutex = true
end

local function UnlockMutex()
    Mutex = false
end

local function EsperarRoom8()
    while Room8Ativo do task.wait(0.05) end
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

local function Olhar(targetPos)
    local root = GetRoot()
    if root and targetPos then
        pcall(function()
            root.CFrame = CFrame.lookAt(root.Position, targetPos)
        end)
    end
end

-- ==========================================
-- INTERAÇÃO COM PROMPTS
-- ==========================================

local function Interagir(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then
        return false
    end

    local parent = prompt.Parent
    local targetPos = nil

    if parent and parent:IsA("BasePart") then
        targetPos = parent.Position
    elseif parent then
        local part = parent:FindFirstChildOfClass("BasePart")
        if part then targetPos = part.Position end
    end

    if targetPos then
        Teleportar(targetPos)
        Olhar(targetPos)
        task.wait(0.15)
    end

    if Config.InstantAction then
        pcall(function() prompt.HoldDuration = 0 end)
    end

    local sucesso = false

    if typeof(fireproximityprompt) == "function" then
        pcall(function()
            fireproximityprompt(prompt)
            sucesso = true
        end)
    end

    if not sucesso then
        pcall(function()
            prompt:InputHoldStart(LocalPlayer)
            task.wait(prompt.HoldDuration or 0.05)
            prompt:InputHoldEnd(LocalPlayer)
            sucesso = true
        end)
    end

    return sucesso
end

local function Clicar(parte)
    if not parte then return false end

    local clicker = parte:FindFirstChildOfClass("ClickDetector")
    if clicker then
        local partPos = nil
        if parte:IsA("BasePart") then
            partPos = parte.Position
        else
            local p = parte:FindFirstChildOfClass("BasePart")
            if p then partPos = p.Position end
        end

        if partPos then
            Teleportar(partPos)
            Olhar(partPos)
            task.wait(0.15)
        end

        if typeof(fireclickdetector) == "function" then
            return pcall(function() fireclickdetector(clicker) end)
        end
    end

    local prompt = parte:FindFirstChildOfClass("ProximityPrompt")
    if prompt and prompt.Enabled then
        return Interagir(prompt)
    end

    for _, child in ipairs(parte:GetDescendants()) do
        if child:IsA("ProximityPrompt") and child.Enabled then
            return Interagir(child)
        end
    end

    return false
end

local function BuscarPrompt(texto, onde)
    if not texto or texto == "" then return nil end
    onde = onde or Workspace

    local t = string.lower(texto)
    for _, obj in ipairs(onde:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled and obj.ActionText then
            local a = string.lower(obj.ActionText)
            if string.find(a, t) or string.find(t, a) then
                return obj
            end
        end
    end
    return nil
end

local function TemItem(nome)
    if not nome or nome == "" then return false end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    local char = GetChar()

    local function Checar(onde)
        if not onde then return false end
        for _, tool in ipairs(onde:GetChildren()) do
            if tool:IsA("Tool") and string.find(string.lower(tool.Name), string.lower(nome)) then
                return true
            end
        end
        return false
    end

    return Checar(bp) or Checar(char)
end

local function EquiparItem(nome)
    local bp = LocalPlayer:FindFirstChild("Backpack")
    local hum = GetHum()
    if not bp or not hum then return false end

    for _, tool in ipairs(bp:GetChildren()) do
        if tool:IsA("Tool") and string.find(string.lower(tool.Name), string.lower(nome)) then
            hum:EquipTool(tool)
            task.wait(0.05)
            return true
        end
    end
    return false
end

-- ==========================================
-- FUNÇÕES DE AUTO (NOVA SEÇÃO)
-- ==========================================

-- Auto Accept Patient
local function LoopAutoAcceptPatient()
    while Config.AutoAcceptPatient do
        local npcs = Workspace:FindFirstChild("NPCs")
        if npcs then
            for _, npc in ipairs(npcs:GetChildren()) do
                if npc:FindFirstChildOfClass("Humanoid") then
                    for _, child in ipairs(npc:GetChildren()) do
                        if child:IsA("ProximityPrompt") and child.Enabled then
                            if string.find(string.lower(child.ActionText or ""), "accept") or
                               string.find(string.lower(child.ActionText or ""), "patient") then
                                Interagir(child)
                                task.wait(0.2)
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.5)
    end
end

-- Auto Stamp Clipboard
local function LoopAutoStampClipboard()
    while Config.AutoStampClipboard do
        local misc = Workspace:FindFirstChild("Misc")
        local checkIn = misc and misc:FindFirstChild("CheckIn")

        if checkIn then
            local camera = checkIn:FindFirstChild("Camera")
            if camera then
                local p = BuscarPrompt("stamp", camera) or BuscarPrompt("take", camera) or BuscarPrompt("photo", camera)
                if p then Interagir(p) task.wait(0.3) end
            end
        end
        task.wait(1)
    end
end

-- Auto Check-In
local function LoopAutoCheckIn()
    while Config.AutoCheckIn do
        local misc = Workspace:FindFirstChild("Misc")
        local checkIn = misc and misc:FindFirstChild("CheckIn")

        if checkIn then
            -- Computer
            local computer = checkIn:FindFirstChild("Computer")
            if computer then
                local keyboard = computer:FindFirstChild("Keyboard")
                if keyboard then
                    local clicker = keyboard:FindFirstChild("ClickDetector")
                    if clicker then
                        Teleportar(keyboard.Position + Vector3.new(0, 1, 2))
                        task.wait(0.1)
                        if typeof(fireclickdetector) == "function" then
                            pcall(function() fireclickdetector(clicker) end)
                            task.wait(0.3)
                        end
                    end
                end
            end

            -- Printer
            local printer = checkIn:FindFirstChild("Printer")
            if printer then
                local p = BuscarPrompt("print", printer) or BuscarPrompt("badge", printer)
                if p then Interagir(p) task.wait(0.3) end
            end
        end
        task.wait(1)
    end
end

-- Auto Close Blinds
local function LoopAutoCloseBlinds()
    while Config.AutoCloseBlinds do
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if string.find(string.lower(obj.Name or ""), "blind") or string.find(string.lower(obj.Name or ""), "shutter") then
                local p = obj:FindFirstChildOfClass("ProximityPrompt")
                if p and p.Enabled then
                    if string.find(string.lower(p.ActionText or ""), "close") or
                       string.find(string.lower(p.ActionText or ""), "blind") then
                        Interagir(p)
                        task.wait(0.3)
                    end
                end

                local button = obj:FindFirstChild("Button") or obj:FindFirstChild("Main")
                if button then
                    Clicar(button)
                    task.wait(0.3)
                end
            end
        end
        task.wait(1)
    end
end

-- Auto Detect Anomaly
local anomalyTargets = {}

local function LoopAutoDetectAnomaly()
    while Config.AutoDetectAnomaly do
        anomalyTargets = {}

        -- Procura NPCs que são anomalias
        local npcs = Workspace:FindFirstChild("NPCs")
        if npcs then
            for _, npc in ipairs(npcs:GetChildren()) do
                local name = string.lower(npc.Name or "")
                if string.find(name, "anomaly") or string.find(name, "shadow") or
                   string.find(name, "ghost") or string.find(name, "hollow") or
                   string.find(name, "hider") then
                    local hum = npc:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        table.insert(anomalyTargets, npc)
                    end
                end
            end
        end

        -- Procura no workspace
        for _, char in ipairs(Workspace:GetDescendants()) do
            if char:IsA("Model") and char:FindFirstChildOfClass("Humanoid") then
                local name = string.lower(char.Name or "")
                if string.find(name, "anomaly") or string.find(name, "shadow") or
                   string.find(name, "ghost") or string.find(name, "hollow") then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 and char ~= LocalPlayer.Character then
                        local jaTem = false
                        for _, t in ipairs(anomalyTargets) do
                            if t == char then jaTem = true break end
                        end
                        if not jaTem then
                            table.insert(anomalyTargets, char)
                        end
                    end
                end
            end
        end

        task.wait(2)
    end
end

-- Auto Reject Anomaly
local function LoopAutoRejectAnomaly()
    while Config.AutoRejectAnomaly do
        for _, target in ipairs(anomalyTargets) do
            if target and target.Parent then
                local npcs = Workspace:FindFirstChild("NPCs")
                if npcs then
                    for _, npc in ipairs(npcs:GetChildren()) do
                        if npc:FindFirstChildOfClass("Humanoid") then
                            for _, child in ipairs(npc:GetChildren()) do
                                if child:IsA("ProximityPrompt") and child.Enabled then
                                    if string.find(string.lower(child.ActionText or ""), "reject") or
                                       string.find(string.lower(child.ActionText or ""), "remove") or
                                       string.find(string.lower(child.ActionText or ""), "kick") then
                                        Teleportar(target:FindFirstChild("HumanoidRootPart") and target.HumanoidRootPart.Position or target.Position)
                                        task.wait(0.1)
                                        Interagir(child)
                                        task.wait(0.3)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        task.wait(1)
    end
end

-- Auto Buy Upgrades
local function LoopAutoBuyUpgrades()
    while Config.AutoBuyUpgrades do
        local misc = Workspace:FindFirstChild("Misc")
        if misc then
            -- Procura shop
            for _, obj in ipairs(misc:GetDescendants()) do
                if string.find(string.lower(obj.Name or ""), "shop") or
                   string.find(string.lower(obj.Name or ""), "upgrade") or
                   string.find(string.lower(obj.Name or ""), "buy") then
                    local p = obj:FindFirstChildOfClass("ProximityPrompt")
                    if p and p.Enabled then
                        Interagir(p)
                        task.wait(0.3)
                    end
                end
            end

            -- Shop items
            local shopItems = misc:FindFirstChild("ShopItems")
            if shopItems then
                for _, item in ipairs(shopItems:GetChildren()) do
                    local p = item:FindFirstChildOfClass("ProximityPrompt")
                    if p and p.Enabled then
                        Interagir(p)
                        task.wait(0.3)
                    end
                end
            end
        end
        task.wait(2)
    end
end

-- ==========================================
-- ESP: NAME + TRACER
-- ==========================================

local ESPData = {}

local function CriarESP(player)
    if ESPData[player] then return end

    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- Nome
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "SilverfoxESP"
    billboard.Size = UDim2.fromOffset(100, 30)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.Adornee = root
    billboard.AlwaysOnTop = true

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.fromScale(1, 0.5)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.Name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Parent = billboard

    -- Box
    local box = Instance.new("BoxHandleAdornment")
    box.Name = "ESPBox"
    box.Size = Vector3.new(3, 6, 3)
    box.Adornee = root
    box.AlwaysOnTop = true
    box.Transparency = 0.5

    -- Cor baseada no tipo
    local name = string.lower(player.Name or "")
    local isAnomaly = string.find(name, "anomaly") or string.find(name, "shadow") or
                      string.find(name, "ghost") or string.find(name, "hollow")

    if isAnomaly then
        box.Color3 = Color3.fromRGB(255, 0, 0)
        nameLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    else
        box.Color3 = Color3.fromRGB(0, 255, 0)
        nameLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    end

    box.Parent = root
    billboard.Parent = root

    -- Tracer
    if Config.TracerESP then
        local tracer = Instance.new("LineHandleAdornment")
        tracer.Name = "Tracer"
        tracer.Thickness = 1
        tracer.Transparency = 0.5
        tracer.Color3 = isAnomaly and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 255, 0)
        tracer.Adornee = Camera
        tracer.Parent = Camera
    end

    ESPData[player] = {billboard = billboard, box = box}
end

local function AtualizarESP()
    while Config.NameESP or Config.TracerESP do
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                if Config.NameESP and not ESPData[player] then
                    CriarESP(player)
                elseif not Config.NameESP and ESPData[player] then
                    if ESPData[player].billboard then ESPData[player].billboard:Destroy() end
                    if ESPData[player].box then ESPData[player].box:Destroy() end
                    ESPData[player] = nil
                end
            end
        end
        task.wait(0.5)
    end

    -- Limpa ESP
    for player, data in pairs(ESPData) do
        if data.billboard then data.billboard:Destroy() end
        if data.box then data.box:Destroy() end
    end
    ESPData = {}
end

-- ==========================================
-- SERVER HOP
-- ==========================================

local function ServerHop()
    ScriptStatus.UltimoLog = os.date("%H:%M:%S")
    ScriptStatus.FuncoesAtivas = 0

    local servers = {}
    local cursor = ""

    local HttpService = game:GetService("HttpService")

    for i = 1, 3 do
        local success, response = pcall(function()
            local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
            if cursor ~= "" then
                url = url .. "&cursor=" .. cursor
            end
            return HttpService:GetAsync(url)
        end)

        if success then
            local data = HttpService:JSONDecode(response)
            for _, server in ipairs(data.data) do
                if server.id ~= game.JobId and server.playing < server.maxPlayers then
                    table.insert(servers, server.id)
                end
            end
            if data.nextPageCursor then
                cursor = data.nextPageCursor
            else
                break
            end
        end
    end

    if #servers > 0 then
        local serverId = servers[math.random(1, #servers)]
        TeleportService:TeleportToPlaceInstance(game.PlaceId, serverId, LocalPlayer)
    end
end

-- ==========================================
-- ANTI AFK
-- ==========================================

task.spawn(function()
    while true do
        if Config.AntiAFK then
            local virtualUser = game:GetService("VirtualUser")
            virtualUser:CaptureController()
            virtualUser:ClickButton2(Vector2.new())
        end
        task.wait(30)
    end
end)

-- ==========================================
-- HIGH JUMP
-- ==========================================

task.spawn(function()
    while true do
        if Config.HighJump then
            local hum = GetHum()
            if hum then
                hum.JumpPower = 100
                hum.MaxSlopeAngle = 90
            end
        else
            local hum = GetHum()
            if hum and hum.JumpPower > 50 then
                hum.JumpPower = 50
            end
        end
        task.wait(0.1)
    end
end)

-- ==========================================
-- FLY
-- ==========================================

local Flying = false

local function ToggleFly(state)
    Config.Fly = state
    Flying = state
    local root = GetRoot()
    if not root then return end

    if state then
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(100000, 100000, 100000)
        bv.P = 10000
        bv.Parent = root

        while Flying and Config.Fly do
            local dir = Vector3.new(0, 0, 0)
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
            if dir.Magnitude > 0 then dir = dir.Unit end
            bv.Velocity = dir * Config.FlySpeed
            RunService.RenderStepped:Wait()
        end

        if bv and bv.Parent then bv:Destroy() end
    else
        local bv = root:FindFirstChildOfClass("BodyVelocity")
        if bv then bv:Destroy() end
    end
end

-- Loops auxiliares
task.spawn(function()
    while true do
        if Config.NoClip then
            local char = GetChar()
            if char then
                for _, p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
        end
        task.wait(0.1)
    end
end)

task.spawn(function()
    while true do
        local hum = GetHum()
        if hum then hum.WalkSpeed = Config.WalkSpeed end
        task.wait(0.1)
    end
end)

task.spawn(function()
    while true do
        if Config.SanityLock then
            local misc = Workspace:FindFirstChild("Misc")
            if misc then
                local s = misc:FindFirstChild("sanity")
                if s and (s:IsA("IntValue") or s:IsA("NumberValue")) then
                    pcall(function() s.Value = 100 end)
                end
            end
        end
        task.wait(0.1)
    end
end)

-- ==========================================
-- FUNÇÕES SEPARADAS (EXISTENTES)
-- ==========================================

-- SECRETARIA
local function LoopSecretaria()
    while Config.Secretaria do
        EsperarRoom8()

        local misc = Workspace:FindFirstChild("Misc")
        local checkIn = misc and misc:FindFirstChild("CheckIn")

        if checkIn then
            local camera = checkIn:FindFirstChild("Camera")
            if camera then
                local p = BuscarPrompt("take", camera) or BuscarPrompt("photo", camera) or BuscarPrompt("stamp", camera)
                if p then Interagir(p) task.wait(0.3) end
            end

            local vb = checkIn:FindFirstChild("VisitorBadgeBase")
            if vb then
                local p = BuscarPrompt("take", vb) or BuscarPrompt("visitor", vb)
                if p then Interagir(p) task.wait(0.2) end
            end

            local pb = checkIn:FindFirstChild("PatientBadgeBase")
            if pb then
                local p = BuscarPrompt("take", pb) or BuscarPrompt("patient", pb)
                if p then Interagir(p) task.wait(0.2) end
            end

            local computer = checkIn:FindFirstChild("Computer")
            if computer then
                local keyboard = computer:FindFirstChild("Keyboard")
                if keyboard then
                    local clicker = keyboard:FindFirstChild("ClickDetector")
                    if clicker then
                        Teleportar(keyboard.Position + Vector3.new(0, 1, 2))
                        task.wait(0.15)
                        if typeof(fireclickdetector) == "function" then
                            pcall(function() fireclickdetector(clicker) end)
                            task.wait(0.3)
                        end
                    end
                end
            end

            local printer = checkIn:FindFirstChild("Printer")
            if printer then
                local p = BuscarPrompt("print", printer) or BuscarPrompt("badge", printer)
                if p then Interagir(p) task.wait(0.3) end
            end

            local npcs = Workspace:FindFirstChild("NPCs")
            if npcs then
                for _, npc in ipairs(npcs:GetChildren()) do
                    if npc:FindFirstChildOfClass("Humanoid") then
                        Teleportar(npc.Position + Vector3.new(0, 1, 2))
                        task.wait(0.1)
                        for _, c in ipairs(npc:GetChildren()) do
                            if c:IsA("ProximityPrompt") and c.Enabled then
                                Interagir(c)
                                task.wait(0.2)
                                break
                            end
                        end
                        break
                    end
                end
            end
        end

        task.wait(1)
    end
end

-- ROOMS MEDICAL
local function LoopRoomMedica(num)
    while Config["Room" .. num] do
        EsperarRoom8()

        local rooms = Workspace:FindFirstChild("Rooms")
        local medical = rooms and rooms:FindFirstChild("Medical")
        local room = medical and medical:FindFirstChild("Room" .. num)

        if room then
            local inBed = room:FindFirstChild("InBed")
            if not inBed then
                local mg = room:FindFirstChild("Minigame")
                if mg then
                    local bed = mg:FindFirstChild("Bed")
                    if bed then inBed = bed:FindFirstChild("InBed") end
                end
            end

            if inBed and inBed.Parent then
                Teleportar(inBed.Position + Vector3.new(0, 2, 0))
                task.wait(0.1)

                for _, c in ipairs(inBed:GetChildren()) do
                    if c:IsA("ProximityPrompt") and c.Enabled then
                        Interagir(c)
                        task.wait(0.2)
                    end
                end
            end
        end

        task.wait(0.5)
    end
end

-- ROOM 6
local function LoopRoom6()
    while Config.Room6 do
        EsperarRoom8()

        local rooms = Workspace:FindFirstChild("Rooms")
        local emergency = rooms and rooms:FindFirstChild("Emergency")
        local room6 = emergency and emergency:FindFirstChild("Room6")
        local mg = room6 and room6:FindFirstChild("Minigame")

        if mg then
            local xray = mg:FindFirstChild("xrayMonitor")
            if xray then
                local p = BuscarPrompt("xray", xray)
                if p then Interagir(p) task.wait(1) end
            end

            local colors = mg:FindFirstChild("Colors")
            if colors then
                for _, modelo in ipairs(colors:GetChildren()) do
                    if modelo:IsA("Model") then
                        local btn = modelo:FindFirstChild("Button")
                        if btn and btn:IsA("BasePart") then
                            Clicar(btn)
                            task.wait(0.2)
                        end
                    end
                end
            end

            local xresult = mg:FindFirstChild("xresult")
            if xresult then
                local p = BuscarPrompt("process", xresult)
                if p then Interagir(p) task.wait(0.3) end
            end

            local printer = mg:FindFirstChild("Printer")
            if printer then
                local p = BuscarPrompt("collect", printer)
                if p then Interagir(p) task.wait(0.3) end
            end
        end

        task.wait(0.5)
    end
end

-- ROOM 7
local function LoopRoom7()
    while Config.Room7 do
        EsperarRoom8()

        local rooms = Workspace:FindFirstChild("Rooms")
        local emergency = rooms and rooms:FindFirstChild("Emergency")
        local room7 = emergency and emergency:FindFirstChild("Room7")
        local mg = room7 and room7:FindFirstChild("Minigame")

        if mg then
            local bed = mg:FindFirstChild("Bed")
            if bed then
                local inBed = bed:FindFirstChild("InBed")
                if inBed then
                    Teleportar(inBed.Position + Vector3.new(0, 1, 1))
                    task.wait(0.1)
                    for _, c in ipairs(inBed:GetChildren()) do
                        if c:IsA("ProximityPrompt") and c.Enabled then
                            Interagir(c)
                            task.wait(0.2)
                        end
                    end
                end
            end

            local machine = mg:FindFirstChild("Machine")
            if machine then
                local p = BuscarPrompt("use", machine)
                if p then Interagir(p) task.wait(0.2) end
            end

            local curtains = room7:FindFirstChild("Curtains")
            if curtains then
                local open = curtains:FindFirstChild("Open")
                if open then Clicar(open) task.wait(0.2) end
            end
        end

        task.wait(0.5)
    end
end

-- ROOM 8
local function LoopRoom8()
    while Config.Room8 do
        local rooms = Workspace:FindFirstChild("Rooms")
        local emergency = rooms and rooms:FindFirstChild("Emergency")
        local room8 = emergency and emergency:FindFirstChild("Room8")
        local mg = room8 and room8:FindFirstChild("Minigame")

        if mg then
            local inBed = mg:FindFirstChild("Bed")
            if inBed then inBed = inBed:FindFirstChild("InBed") end
            if not inBed then inBed = mg:FindFirstChild("InBed") end

            if inBed then
                local temPrompt = false
                for _, c in ipairs(inBed:GetChildren()) do
                    if c:IsA("ProximityPrompt") and c.Enabled then temPrompt = true break end
                end

                if temPrompt then
                    Room8Ativo = true

                    Teleportar(inBed.Position + Vector3.new(0, 1, 1))
                    task.wait(0.1)

                    for _, c in ipairs(inBed:GetChildren()) do
                        if c:IsA("ProximityPrompt") and c.Enabled then
                            Interagir(c)
                            task.wait(0.3)
                        end
                    end

                    Room8Ativo = false
                end
            end
        end

        task.wait(0.3)
    end

    Room8Ativo = false
end

-- ==========================================
-- INTERFACE
-- ==========================================

-- TAB 1: ATENDIMENTO
local Tab1 = Window:Tab({
    Title = "Atendimento",
    Icon = "home"
})

Tab1:Label("Funções de ATENDIMENTO do Hospital")

Tab1:Toggle({
    Title = "Secretaria (Check-in)",
    Desc = "Camera, Badge, PC, Printer, NPCs",
    Value = false,
    Callback = function(state)
        Config.Secretaria = state
        if state then task.spawn(LoopSecretaria) end
    end,
})

Tab1:Label("")
Tab1:Label("Rooms Medical:")

for i = 1, 5 do
    Tab1:Toggle({
        Title = "Room " .. i,
        Desc = "Medical",
        Value = false,
        Callback = function(state)
            Config["Room" .. i] = state
            if state then task.spawn(function() LoopRoomMedica(i) end) end
        end,
    })
end

Tab1:Label("")
Tab1:Label("Rooms Emergency:")

Tab1:Toggle({
    Title = "Room 6 (X-Ray)",
    Desc = "X-Ray + Cores",
    Value = false,
    Callback = function(state)
        Config.Room6 = state
        if state then task.spawn(LoopRoom6) end
    end,
})

Tab1:Toggle({
    Title = "Room 7",
    Desc = "Máquina + Monitor",
    Value = false,
    Callback = function(state)
        Config.Room7 = state
        if state then task.spawn(LoopRoom7) end
    end,
})

Tab1:Toggle({
    Title = "Room 8 (CIRURGIA)",
    Desc = "PRIORIDADE MÁXIMA",
    Value = false,
    Callback = function(state)
        Config.Room8 = state
        if state then task.spawn(LoopRoom8) end
    end,
})

-- TAB 2: AUTO FUNÇÕES
local Tab2 = Window:Tab({
    Title = "Auto",
    Icon = "sparkles"
})

Tab2:Label("Funções AUTOMÁTICAS do Hospital")

Tab2:Toggle({
    Title = "Auto Accept Patient",
    Desc = "Aceita pacientes automaticamente",
    Value = false,
    Callback = function(state)
        Config.AutoAcceptPatient = state
        if state then task.spawn(LoopAutoAcceptPatient) end
    end,
})

Tab2:Toggle({
    Title = "Auto Stamp Clipboard",
    Desc = "Stampa o clipboard automaticamente",
    Value = false,
    Callback = function(state)
        Config.AutoStampClipboard = state
        if state then task.spawn(LoopAutoStampClipboard) end
    end,
})

Tab2:Toggle({
    Title = "Auto Check-In",
    Desc = "Faz check-in automaticamente",
    Value = false,
    Callback = function(state)
        Config.AutoCheckIn = state
        if state then task.spawn(LoopAutoCheckIn) end
    end,
})

Tab2:Toggle({
    Title = "Auto Close Blinds",
    Desc = "Fecha persianas automaticamente",
    Value = false,
    Callback = function(state)
        Config.AutoCloseBlinds = state
        if state then task.spawn(LoopAutoCloseBlinds) end
    end,
})

Tab2:Toggle({
    Title = "Auto Detect Anomaly",
    Desc = "Detecta anomalias no mapa",
    Value = false,
    Callback = function(state)
        Config.AutoDetectAnomaly = state
        if state then task.spawn(LoopAutoDetectAnomaly) end
    end,
})

Tab2:Toggle({
    Title = "Auto Reject Anomaly",
    Desc = "Rejeita anomalias detectadas",
    Value = false,
    Callback = function(state)
        Config.AutoRejectAnomaly = state
        if state then task.spawn(LoopAutoRejectAnomaly) end
    end,
})

Tab2:Toggle({
    Title = "Auto Buy Upgrades",
    Desc = "Compra upgrades automaticamente",
    Value = false,
    Callback = function(state)
        Config.AutoBuyUpgrades = state
        if state then task.spawn(LoopAutoBuyUpgrades) end
    end,
})

-- TAB 3: VISUAL
local Tab3 = Window:Tab({
    Title = "Visual",
    Icon = "eye"
})

Tab3:Label("Recursos Visuais")

Tab3:Toggle({
    Title = "Name ESP",
    Desc = "Mostra nome dos jogadores",
    Value = false,
    Callback = function(state)
        Config.NameESP = state
        if state or Config.TracerESP then task.spawn(AtualizarESP) end
    end,
})

Tab3:Toggle({
    Title = "Tracer ESP",
    Desc = "Linhas até os jogadores",
    Value = false,
    Callback = function(state)
        Config.TracerESP = state
        if state or Config.NameESP then task.spawn(AtualizarESP) end
    end,
})

Tab3:Label("Vermelho = Anomaly | Verde = Normal")

-- TAB 4: UTILIDADES
local Tab4 = Window:Tab({
    Title = "Utilitários",
    Icon = "user"
})

Tab4:Toggle({
    Title = "Instant Action",
    Desc = "Remove delay dos prompts",
    Value = false,
    Callback = function(state)
        Config.InstantAction = state
    end,
})

Tab4:Toggle({
    Title = "NoClip",
    Desc = "Atravessa paredes",
    Value = false,
    Callback = function(state)
        Config.NoClip = state
    end,
})

Tab4:Slider({
    Title = "WalkSpeed",
    Desc = "Velocidade do personagem",
    Step = 1,
    Value = {Min = 16, Max = 200, Default = 16},
    Callback = function(val)
        Config.WalkSpeed = val
    end,
})

Tab4:Toggle({
    Title = "High Jump",
    Desc = "Pulo alto",
    Value = false,
    Callback = function(state)
        Config.HighJump = state
    end,
})

Tab4:Toggle({
    Title = "Fly",
    Desc = "WASD + Espaço/Ctrl",
    Value = false,
    Callback = function(state)
        ToggleFly(state)
    end,
})

Tab4:Slider({
    Title = "Fly Speed",
    Desc = "Velocidade do voo",
    Step = 5,
    Value = {Min = 10, Max = 200, Default = 50},
    Callback = function(val)
        Config.FlySpeed = val
    end,
})

Tab4:Toggle({
    Title = "Anti AFK",
    Desc = "Evita kick por inatividade",
    Value = false,
    Callback = function(state)
        Config.AntiAFK = state
    end,
})

Tab4:Toggle({
    Title = "Sanidade Infinita",
    Desc = "Mantém sanidade em 100",
    Value = false,
    Callback = function(state)
        Config.SanityLock = state
    end,
})

-- TAB 5: SERVIDOR
local Tab5 = Window:Tab({
    Title = "Servidor",
    Icon = "globe"
})

Tab5:Button({
    Title = "Server Hop",
    Desc = "Troca para outro servidor",
    Callback = function()
        WindUI:Notify({
            Title = "Server Hop",
            Content = "Trocando de servidor...",
            Duration = 3,
            Icon = "globe",
        })
        task.wait(1)
        ServerHop()
    end,
})

Tab5:Label("")
Tab5:Label("INFORMAÇÕES DO EXECUTOR:")

local executorName = "Desconhecido"
local executorVersion = "?"

if identifyexecutor then
    local ok, name, ver = pcall(identifyexecutor)
    if ok then
        executorName = name or "Desconhecido"
        executorVersion = ver or "?"
    end
end

Tab5:Label("Executor: " .. executorName)
Tab5:Label("Versão: " .. tostring(executorVersion))

Tab5:Label("")
Tab5:Label("STATUS DO SCRIPT:")
Tab5:Label("Status: ATIVO ✅")
Tab5:Label("Versão: v6.0")
Tab5:Label("Feito por: Silverfox Scripts")

-- TAB 6: RESET
local Tab6 = Window:Tab({
    Title = "Config",
    Icon = "settings"
})

Tab6:Button({
    Title = "Resetar Velocidade",
    Desc = "Volta pra 16",
    Callback = function()
        Config.WalkSpeed = 16
        local hum = GetHum()
        if hum then hum.WalkSpeed = 16 end
    end,
})

Tab6:Button({
    Title = "DESATIVAR TUDO",
    Desc = "Desliga todas as funções",
    Callback = function()
        -- Reset configs
        Config.Secretaria = false
        Config.Room1 = false
        Config.Room2 = false
        Config.Room3 = false
        Config.Room4 = false
        Config.Room5 = false
        Config.Room6 = false
        Config.Room7 = false
        Config.Room8 = false
        Config.AutoAcceptPatient = false
        Config.AutoStampClipboard = false
        Config.AutoCheckIn = false
        Config.AutoCloseBlinds = false
        Config.AutoDetectAnomaly = false
        Config.AutoRejectAnomaly = false
        Config.AutoBuyUpgrades = false
        Config.NameESP = false
        Config.TracerESP = false
        Config.NoClip = false
        Config.WalkSpeed = 16
        Config.HighJump = false
        Config.SanityLock = false
        Config.InstantAction = false
        Config.AntiAFK = false
        Room8Ativo = false

        ToggleFly(false)

        local hum = GetHum()
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
        end
    end,
})

-- ==========================================
-- INICIALIZAÇÃO
-- ==========================================

print("=================================")
print("Silverfox Scripts | Hospital v6.0")
print("TODAS AS FUNÇÕES ATIVAS")
print("=================================")

WindUI:Notify({
    Title = "Silverfox Scripts",
    Content = "Script completo carregado!\n" .. executorName .. " v" .. tostring(executorVersion) .. "\nVersão: v6.0",
    Duration = 5,
    Icon = "check-circle",
})
