-- =====================================================================
-- SILVERFOX SCRIPTS | HOSPITAL DE ANIMAIS
-- VERSÃO CORRIGIDA v6.2
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
    Title = "v6.2 CORRIGIDO",
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
                local p = nil

                -- 1) Busca pelo nome do objeto "Formulário(s) de Selo" em qualquer lugar do CheckIn
                for _, obj in ipairs(checkIn:GetDescendants()) do
                    if obj:IsA("ProximityPrompt") and obj.Enabled then
                        local parentName = string.lower(obj.Parent and obj.Parent.Name or "")
                        local actionText = string.lower(obj.ActionText or "")
                        if string.find(parentName, "formul") or string.find(parentName, "selo") or
                           string.find(actionText, "carimb") or string.find(actionText, "stamp") or
                           string.find(actionText, "formul") then
                            p = obj
                            break
                        end
                    end
                end

                -- 2) Fallback: qualquer prompt habilitado dentro da Camera (caso volte a ser lá)
                if not p then
                    local camera = checkIn:FindFirstChild("Camera")
                    if camera then
                        for _, c in ipairs(camera:GetDescendants()) do
                            if c:IsA("ProximityPrompt") and c.Enabled then
                                p = c
                                break
                            end
                        end
                    end
                end

                -- 3) Último fallback: qualquer prompt habilitado em todo o CheckIn que não seja de outra função conhecida
                if not p then
                    for _, obj in ipairs(checkIn:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") and obj.Enabled then
                            local parentName = string.lower(obj.Parent and obj.Parent.Name or "")
                            if not string.find(parentName, "computer") and
                               not string.find(parentName, "printer") and
                               not string.find(parentName, "badge") then
                                p = obj
                                break
                            end
                        end
                    end
                end

                if p then Interagir(p) end
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
                    -- 1) Prompt do formulário direto no Computer (PP)
                    local formPrompt = computer:FindFirstChild("PP")
                    if formPrompt and formPrompt:IsA("ProximityPrompt") and formPrompt.Enabled then
                        Interagir(formPrompt)
                        task.wait(0.15)
                    end

                    -- 2) Clicker do teclado (Computer.Keyboard.Keyboard.Clicker)
                    local keyboard = computer:FindFirstChild("Keyboard")
                    local realKeyboard = keyboard and keyboard:FindFirstChild("Keyboard")
                    if realKeyboard then
                        local clicker = realKeyboard:FindFirstChild("Clicker")
                        if clicker and typeof(fireclickdetector) == "function" then
                            Teleportar(realKeyboard.Position + Vector3.new(0, 1, 2))
                            task.wait(0.15)
                            pcall(function() fireclickdetector(clicker) end)
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while wait(0.8) do
        if Config.NameESP then
            local npcs = Workspace:FindFirstChild("NPCs")
            if npcs then
                for _, npc in ipairs(npcs:GetChildren()) do
                    local humanoid = npc:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        local tag = npc:FindFirstChild("ESPName")
                        if not tag then
                            tag = Instance.new("BillboardGui")
                            tag.Name = "ESPName"
                            tag.MaxDistance = math.huge
                            tag.Size = UDim2.new(2, 0, 2, 0)
                            tag.Parent = npc:FindFirstChild("Head") or npc
                            
                            local label = Instance.new("TextLabel")
                            label.Size = UDim2.new(1, 0, 1, 0)
                            label.BackgroundTransparency = 1
                            label.TextSize = 13
                            label.Parent = tag
                            
                            local nameStr = string.lower(npc.Name or "")
                            if string.find(nameStr, "anomaly") or string.find(nameStr, "shadow") or 
                               string.find(nameStr, "ghost") then
                                label.TextColor3 = Color3.fromRGB(255, 0, 0)
                            else
                                label.TextColor3 = Color3.fromRGB(0, 255, 0)
                            end
                            label.Text = npc.Name
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
            local rooms = Workspace:FindFirstChild("Rooms")
            if rooms then
                for _, room in ipairs(rooms:GetDescendants()) do
                    if room:IsA("ProximityPrompt") and room.Enabled then
                        if string.find(string.lower(room.ActionText or ""), "close") or 
                           string.find(string.lower(room.ActionText or ""), "blind") then
                            Interagir(room)
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while wait(1) do
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
    while wait(0.1) do
        if Config.WalkSpeed and Config.WalkSpeed ~= 16 then
            local hum = GetHum()
            if hum then
                hum.WalkSpeed = Config.WalkSpeed
            end
        end
    end
end)

task.spawn(function()
    while wait(0.1) do
        if Config.HighJump then
            local hum = GetHum()
            if hum then
                hum.JumpPower = 200
            end
        else
            local hum = GetHum()
            if hum then
                hum.JumpPower = 50
            end
        end
    end
end)

task.spawn(function()
    while wait(2) do
        if Config.AntiAFK then
            local hum = GetHum()
            if hum then
                local args = {
                    [1] = true
                }
                game:GetService("Players"):FindFirstChild("LocalPlayer"):FindFirstChildOfClass("Humanoid"):TakeDamage(0)
            end
        end
    end
end)

task.spawn(function()
    while wait(0.5) do
        if Config.SanityLock then
            local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
            if leaderstats and leaderstats:FindFirstChild("Sanidade") then
                leaderstats.Sanidade.Value = 100
            end
        end
    end
end)

local FlyingEnabled = false
local FlyingConnection = nil

