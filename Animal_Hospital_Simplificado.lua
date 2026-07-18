-- =====================================================================
-- SILVERFOX SCRIPTS | HOSPITAL DE ANIMAIS
-- VERSÃO SIMPLIFICADA - UMA FUNÇÃO PRA TUDO
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
    Size = UDim2.fromOffset(600, 500),
})

Window:Tag({
    Title = "v4.0 UNIFICADO",
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
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ==========================================
-- CONFIGURAÇÃO CENTRALIZADA
-- ==========================================

_G.HospitalConfig = _G.HospitalConfig or {
    -- FILTROS DE ATIVAÇÃO (o que quer atender)
    AtenderSecretaria = true,      -- Check-in (Camera, Badge, PC, Printer)
    AtenderRooms = true,           -- Rooms 1-5 (coletar itens, tratar)
    AtenderRoom6 = true,           -- Room 6 (X-Ray, cores)
    AtenderRoom7 = true,           -- Room 7 (máquina, monitor)
    AtenderRoom8 = true,           -- Room 8 (cirurgia - PRIORIDADE)

    -- UTILIDADES
    InstantAction = false,
    NoClip = false,
    WalkSpeed = 16,
    Fly = false,
    SanityLock = false,
}

local Config = _G.HospitalConfig

-- ==========================================
-- CONTROLE DE THREAD
-- ==========================================

local AutoAtendimentoAtivo = false
local ThreadPausada = false

-- Prioridade: Room 8 sempre passa na frente
local Room8EmAndamento = false

local function YieldSeRoom8()
    while Room8EmAndamento do
        task.wait(0.1)
    end
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
    local ok = pcall(function()
        root.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
    end)
    if ok then
        RunService.Heartbeat:Wait()
        root.Velocity = Vector3.new(0, 0, 0)
    end
    return ok
end

local function OlharPara(targetPos)
    local root = GetRoot()
    if root and targetPos then
        pcall(function()
            root.CFrame = CFrame.lookAt(root.Position, targetPos)
        end)
    end
end

-- ==========================================
-- INTERAGIR COM PROMPT (simplificado)
-- ==========================================

local function Interagir(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then
        return false
    end

    -- Teleportar e olhar
    local parent = prompt.Parent
    if parent and parent:IsA("BasePart") then
        Teleportar(parent.Position)
        OlharPara(parent.Position)
        task.wait(0.2)
    elseif parent and parent:FindFirstChildOfClass("BasePart") then
        local part = parent:FindFirstChildOfClass("BasePart")
        Teleportar(part.Position)
        OlharPara(part.Position)
        task.wait(0.2)
    end

    -- Instant action
    if Config.InstantAction then
        pcall(function() prompt.HoldDuration = 0 end)
    end

    -- Tentar fire
    local sucesso = false

    -- Método 1: fireproximityprompt
    if typeof(fireproximityprompt) == "function" then
        pcall(function()
            fireproximityprompt(prompt)
            sucesso = true
        end)
    end

    -- Método 2: input hold
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

-- ==========================================
-- CLICK BUTTON (simplificado)
-- ==========================================

local function ClicarBotao(parte)
    if not parte then return false end

    -- Procura ClickDetector
    local clicker = parte:FindFirstChildOfClass("ClickDetector")
    if clicker then
        local partPos = parte:IsA("BasePart") and parte.Position or parte:FindFirstChildOfClass("BasePart") and parte:FindFirstChildOfClass("BasePart").Position
        if partPos then
            Teleportar(partPos)
            OlharPara(partPos)
            task.wait(0.2)
        end

        if typeof(fireclickdetector) == "function" then
            return pcall(function() fireclickdetector(clicker) end)
        end
    end

    -- Procura ProximityPrompt
    local prompt = parte:FindFirstChildOfClass("ProximityPrompt")
    if prompt and prompt.Enabled then
        return Interagir(prompt)
    end

    -- Procura nos descendentes
    for _, child in ipairs(parte:GetDescendants()) do
        if child:IsA("ProximityPrompt") and child.Enabled then
            return Interagir(child)
        end
    end

    return false
end

-- ==========================================
-- BUSCAR PROMPT POR TEXTO
-- ==========================================

local function BuscarPrompt(texto, onde)
    if not texto or texto == "" then return nil end
    onde = onde or Workspace

    local textoLower = string.lower(texto)
    for _, obj in ipairs(onde:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled and obj.ActionText then
            if string.find(string.lower(obj.ActionText), textoLower) or string.find(textoLower, string.lower(obj.ActionText)) then
                return obj
            end
        end
    end
    return nil
end

-- ==========================================
-- TEM ITEM?
-- ==========================================

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

-- ==========================================
-- EQUIPAR ITEM
-- ==========================================

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
-- 1. ATENDER SECRETARIA (Check-in)
-- ==========================================

local function AtenderSecretaria()
    if not Config.AtenderSecretaria then return false end

    local misc = Workspace:FindFirstChild("Misc")
    if not misc then return false end

    local checkIn = misc:FindFirstChild("CheckIn")
    if not checkIn then return false end

    local fezAlgo = false

    -- 1. Camera/Foto
    local camera = checkIn:FindFirstChild("Camera")
    if camera then
        Teleportar(camera.Position + Vector3.new(0, 1, 2))
        task.wait(0.3)
        local prompt = BuscarPrompt("take", camera) or BuscarPrompt("photo", camera) or BuscarPrompt("stamp", camera)
        if prompt and Interagir(prompt) then
            task.wait(0.5)
            fezAlgo = true
        end
    end

    -- 2. Visitor Badge
    local visitorBadge = checkIn:FindFirstChild("VisitorBadgeBase")
    if visitorBadge then
        Teleportar(visitorBadge.Position + Vector3.new(0, 1, 2))
        task.wait(0.3)
        local prompt = BuscarPrompt("take", visitorBadge) or BuscarPrompt("visitor", visitorBadge)
        if prompt and Interagir(prompt) then
            task.wait(0.3)
            fezAlgo = true
        end
    end

    -- 3. Patient Badge
    local patientBadge = checkIn:FindFirstChild("PatientBadgeBase")
    if patientBadge then
        Teleportar(patientBadge.Position + Vector3.new(0, 1, 2))
        task.wait(0.3)
        local prompt = BuscarPrompt("take", patientBadge) or BuscarPrompt("patient", patientBadge)
        if prompt and Interagir(prompt) then
            task.wait(0.3)
            fezAlgo = true
        end
    end

    -- 4. COMPUTADOR - USA CLICKDETECTOR (mais confiável!)
    local computer = checkIn:FindFirstChild("Computer")
    if computer then
        -- Procura Keyboard com ClickDetector
        local keyboard = computer:FindFirstChild("Keyboard")
        if keyboard then
            local clicker = keyboard:FindFirstChild("ClickDetector")
            if clicker then
                Teleportar(keyboard.Position + Vector3.new(0, 1, 2))
                task.wait(0.3)
                if typeof(fireclickdetector) == "function" then
                    pcall(function() fireclickdetector(clicker) end)
                    task.wait(0.5)
                    fezAlgo = true
                end
            end
        end

        -- Fallback: ProximityPrompt direto
        local prompt = computer:FindFirstChildOfClass("ProximityPrompt")
        if not prompt then
            for _, child in ipairs(computer:GetDescendants()) do
                if child:IsA("ProximityPrompt") and child.Enabled then
                    prompt = child
                    break
                end
            end
        end
        if prompt and prompt.Enabled then
            Teleportar(prompt.Parent.Position + Vector3.new(0, 1, 2))
            task.wait(0.3)
            if Interagir(prompt) then
                task.wait(0.5)
                fezAlgo = true
            end
        end
    end

    -- 5. Printer
    local printer = checkIn:FindFirstChild("Printer")
    if printer then
        Teleportar(printer.Position + Vector3.new(0, 1, 2))
        task.wait(0.3)
        local prompt = BuscarPrompt("print", printer) or BuscarPrompt("badge", printer)
        if prompt and Interagir(prompt) then
            task.wait(0.5)
            fezAlgo = true
        end
    end

    -- 6. NPCs de finalização
    local npcs = Workspace:FindFirstChild("NPCs")
    if npcs then
        for _, npc in ipairs(npcs:GetChildren()) do
            if npc:FindFirstChildOfClass("Humanoid") then
                Teleportar(npc.Position + Vector3.new(0, 1, 2))
                task.wait(0.2)
                for _, child in ipairs(npc:GetChildren()) do
                    if child:IsA("ProximityPrompt") and child.Enabled then
                        if Interagir(child) then
                            task.wait(0.3)
                            fezAlgo = true
                        end
                        break
                    end
                end
                break
            end
        end
    end

    return fezAlgo
end

-- ==========================================
-- 2. ATENDER ROOMS 1-5 (Medical)
-- ==========================================

local function AtenderRoomMedica(num)
    if not Config.AtenderRooms then return false end
    if not num then return false end

    local rooms = Workspace:FindFirstChild("Rooms")
    if not rooms then return false end
    local medical = rooms:FindFirstChild("Medical")
    if not medical then return false end

    local room = medical:FindFirstChild("Room" .. num)
    if not room then return false end

    local fezAlgo = false

    -- Procura InBed
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
        task.wait(0.2)

        -- Interage com prompts do InBed
        for _, child in ipairs(inBed:GetChildren()) do
            if child:IsA("ProximityPrompt") and child.Enabled then
                if Interagir(child) then
                    task.wait(0.3)
                    fezAlgo = true
                end
            end
        end

        -- Pega itens necessários da inv
        local mg = room:FindFirstChild("Minigame")
        if mg then
            local tv = mg:FindFirstChild("TV")
            if tv then
                local screen = tv:FindFirstChild("Screen")
                if screen then
                    local ui = screen:FindFirstChild("UI")
                    if ui then
                        local report = ui:FindFirstChild("Report")
                        if report then
                            local inv = report:FindFirstChild("inv")
                            if inv then
                                for _, item in ipairs(inv:GetChildren()) do
                                    if item:IsA("Frame") and item.Name and item.Name ~= "" then
                                        local check = item:FindFirstChild("check")
                                        if not (check and check:IsA("ImageLabel") and check.Visible) then
                                            -- Vai pegar o item
                                            local nomeItem = item.Name
                                            local promptItem = BuscarPrompt(nomeItem)
                                            if promptItem then
                                                Teleportar(promptItem.Parent.Position + Vector3.new(0, 2, 0))
                                                task.wait(0.15)
                                                if Interagir(promptItem) then
                                                    task.wait(0.15)
                                                    if not TemItem(nomeItem) then
                                                        EquiparItem(nomeItem)
                                                        task.wait(0.1)
                                                    end
                                                    Teleportar(inBed.Position + Vector3.new(0, 2, 0))
                                                    task.wait(0.1)
                                                    fezAlgo = true
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
        end
    end

    return fezAlgo
end

-- ==========================================
-- 3. ATENDER ROOM 6 (Emergency - X-Ray)
-- ==========================================

local function AtenderRoom6()
    if not Config.AtenderRoom6 then return false end

    YieldSeRoom8()

    local rooms = Workspace:FindFirstChild("Rooms")
    if not rooms then return false end
    local emergency = rooms:FindFirstChild("Emergency")
    if not emergency then return false end

    local room6 = emergency:FindFirstChild("Room6")
    if not room6 then return false end

    local mg = room6:FindFirstChild("Minigame")
    if not mg then return false end

    local fezAlgo = false

    -- X-Ray Monitor
    local xrayMonitor = mg:FindFirstChild("xrayMonitor")
    if xrayMonitor then
        local prompt = BuscarPrompt("xray", xrayMonitor)
        if prompt then
            if Interagir(prompt) then
                task.wait(1.5)
                fezAlgo = true
            end
        end
    end

    -- Cores (botões)
    YieldSeRoom8()
    local colors = mg:FindFirstChild("Colors")
    if colors then
        for _, modelo in ipairs(colors:GetChildren()) do
            if modelo:IsA("Model") then
                local btn = modelo:FindFirstChild("Button")
                if btn and btn:IsA("BasePart") then
                    YieldSeRoom8()
                    ClicarBotao(btn)
                    task.wait(0.3)
                    fezAlgo = true
                end
            end
        end
    end

    -- Processar resultado
    YieldSeRoom8()
    local xresult = mg:FindFirstChild("xresult")
    if xresult then
        local prompt = BuscarPrompt("process", xresult) or BuscarPrompt("result", xresult)
        if prompt and Interagir(prompt) then
            task.wait(0.5)
            fezAlgo = true
        end
    end

    -- Coletar prêmio
    YieldSeRoom8()
    local printer = mg:FindFirstChild("Printer")
    if printer then
        local prompt = BuscarPrompt("collect", printer)
        if prompt and Interagir(prompt) then
            task.wait(0.5)
            fezAlgo = true
        end
    end

    return fezAlgo
end

-- ==========================================
-- 4. ATENDER ROOM 7 (Emergency)
-- ==========================================

local function AtenderRoom7()
    if not Config.AtenderRoom7 then return false end

    YieldSeRoom8()

    local rooms = Workspace:FindFirstChild("Rooms")
    if not rooms then return false end
    local emergency = rooms:FindFirstChild("Emergency")
    if not emergency then return false end

    local room7 = emergency:FindFirstChild("Room7")
    if not room7 then return false end

    local mg = room7:FindFirstChild("Minigame")
    if not mg then return false end

    local fezAlgo = false

    -- InBed
    local bed = mg:FindFirstChild("Bed")
    if bed then
        local inBed = bed:FindFirstChild("InBed")
        if inBed then
            Teleportar(inBed.Position + Vector3.new(0, 1, 1))
            task.wait(0.2)
            for _, child in ipairs(inBed:GetChildren()) do
                if child:IsA("ProximityPrompt") and child.Enabled then
                    if Interagir(child) then
                        task.wait(0.3)
                        fezAlgo = true
                    end
                end
            end
        end
    end

    -- Máquina
    YieldSeRoom8()
    local machine = mg:FindFirstChild("Machine")
    if machine then
        local prompt = BuscarPrompt("use", machine) or BuscarPrompt("machine", machine)
        if prompt and Interagir(prompt) then
            task.wait(0.3)
            fezAlgo = true
        end
    end

    -- Heart Monitor
    YieldSeRoom8()
    local heartMonitor = mg:FindFirstChild("HeartMonitor")
    if heartMonitor then
        local prompt = BuscarPrompt("heart", heartMonitor) or BuscarPrompt("monitor", heartMonitor)
        if prompt and Interagir(prompt) then
            task.wait(0.3)
            fezAlgo = true
        end
    end

    -- Stand IV
    YieldSeRoom8()
    local standIV = mg:FindFirstChild("StandIV")
    if standIV then
        local prompt = BuscarPrompt("iv", standIV) or BuscarPrompt("stand", standIV)
        if prompt and Interagir(prompt) then
            task.wait(0.3)
            fezAlgo = true
        end
    end

    -- Curtains (cortinas)
    YieldSeRoom8()
    local curtains = room7:FindFirstChild("Curtains")
    if curtains then
        local open = curtains:FindFirstChild("Open")
        if open then
            ClicarBotao(open)
            task.wait(0.3)
        end
    end

    return fezAlgo
end

-- ==========================================
-- 5. ATENDER ROOM 8 (Emergency - CIRURGIA)
-- ==========================================

local function AtenderRoom8()
    if not Config.AtenderRoom8 then return false end

    local rooms = Workspace:FindFirstChild("Rooms")
    if not rooms then return false end
    local emergency = rooms:FindFirstChild("Emergency")
    if not emergency then return false end

    local room8 = emergency:FindFirstChild("Room8")
    if not room8 then return false end

    local mg = room8:FindFirstChild("Minigame")
    if not mg then return false end

    local inBed = nil
    local bed = mg:FindFirstChild("Bed")
    if bed then inBed = bed:FindFirstChild("InBed") end
    if not inBed then inBed = mg:FindFirstChild("InBed") end
    if not inBed then inBed = room8:FindFirstChild("InBed") end

    if not inBed then return false end

    -- Verifica se tem prompts pendentes
    local temPrompt = false
    for _, child in ipairs(inBed:GetChildren()) do
        if child:IsA("ProximityPrompt") and child.Enabled then
            temPrompt = true
            break
        end
    end

    if not temPrompt then return false end

    -- ATIVA PRIORIDADE - outras rooms pausam
    Room8EmAndamento = true

    Teleportar(inBed.Position + Vector3.new(0, 1, 1))
    task.wait(0.2)

    -- Interage com todos os prompts
    for _, child in ipairs(inBed:GetChildren()) do
        if child:IsA("ProximityPrompt") and child.Enabled then
            Interagir(child)
            task.wait(0.5)
        end
    end

    -- Medicine (instrumentos cirúrgicos)
    local medicine = mg:FindFirstChild("Medicine")
    if medicine then
        for _, modelo in ipairs(medicine:GetChildren()) do
            if modelo:IsA("Model") then
                local parte = modelo:FindFirstChildOfClass("BasePart")
                if parte then
                    local prompt = parte:FindFirstChildOfClass("ProximityPrompt")
                    if prompt and prompt.Enabled then
                        Interagir(prompt)
                        task.wait(0.3)
                    end
                end
            end
        end
    end

    -- LIBERA PRIORIDADE - outras rooms voltam
    Room8EmAndamento = false

    return true
end

-- ==========================================
-- FUNÇÃO PRINCIPAL ÚNICA (atende tudo)
-- ==========================================

local function LoopPrincipal()
    if AutoAtendimentoAtivo then return end
    AutoAtendimentoAtivo = true

    while AutoAtendimentoAtivo do
        local fezAlgo = false

        -- Room 8 tem PRIORIDADE (cirurgia)
        if AtenderRoom8() then
            fezAlgo = true
        end

        -- Secretaria
        if not Room8EmAndamento then
            if AtenderSecretaria() then
                fezAlgo = true
            end
        end

        -- Rooms 1-5
        if not Room8EmAndamento then
            for i = 1, 5 do
                if not AutoAtendimentoAtivo then break end
                YieldSeRoom8()
                if AtenderRoomMedica(i) then
                    fezAlgo = true
                end
            end
        end

        -- Room 6
        if not Room8EmAndamento then
            YieldSeRoom8()
            if AtenderRoom6() then
                fezAlgo = true
            end
        end

        -- Room 7
        if not Room8EmAndamento then
            YieldSeRoom8()
            if AtenderRoom7() then
                fezAlgo = true
            end
        end

        -- Espera menos se fez algo, mais se não fez
        if fezAlgo then
            task.wait(0.3)
        else
            task.wait(1)
        end
    end

    Room8EmAndamento = false
end

-- ==========================================
-- UTILIDADES
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
            bv.Velocity = dir * 50
            RunService.RenderStepped:Wait()
        end

        if bv and bv.Parent then bv:Destroy() end
    else
        local bv = root:FindFirstChildOfClass("BodyVelocity")
        if bv then bv:Destroy() end
    end
end

-- NoClip loop
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

-- WalkSpeed loop
task.spawn(function()
    while true do
        local hum = GetHum()
        if hum then hum.WalkSpeed = Config.WalkSpeed end
        task.wait(0.1)
    end
end)

-- Sanity loop
task.spawn(function()
    while true do
        if Config.SanityLock then
            local misc = Workspace:FindFirstChild("Misc")
            if misc then
                local sanity = misc:FindFirstChild("sanity")
                if sanity and (sanity:IsA("IntValue") or sanity:IsA("NumberValue")) then
                    pcall(function() sanity.Value = 100 end)
                end
            end
        end
        task.wait(0.1)
    end
end)

-- ==========================================
-- INTERFACE
-- ==========================================

local Tab = Window:Tab({
    Title = "Auto Atendimento",
    Icon = "home"
})

Tab:Label("FUNÇÃO ÚNICA: Atende secretaria + pacientes automaticamente")
Tab:Label("Room 8 (cirurgia) SEMPRE tem prioridade sobre as outras")

-- Toggle principal
local TogglePrincipal = Tab:Toggle({
    Title = "AUTO ATENDIMENTO (ON/OFF)",
    Desc = "Liga/desliga todo o sistema de atendimento",
    Value = false,
    Callback = function(state)
        if state then
            task.spawn(LoopPrincipal)
        else
            AutoAtendimentoAtivo = false
        end
    end,
})

Tab:Label("")

Tab:Label("FILTROS - Escolha o que atender:")

Tab:Toggle({
    Title = "Atender Secretaria (Check-in)",
    Desc = "Camera, Badge, PC, Printer, NPCs",
    Value = true,
    Callback = function(state)
        Config.AtenderSecretaria = state
    end,
})

Tab:Toggle({
    Title = "Atender Rooms 1-5 (Medical)",
    Desc = "Coleta itens e trata pacientes",
    Value = true,
    Callback = function(state)
        Config.AtenderRooms = state
    end,
})

Tab:Toggle({
    Title = "Atender Room 6 (X-Ray)",
    Desc = "X-Ray, botões de cores, processar",
    Value = true,
    Callback = function(state)
        Config.AtenderRoom6 = state
    end,
})

Tab:Toggle({
    Title = "Atender Room 7",
    Desc = "Máquina, monitor, IV, cortinas",
    Value = true,
    Callback = function(state)
        Config.AtenderRoom7 = state
    end,
})

Tab:Toggle({
    Title = "Atender Room 8 (Cirurgia)",
    Desc = "PRIORIDADE MÁXIMA - pausa outras salas",
    Value = true,
    Callback = function(state)
        Config.AtenderRoom8 = state
    end,
})

Tab:Label("")

Tab:Toggle({
    Title = "Instant Action",
    Desc = "Remove delay dos prompts",
    Value = false,
    Callback = function(state)
        Config.InstantAction = state
    end,
})

-- Tab Utilitários
local Tab2 = Window:Tab({
    Title = "Utilitários",
    Icon = "user"
})

Tab2:Toggle({
    Title = "NoClip",
    Desc = "Atravessa paredes",
    Value = false,
    Callback = function(state)
        Config.NoClip = state
    end,
})

Tab2:Slider({
    Title = "WalkSpeed",
    Desc = "Velocidade do personagem",
    Step = 1,
    Value = {Min = 16, Max = 200, Default = 16},
    Callback = function(val)
        Config.WalkSpeed = val
    end,
})

Tab2:Toggle({
    Title = "Fly",
    Desc = "WASD + Espaço/Ctrl",
    Value = false,
    Callback = function(state)
        ToggleFly(state)
    end,
})

Tab2:Toggle({
    Title = "Sanidade Infinita",
    Desc = "Mantém sanidade em 100",
    Value = false,
    Callback = function(state)
        Config.SanityLock = state
    end,
})

Tab2:Button({
    Title = "Resetar Velocidade",
    Desc = "Volta pra 16",
    Callback = function()
        Config.WalkSpeed = 16
        local hum = GetHum()
        if hum then hum.WalkSpeed = 16 end
    end,
})

Tab2:Button({
    Title = "DESATIVAR TUDO",
    Desc = "Desliga tudo",
    Callback = function()
        AutoAtendimentoAtivo = false
        Config.AtenderSecretaria = true
        Config.AtenderRooms = true
        Config.AtenderRoom6 = true
        Config.AtenderRoom7 = true
        Config.AtenderRoom8 = true
        Config.NoClip = false
        Config.WalkSpeed = 16
        Config.SanityLock = false
        ToggleFly(false)
        local hum = GetHum()
        if hum then hum.WalkSpeed = 16 end
    end,
})

-- ==========================================
-- INICIALIZAÇÃO
-- ==========================================

print("=================================")
print("Silverfox Scripts | Hospital v4.0")
print("FUNÇÃO ÚNICA ATIVADA")
print("=================================")

WindUI:Notify({
    Title = "Silverfox Scripts",
    Content = "Script carregado!\nAuto Atendimento Unificado ✅",
    Duration = 5,
    Icon = "check-circle",
})
