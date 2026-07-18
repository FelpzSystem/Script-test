-- =====================================================================
-- SILVERFOX SCRIPTS | HOSPITAL DE ANIMAIS
-- VERSÃO CORRIGIDA v6.1
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
    Size = UDim2.fromOffset(620, 580),
})

Window:Tag({
    Title = "v6.1 CORRIGIDO",
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
    Room1 = false, Room2 = false, Room3 = false, Room4 = false, Room5 = false,
    Room6 = false, Room7 = false, Room8 = false,
    AutoAcceptPatient = false,
    AutoStampClipboard = false,
    AutoCheckIn = false,
    AutoCloseBlinds = false,
    AutoDetectAnomaly = false,
    AutoRejectAnomaly = false,
    AutoBuyUpgrades = false,
    NameESP = false,
    TracerESP = false,
    InstantAction = false,
    NoClip = false,
    WalkSpeed = 16,
    Fly = false,
    FlySpeed = 50,
    HighJump = false,
    AntiAFK = false,
    SanityLock = false,
}

local Config = _G.HospitalConfig

-- ==========================================
-- CONTROLE
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
        local partPos = parte:IsA("BasePart") and parte.Position or (parte:FindFirstChildOfClass("BasePart") or {}).Position
        if partPos then
            Teleportar(partPos)
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

-- ==========================================
-- LOOPS DE AUTO
-- ==========================================

local anomalyTargets = {}

task.spawn(function()
    while wait(2) do
        if Config.AutoDetectAnomaly then
            anomalyTargets = {}
            local npcs = Workspace:FindFirstChild("NPCs")
            if npcs then
                for _, npc in ipairs(npcs:GetChildren()) do
                    local name = string.lower(npc.Name or "")
                    if string.find(name, "anomaly") or string.find(name, "shadow") or
                       string.find(name, "ghost") or string.find(name, "hollow") then
                        local hum = npc:FindFirstChildOfClass("Humanoid")
                        if hum and hum.Health > 0 then
                            table.insert(anomalyTargets, npc)
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while wait(0.5) do
        if Config.AutoAcceptPatient then
            local npcs = Workspace:FindFirstChild("NPCs")
            if npcs then
                for _, npc in ipairs(npcs:GetChildren()) do
                    if npc:FindFirstChildOfClass("Humanoid") then
                        for _, child in ipairs(npc:GetChildren()) do
                            if child:IsA("ProximityPrompt") and child.Enabled then
                                if string.find(string.lower(child.ActionText or ""), "accept") then
                                    Interagir(child)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while wait(1) do
        if Config.AutoStampClipboard then
            local misc = Workspace:FindFirstChild("Misc")
            local checkIn = misc and misc:FindFirstChild("CheckIn")
            if checkIn then
                local camera = checkIn:FindFirstChild("Camera")
                if camera then
                    local p = BuscarPrompt("stamp", camera) or BuscarPrompt("take", camera)
                    if p then Interagir(p) end
                end
            end
        end
    end
end)

task.spawn(function()
    while wait(1) do
        if Config.AutoCheckIn then
            local misc = Workspace:FindFirstChild("Misc")
            local checkIn = misc and misc:FindFirstChild("CheckIn")
            if checkIn then
                local computer = checkIn:FindFirstChild("Computer")
                if computer then
                    local keyboard = computer:FindFirstChild("Keyboard")
                    if keyboard then
                        local clicker = keyboard:FindFirstChild("ClickDetector")
                        if clicker and typeof(fireclickdetector) == "function" then
                            Teleportar(keyboard.Position + Vector3.new(0, 1, 2))
                            pcall(function() fireclickdetector(clicker) end)
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while wait(2) do
        if Config.AutoRejectAnomaly then
            for _, target in ipairs(anomalyTargets) do
                if target and target.Parent then
                    local npcs = Workspace:FindFirstChild("NPCs")
                    if npcs then
                        for _, npc in ipairs(npcs:GetChildren()) do
                            if npc:FindFirstChildOfClass("Humanoid") then
                                for _, child in ipairs(npc:GetChildren()) do
                                    if child:IsA("ProximityPrompt") and child.Enabled then
                                        if string.find(string.lower(child.ActionText or ""), "reject") then
                                            Interagir(child)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while wait(2) do
        if Config.AutoBuyUpgrades then
            local misc = Workspace:FindFirstChild("Misc")
            if misc then
                local shop = misc:FindFirstChild("ShopItems")
                if shop then
                    for _, item in ipairs(shop:GetChildren()) do
                        local p = item:FindFirstChildOfClass("ProximityPrompt")
                        if p and p.Enabled then
                            Interagir(p)
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while wait(1) do
        if Config.AutoCloseBlinds then
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if string.find(string.lower(obj.Name or ""), "blind") or string.find(string.lower(obj.Name or ""), "shutter") then
                    local p = obj:FindFirstChildOfClass("ProximityPrompt")
                    if p and p.Enabled then
                        Interagir(p)
                    end
                end
            end
        end
    end
end)

-- ==========================================
-- ESP
-- ==========================================

task.spawn(function()
    while wait(0.5) do
        if Config.NameESP or Config.TracerESP then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local root = player.Character:FindFirstChild("HumanoidRootPart")
                    if root then
                        local name = string.lower(player.Name or "")
                        local isAnomaly = string.find(name, "anomaly") or string.find(name, "shadow") or
                                          string.find(name, "ghost") or string.find(name, "hollow")

                        if Config.NameESP then
                            local billboard = root:FindFirstChild("ESP_Billboard")
                            if not billboard then
                                billboard = Instance.new("BillboardGui")
                                billboard.Name = "ESP_Billboard"
                                billboard.Size = UDim2.fromOffset(80, 25)
                                billboard.StudsOffset = Vector3.new(0, 3, 0)
                                billboard.Adornee = root
                                billboard.AlwaysOnTop = true
                                billboard.Parent = root

                                local label = Instance.new("TextLabel")
                                label.Size = UDim2.fromScale(1, 1)
                                label.BackgroundTransparency = 1
                                label.Text = player.Name
                                label.TextColor3 = isAnomaly and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(100, 255, 100)
                                label.TextScaled = true
                                label.Font = Enum.Font.GothamBold
                                label.Parent = billboard
                            end
                        end
                    end
                end
            end
        else
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character then
                    local root = player.Character:FindFirstChild("HumanoidRootPart")
                    if root then
                        local esp = root:FindFirstChild("ESP_Billboard")
                        if esp then esp:Destroy() end
                    end
                end
            end
        end
    end
end)

-- ==========================================
-- UTILIDADES
-- ==========================================

local Flying = false

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
        wait(0.1)
    end
end)