local function ToggleFly(enabled)
    Config.Fly = enabled
    
    if FlyingConnection then
        FlyingConnection:Disconnect()
        FlyingConnection = nil
    end
    
    if not enabled then return end
    
    FlyingEnabled = true
    local root = GetRoot()
    if not root then FlyingEnabled = false return end
    
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVelocity.Parent = root
    
    local flying = true
    FlyingConnection = RunService.Heartbeat:Connect(function()
        if not Config.Fly or not root or not root.Parent then
            if bodyVelocity and bodyVelocity.Parent then
                bodyVelocity:Destroy()
            end
            flying = false
            FlyingEnabled = false
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

task.spawn(function()
    while wait(0.5) do
        if Config.AutoBuyUpgrades then
            local misc = Workspace:FindFirstChild("Misc")
            if misc then
                for _, item in ipairs(misc:GetDescendants()) do
                    if item:IsA("ProximityPrompt") and item.Enabled then
                        if string.find(string.lower(item.ActionText or ""), "buy") or 
                           string.find(string.lower(item.ActionText or ""), "upgrade") then
                            Interagir(item)
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while wait(1) do
        if Config.AutoRejectAnomaly then
            if #anomalyTargets > 0 then
                for _, anomaly in ipairs(anomalyTargets) do
                    if anomaly and anomaly.Parent then
                        local found = false
                        for _, child in ipairs(anomaly:GetChildren()) do
                            if child:IsA("ProximityPrompt") and child.Enabled then
                                if string.find(string.lower(child.ActionText or ""), "reject") then
                                    Interagir(child)
                                    found = true
                                    break
                                end
                            end
                        end
                        if found then break end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while wait(1) do
        if Config.Room1 or Config.Room2 or Config.Room3 or Config.Room4 or Config.Room5 then
            for i = 1, 5 do
                if Config["Room" .. i] then
                    local rooms = Workspace:FindFirstChild("Rooms")
                    if rooms then
                        local medical = rooms:FindFirstChild("Medical")
                        if medical then
                            local room = medical:FindFirstChild("Room" .. i)
                            if room then
                                for _, child in ipairs(room:GetDescendants()) do
                                    if child:IsA("ProximityPrompt") and child.Enabled then
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
end)

task.spawn(function()
    while wait(1) do
        if Config.Room6 then
            local rooms = Workspace:FindFirstChild("Rooms")
            if rooms then
                local emergency = rooms:FindFirstChild("Emergency")
                if emergency then
                    local room6 = emergency:FindFirstChild("Room6")
                    if room6 then
                        for _, child in ipairs(room6:GetDescendants()) do
                            if child:IsA("ProximityPrompt") and child.Enabled then
                                Interagir(child)
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
        if Config.Room7 then
            local rooms = Workspace:FindFirstChild("Rooms")
            if rooms then
                local emergency = rooms:FindFirstChild("Emergency")
                if emergency then
                    local room7 = emergency:FindFirstChild("Room7")
                    if room7 then
                        for _, child in ipairs(room7:GetDescendants()) do
                            if child:IsA("ProximityPrompt") and child.Enabled then
                                Interagir(child)
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

task.spawn(function()
    while wait(1) do
        if Config.Secretaria then
            local misc = Workspace:FindFirstChild("Misc")
            local checkIn = misc and misc:FindFirstChild("CheckIn")
            if checkIn then
                -- Varre TUDO dentro de CheckIn, incluindo objetos soltos (ex: Formularios de Selo)
                -- que não ficam necessariamente dentro de Camera/Computer/etc
                for _, obj in ipairs(checkIn:GetDescendants()) do
                    if obj:IsA("ProximityPrompt") and obj.Enabled then
                        Interagir(obj)
                        task.wait(0.4)
                    end
                end

                -- Clicker do teclado do Computer (não é ProximityPrompt, precisa disparo separado)
                local computer = checkIn:FindFirstChild("Computer")
                if computer then
                    local keyboard = computer:FindFirstChild("Keyboard")
                    local realKeyboard = keyboard and keyboard:FindFirstChild("Keyboard")
                    local clicker = realKeyboard and realKeyboard:FindFirstChild("Clicker")
                    if clicker and typeof(fireclickdetector) == "function" then
                        Teleportar(realKeyboard.Position + Vector3.new(0, 1, 2))
                        task.wait(0.15)
                        pcall(function() fireclickdetector(clicker) end)
                        task.wait(0.4)
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

Tab1:Paragraph({ Title = "Hospital - Funcoes de Atendimento" })

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

Tab2:Paragraph({ Title = "Funcoes Automaticas" })

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

Tab3:Paragraph({ Title = "Recursos Visuais" })

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

Tab4:Paragraph({ Title = "Controles do Personagem" })

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

Tab5:Paragraph({ Title = "Opcoes de Servidor" })

Tab5:Button({
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

Tab5:Paragraph({
    Title = "Info do Executor",
    Desc = "Executor: " .. execName .. "\nVersao: v6.2\nby Silverfox Scripts",
})

-- TAB 6: RESET
local Tab6 = Window:Tab({Title = "Reset", Icon = "settings"})

Tab6:Paragraph({ Title = "Resetar Configuracoes" })

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
        if hum then 
            hum.WalkSpeed = 16
            hum.JumpPower = 50 
        end
    end,
})

-- ==========================================
-- INIT
-- ==========================================

print("Silverfox Scripts | Hospital v6.2 CORRIGIDO")

WindUI:Notify({
    Title = "Silverfox Scripts",
    Content = "Script carregado!\nVersao: v6.2",
    Duration = 5,
    Icon = "check-circle",
})