task.spawn(function()
    while true do
        local hum = GetHum()
        if hum then hum.WalkSpeed = Config.WalkSpeed end
        wait(0.1)
    end
end)

task.spawn(function()
    while true do
        if Config.HighJump then
            local hum = GetHum()
            if hum then hum.JumpPower = 100 end
        else
            local hum = GetHum()
            if hum and hum.JumpPower > 50 then hum.JumpPower = 50 end
        end
        wait(0.1)
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
        wait(0.1)
    end
end)

task.spawn(function()
    while true do
        if Config.AntiAFK then
            local vu = game:GetService("VirtualUser")
            vu:CaptureController()
            vu:ClickButton2(Vector2.new())
        end
        wait(30)
    end
end)

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

-- ==========================================
-- LOOPS DE ATENDIMENTO
-- ==========================================

task.spawn(function()
    while wait(1) do
        if Config.Secretaria then
            EsperarRoom8()
            local misc = Workspace:FindFirstChild("Misc")
            local checkIn = misc and misc:FindFirstChild("CheckIn")
            if checkIn then
                local camera = checkIn:FindFirstChild("Camera")
                if camera then
                    local p = BuscarPrompt("take", camera) or BuscarPrompt("photo", camera)
                    if p then Interagir(p) end
                end

                local vb = checkIn:FindFirstChild("VisitorBadgeBase")
                if vb then
                    local p = BuscarPrompt("take", vb)
                    if p then Interagir(p) end
                end

                local computer = checkIn:FindFirstChild("Computer")
                if computer then
                    local keyboard = computer:FindFirstChild("Keyboard")
                    if keyboard then
                        local clicker = keyboard:FindFirstChild("ClickDetector")
                        if clicker and typeof(fireclickdetector) == "function" then
                            Teleportar(keyboard.Position + Vector3.new(0, 1, 2))
                            pcall(function() fireclickdetector(clicker) end)
                        end
                    end
                end

                local printer = checkIn:FindFirstChild("Printer")
                if printer then
                    local p = BuscarPrompt("print", printer)
                    if p then Interagir(p) end
                end
            end
        end
    end
end)

for i = 1, 5 do
    task.spawn(function(n)
        while wait(0.5) do
            if Config["Room" .. n] then
                EsperarRoom8()
                local rooms = Workspace:FindFirstChild("Rooms")
                local medical = rooms and rooms:FindFirstChild("Medical")
                local room = medical and medical:FindFirstChild("Room" .. n)
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
                        wait(0.1)
                        for _, c in ipairs(inBed:GetChildren()) do
                            if c:IsA("ProximityPrompt") and c.Enabled then
                                Interagir(c)
                            end
                        end
                    end
                end
            end
        end
    end, i)
end

task.spawn(function()
    while wait(0.5) do
        if Config.Room6 then
            EsperarRoom8()
            local rooms = Workspace:FindFirstChild("Rooms")
            local emergency = rooms and rooms:FindFirstChild("Emergency")
            local room6 = emergency and emergency:FindFirstChild("Room6")
            local mg = room6 and room6:FindFirstChild("Minigame")
            if mg then
                local xray = mg:FindFirstChild("xrayMonitor")
                if xray then
                    local p = BuscarPrompt("xray", xray)
                    if p then Interagir(p) end
                end

                local colors = mg:FindFirstChild("Colors")
                if colors then
                    for _, modelo in ipairs(colors:GetChildren()) do
                        if modelo:IsA("Model") then
                            local btn = modelo:FindFirstChild("Button")
                            if btn and btn:IsA("BasePart") then
                                Clicar(btn)
                            end
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while wait(0.5) do
        if Config.Room7 then
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
                        wait(0.1)
                        for _, c in ipairs(inBed:GetChildren()) do
                            if c:IsA("ProximityPrompt") and c.Enabled then
                                Interagir(c)
                            end
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while wait(0.3) do
        if Config.Room8 then
            local rooms = Workspace:FindFirstChild("Rooms")
            local emergency = rooms and rooms:FindFirstChild("Emergency")
            local room8 = emergency and emergency:FindFirstChild("Room8")
            local mg = room8 and room8:FindFirstChild("Minigame")
            if mg then
                local inBed = (mg:FindFirstChild("Bed") or {}):FindFirstChild("InBed") or mg:FindFirstChild("InBed")
                if inBed then
                    local temPrompt = false
                    for _, c in ipairs(inBed:GetChildren()) do
                        if c:IsA("ProximityPrompt") and c.Enabled then temPrompt = true break end
                    end

                    if temPrompt then
                        Room8Ativo = true
                        Teleportar(inBed.Position + Vector3.new(0, 1, 1))
                        wait(0.1)
                        for _, c in ipairs(inBed:GetChildren()) do
                            if c:IsA("ProximityPrompt") and c.Enabled then
                                Interagir(c)
                            end
                        end
                        Room8Ativo = false
                    end
                end
            end
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

Tab1:Label("Hospital - Funcoes de Atendimento")

Tab1:Toggle({
    Title = "Secretaria",
    Value = false,
    Callback = function(v) Config.Secretaria = v end,
})

for i = 1, 5 do
    Tab1:Toggle({
        Title = "Room " .. i .. " (Medical)",
        Value = false,
        Callback = function(v) Config["Room" .. i] = v end,
    })
end

Tab1:Toggle({
    Title = "Room 6 (X-Ray)",
    Value = false,
    Callback = function(v) Config.Room6 = v end,
})

Tab1:Toggle({
    Title = "Room 7",
    Value = false,
    Callback = function(v) Config.Room7 = v end,
})

Tab1:Toggle({
    Title = "Room 8 (Cirurgia)",
    Value = false,
    Callback = function(v) Config.Room8 = v end,
})

-- TAB 2: AUTO
local Tab2 = Window:Tab({Title = "Auto", Icon = "sparkles"})

Tab2:Label("Funcoes Automaticas")

Tab2:Toggle({
    Title = "Auto Accept Patient",
    Value = false,
    Callback = function(v) Config.AutoAcceptPatient = v end,
})

Tab2:Toggle({
    Title = "Auto Stamp Clipboard",
    Value = false,
    Callback = function(v) Config.AutoStampClipboard = v end,
})

Tab2:Toggle({
    Title = "Auto Check-In",
    Value = false,
    Callback = function(v) Config.AutoCheckIn = v end,
})

Tab2:Toggle({
    Title = "Auto Close Blinds",
    Value = false,
    Callback = function(v) Config.AutoCloseBlinds = v end,
})

Tab2:Toggle({
    Title = "Auto Detect Anomaly",
    Value = false,
    Callback = function(v) Config.AutoDetectAnomaly = v end,
})

Tab2:Toggle({
    Title = "Auto Reject Anomaly",
    Value = false,
    Callback = function(v) Config.AutoRejectAnomaly = v end,
})

Tab2:Toggle({
    Title = "Auto Buy Upgrades",
    Value = false,
    Callback = function(v) Config.AutoBuyUpgrades = v end,
})

-- TAB 3: VISUAL
local Tab3 = Window:Tab({Title = "Visual", Icon = "eye"})

Tab3:Label("Recursos Visuais")

Tab3:Toggle({
    Title = "Name ESP",
    Desc = "Vermelho = Anomaly | Verde = Normal",
    Value = false,
    Callback = function(v) Config.NameESP = v end,
})

Tab3:Toggle({
    Title = "Instant Action",
    Desc = "Remove delay dos prompts",
    Value = false,
    Callback = function(v) Config.InstantAction = v end,
})

-- TAB 4: UTILIDADES
local Tab4 = Window:Tab({Title = "Utilidades", Icon = "user"})

Tab4:Label("Controles do Personagem")

Tab4:Toggle({
    Title = "NoClip",
    Value = false,
    Callback = function(v) Config.NoClip = v end,
})

Tab4:Slider({
    Title = "WalkSpeed",
    Step = 1,
    Value = {Min = 16, Max = 200, Default = 16},
    Callback = function(v) Config.WalkSpeed = v end,
})

Tab4:Toggle({
    Title = "High Jump",
    Value = false,
    Callback = function(v) Config.HighJump = v end,
})

Tab4:Toggle({
    Title = "Fly (WASD+Space+Ctrl)",
    Value = false,
    Callback = function(v) ToggleFly(v) end,
})

Tab4:Slider({
    Title = "Fly Speed",
    Step = 5,
    Value = {Min = 10, Max = 200, Default = 50},
    Callback = function(v) Config.FlySpeed = v end,
})

Tab4:Toggle({
    Title = "Anti AFK",
    Value = false,
    Callback = function(v) Config.AntiAFK = v end,
})

Tab4:Toggle({
    Title = "Sanidade Infinita",
    Value = false,
    Callback = function(v) Config.SanityLock = v end,
})

-- TAB 5: SERVIDOR
local Tab5 = Window:Tab({Title = "Servidor", Icon = "globe"})

Tab5:Label("Opcoes de Servidor")

Tab5:Button({
    Title = "Server Hop",
    Desc = "Troca para outro servidor",
    Callback = function()
        WindUI:Notify({Title = "Server Hop", Content = "Trocando servidor...", Duration = 3})
        task.wait(1)
        ServerHop()
    end,
})

Tab5:Label("")
Tab5:Label("Info do Executor:")

local execName = "Desconhecido"
if identifyexecutor then
    local ok, name = pcall(identifyexecutor)
    if ok then execName = name or "Desconhecido" end
end

Tab5:Label("Executor: " .. execName)
Tab5:Label("Versao: v6.1")
Tab5:Label("by Silverfox Scripts")

-- TAB 6: RESET
local Tab6 = Window:Tab({Title = "Reset", Icon = "settings"})

Tab6:Label("Resetar Configuracoes")

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
    Desc = "Desliga todas as funcoes",
    Callback = function()
        for k in pairs(Config) do
            if type(Config[k]) == "boolean" then
                Config[k] = false
            end
        end
        Config.WalkSpeed = 16
        Room8Ativo = false
        ToggleFly(false)
        local hum = GetHum()
        if hum then hum.WalkSpeed = 16 hum.JumpPower = 50 end
    end,
})

-- ==========================================
-- INIT
-- ==========================================

print("Silverfox Scripts | Hospital v6.1 CORRIGIDO")

WindUI:Notify({
    Title = "Silverfox Scripts",
    Content = "Script carregado!\nVersao: v6.1",
    Duration = 5,
    Icon = "check-circle",
})
