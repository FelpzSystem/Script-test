-- =====================================================================
-- ANIMAL HOSPITAL HUB v3.0 (ULTRA OTIMIZADO)
-- Sanidade Infinita + Highlights + Detecção Anomalias + Close Automático
-- =====================================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = Workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")

-- ==========================================
-- CONFIGURAÇÃO GLOBAL
-- ==========================================

if not _G.HospitalConfig then
    _G.HospitalConfig = {
        InstantAction = false,
        AutoProcess = false,
        AutoHeal = false,
        AutoRoom6 = false,
        AutoRoom7 = false,
        AutoRoom8 = false,
        NoClip = false,
        AutoSecretaria = false,
        WalkSpeed = 16,
        InfiniteSanity = true,
        EnableHighlights = true,
        EnableAnomalyDetection = true,
        AutoCloseDoors = true,
    }
end

local Config = _G.HospitalConfig
local PromptConnections = {}
local OriginalCollisions = {}

-- ==========================================
-- SISTEMA DE SANIDADE INFINITA
-- ==========================================

local function InitializeSanity()
    pcall(function()
        if LocalPlayer:GetAttribute("Sanity") then
            LocalPlayer:SetAttribute("Sanity", 100)
        end
    end)
end

local SanityLoop = RunService.Heartbeat:Connect(function()
    if Config.InfiniteSanity then
        pcall(function()
            if LocalPlayer:GetAttribute("Sanity") then
                LocalPlayer:SetAttribute("Sanity", 100)
            end
        end)
    end
end)

InitializeSanity()

-- ==========================================
-- SISTEMA DE HIGHLIGHTS (ESPÍRITOS)
-- ==========================================

local HighlightsEnabled = {}

local function CreateHighlight(character, color, name)
    if not character then return end
    
    local highlight = Instance.new("Highlight")
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.FillTransparency = 0.3
    highlight.OutlineTransparency = 0
    highlight.Parent = character
    
    HighlightsEnabled[character] = highlight
    return highlight
end

local function RemoveHighlight(character)
    if HighlightsEnabled[character] then
        HighlightsEnabled[character]:Destroy()
        HighlightsEnabled[character] = nil
    end
end

local function UpdateHighlights()
    if not Config.EnableHighlights then
        for _, highlight in pairs(HighlightsEnabled) do
            if highlight then highlight:Destroy() end
        end
        HighlightsEnabled = {}
        return
    end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player ~= LocalPlayer then
            local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
            
            if humanoidRootPart then
                local isAnomaly = string.find(player.Name:lower(), "anomal") or 
                                 player.Character:FindFirstChild("IsAnomaly") or
                                 (player:FindFirstChild("PlayerRole") and 
                                  player.PlayerRole.Value == "Anomaly")
                
                local isVisitor = string.find(player.Name:lower(), "visit") or
                                 (player:FindFirstChild("PlayerRole") and 
                                  player.PlayerRole.Value == "Visitor")
                
                local isPacient = string.find(player.Name:lower(), "pacient") or
                                (player:FindFirstChild("PlayerRole") and 
                                 player.PlayerRole.Value == "Patient")
                
                if isAnomaly or isVisitor then
                    if not HighlightsEnabled[player.Character] then
                        CreateHighlight(player.Character, Color3.fromRGB(255, 0, 0), "Anomaly")
                    end
                elseif isPacient then
                    if not HighlightsEnabled[player.Character] then
                        CreateHighlight(player.Character, Color3.fromRGB(0, 255, 0), "Patient")
                    end
                else
                    RemoveHighlight(player.Character)
                end
            end
        end
    end
end

local HighlightLoop = RunService.Heartbeat:Connect(function()
    pcall(UpdateHighlights)
end)

-- ==========================================
-- SISTEMA DE DETECÇÃO DE ANOMALIAS & CLOSE
-- ==========================================

local DoorsClosedByAnomalyDetection = {}

local function GetAllDoors()
    local doors = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and (obj.Name:lower():find("door") or obj.Name:lower():find("porta")) then
            local part = obj:FindFirstChildOfClass("BasePart")
            if part then table.insert(doors, obj) end
        end
    end
    return doors
end

local function CloseDoor(door)
    if not door then return end
    
    pcall(function()
        local part = door:FindFirstChildOfClass("BasePart")
        if part then
            part.CanCollide = true
            if door:FindFirstChild("BodyVelocity") then
                door.BodyVelocity:Destroy()
            end
        end
        
        local clickDetector = door:FindFirstChildOfClass("ClickDetector")
        if clickDetector then
            pcall(function() fireclickdetector(clickDetector) end)
        end
        
        DoorsClosedByAnomalyDetection[door] = true
    end)
end

local function OpenDoor(door)
    if not door then return end
    
    pcall(function()
        local part = door:FindFirstChildOfClass("BasePart")
        if part then
            part.CanCollide = false
        end
        DoorsClosedByAnomalyDetection[door] = false
    end)
end

local function DetectAnomaliesAndCloseDoors()
    if not Config.AutoCloseDoors then return end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player ~= LocalPlayer then
            local isAnomaly = string.find(player.Name:lower(), "anomal") or
                             player.Character:FindFirstChild("IsAnomaly") or
                             (player:FindFirstChild("PlayerRole") and 
                              player.PlayerRole.Value == "Anomaly")
            
            if isAnomaly then
                local doors = GetAllDoors()
                for _, door in ipairs(doors) do
                    if not DoorsClosedByAnomalyDetection[door] then
                        CloseDoor(door)
                    end
                end
                return
            end
        end
    end
    
    for door, _ in pairs(DoorsClosedByAnomalyDetection) do
        OpenDoor(door)
    end
end

local AnomalyDetectionLoop = RunService.Heartbeat:Connect(function()
    pcall(DetectAnomaliesAndCloseDoors)
end)

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
    
    return success
end

local function ClickButton(buttonPart)
    if not buttonPart then return false end
    local clickDetector = buttonPart:FindFirstChildOfClass("ClickDetector")
    if clickDetector then
        LookAtPosition(buttonPart.Position)
        local success = pcall(function() fireclickdetector(clickDetector) end)
        return success
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

-- ==========================================
-- AUTO ACTIONS (Rooms 6, 7, 8)
-- ==========================================

local function AutoRoom6Action()
    if not Config.AutoRoom6 then return end
    
    local medical = Workspace:FindFirstChild("Rooms")
    if medical then medical = medical:FindFirstChild("Medical") end
    if not medical then return end
    
    local room6 = medical:FindFirstChild("Room6")
    if not room6 then return end
    
    for _, item in ipairs(room6:GetDescendants()) do
        if item:IsA("ProximityPrompt") and item.Enabled then
            FirePromptDirect(item)
            task.wait(0.3)
        end
    end
end

local function AutoRoom7Action()
    if not Config.AutoRoom7 then return end
    
    local medical = Workspace:FindFirstChild("Rooms")
    if medical then medical = medical:FindFirstChild("Medical") end
    if not medical then return end
    
    local room7 = medical:FindFirstChild("Room7")
    if not room7 then return end
    
    local inBed = room7:FindFirstChild("InBed")
    if inBed then
        for _, prompt in ipairs(inBed:GetDescendants()) do
            if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                FirePromptDirect(prompt)
                task.wait(0.3)
            end
        end
    end
end

local function AutoRoom8Action()
    if not Config.AutoRoom8 then return end
    
    local emergency = Workspace:FindFirstChild("Rooms")
    if emergency then emergency = emergency:FindFirstChild("Emergency") end
    if not emergency then return end
    
    local room8 = emergency:FindFirstChild("Room8")
    if not room8 then return end
    
    local inBed = room8:FindFirstChild("InBed")
    if inBed then
        for _, prompt in ipairs(inBed:GetDescendants()) do
            if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                FirePromptDirect(prompt)
                task.wait(0.3)
            end
        end
    end
end

-- ==========================================
-- AUTO SECRETÁRIA (CORRIGIDO - caminhos reais do jogo)
-- Fluxo: Camera > Computer > Printer (1.5s) > Badge (Visitor/Patient) > NPC
-- ==========================================

local CHECKIN_CAMERA_WAIT   = 0.4   -- sem espera de "revelar foto" (removido por ser inutil)
local CHECKIN_COMPUTER_WAIT = 0.4
local CHECKIN_PRINTER_WAIT  = 1.5   -- conforme especificado
local CHECKIN_BADGE_WAIT    = 0.3
local CHECKIN_DELIVER_WAIT  = 0.3
local CHECKIN_STEP_TIMEOUT  = 5     -- tempo maximo esperando um prompt ficar disponivel
local CHECKIN_RETRY_INTERVAL = 0.25
local CHECKIN_CYCLE_COOLDOWN = 1.5  -- intervalo entre ciclos completos

local function GetCheckInFolder()
    local misc = Workspace:FindFirstChild("Misc")
    return misc and misc:FindFirstChild("CheckIn")
end

local function GetNPCsFolder()
    return Workspace:FindFirstChild("NPCs")
end

-- Busca o ProximityPrompt de um objeto do CheckIn (ex: Camera, Computer, Printer)
local function FindPromptIn(container, name)
    if not container then return nil end
    local host = container:FindFirstChild(name)
    if not host then return nil end
    if host:IsA("ProximityPrompt") then return host end
    local prompt = host:FindFirstChildOfClass("ProximityPrompt")
    if prompt then return prompt end
    for _, d in ipairs(host:GetDescendants()) do
        if d:IsA("ProximityPrompt") then return d end
    end
    return nil
end

-- Espera o prompt existir e estar habilitado (evita clicar em prompt "morto")
local function WaitForPrompt(getPromptFn, timeout)
    timeout = timeout or CHECKIN_STEP_TIMEOUT
    local start = os.clock()
    while os.clock() - start < timeout do
        if not Config.AutoSecretaria then return nil end
        local prompt = getPromptFn()
        if prompt and prompt.Enabled then return prompt end
        task.wait(CHECKIN_RETRY_INTERVAL)
    end
    return nil
end

local function FireCheckInStep(getPromptFn, stepName, waitAfter)
    if not Config.AutoSecretaria then return false end

    local prompt = WaitForPrompt(getPromptFn, CHECKIN_STEP_TIMEOUT)
    if not prompt then
        warn("[Secretaria] Prompt indisponivel: " .. stepName)
        return false
    end

    local ok = FirePromptDirect(prompt)
    if not ok then
        warn("[Secretaria] Falha ao acionar: " .. stepName)
        return false
    end

    if waitAfter and waitAfter > 0 then task.wait(waitAfter) end
    return true
end

-- Detecta automaticamente qual base de cracha esta ativa (Visitor ou Patient)
local function GetActiveBadgePrompt()
    local checkIn = GetCheckInFolder()
    if not checkIn then return nil end

    local visitorPrompt = FindPromptIn(checkIn, "VisitorBadgeBase")
    if visitorPrompt and visitorPrompt.Enabled then return visitorPrompt end

    local patientPrompt = FindPromptIn(checkIn, "PatientBadgeBase")
    if patientPrompt and patientPrompt.Enabled then return patientPrompt end

    return nil
end

-- FIX PRINCIPAL #1: equipar o cracha apos pegar (NPC so aceita entrega com item equipado)
local function EquipBadgeTool()
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local hum = GetHumanoid()
    if not backpack or not hum then return false end

    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and string.find(string.lower(tool.Name), "badge") then
            pcall(function() hum:EquipTool(tool) end)
            task.wait(0.2)
            return true
        end
    end
    return false
end

-- FIX PRINCIPAL #2: NPCs reais ficam em Workspace.NPCs (nomes proprios, nao "NPC" generico)
-- Apenas o NPC que esta realmente aguardando tem o prompt Enabled = true
local function GetActiveNPCPrompt()
    local npcsFolder = GetNPCsFolder()
    if not npcsFolder then return nil end

    for _, npc in ipairs(npcsFolder:GetChildren()) do
        local prompt = npc:FindFirstChild("PP")
        if not prompt then
            for _, d in ipairs(npc:GetDescendants()) do
                if d:IsA("ProximityPrompt") then
                    prompt = d
                    break
                end
            end
        end
        if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled then
            return prompt
        end
    end
    return nil
end

local function AutoSecretariaSequence()
    if not Config.AutoSecretaria then return end

    local checkIn = GetCheckInFolder()
    if not checkIn then
        warn("[Secretaria] Workspace.Misc.CheckIn nao encontrado.")
        return
    end

    -- 1) Tirar foto
    if not FireCheckInStep(function() return FindPromptIn(checkIn, "Camera") end,
        "Camera (foto)", CHECKIN_CAMERA_WAIT) then return end
    if not Config.AutoSecretaria then return end

    -- 2) Registrar no computador
    if not FireCheckInStep(function() return FindPromptIn(checkIn, "Computer") end,
        "Computer (registro)", CHECKIN_COMPUTER_WAIT) then return end
    if not Config.AutoSecretaria then return end

    -- 3) Imprimir cracha (aguarda 1.5s)
    if not FireCheckInStep(function() return FindPromptIn(checkIn, "Printer") end,
        "Printer (impressao)", CHECKIN_PRINTER_WAIT) then return end
    if not Config.AutoSecretaria then return end

    -- 4) Pegar o cracha certo (Visitor ou Patient - detectado automaticamente)
    if not FireCheckInStep(GetActiveBadgePrompt, "Badge Base (pegar cracha)", CHECKIN_BADGE_WAIT) then return end
    if not Config.AutoSecretaria then return end

    -- Equipa o cracha antes de tentar entregar
    EquipBadgeTool()

    -- 5) Entregar ao NPC correto (paciente/visitante ativo, detectado automaticamente)
    if not FireCheckInStep(GetActiveNPCPrompt, "NPC (entrega)", CHECKIN_DELIVER_WAIT) then
        warn("[Secretaria] Entrega falhou: nenhum NPC ativo encontrado em Workspace.NPCs")
        return
    end

    print("[Secretaria] Ciclo completo: cracha entregue com sucesso!")
end

-- ==========================================
-- LOOP DE AUTO ACTIONS (Rooms - alta frequencia, ok rodar no Heartbeat)
-- ==========================================

local ActionLoop = RunService.Heartbeat:Connect(function()
    pcall(function()
        if Config.AutoRoom6 then AutoRoom6Action() end
        if Config.AutoRoom7 then AutoRoom7Action() end
        if Config.AutoRoom8 then AutoRoom8Action() end
    end)
end)

-- ==========================================
-- LOOP DA SECRETÁRIA (isolado do Heartbeat de propósito)
-- FIX CRITICO: antes rodava a cada frame (60x/s) e as chamadas se
-- sobrepunham no meio da propria sequencia, quebrando a entrega final.
-- Agora roda em thread propria, um ciclo por vez, com cooldown.
-- ==========================================

task.spawn(function()
    while true do
        if Config.AutoSecretaria then
            local ok, err = pcall(AutoSecretariaSequence)
            if not ok then warn("[Secretaria] Erro no ciclo: " .. tostring(err)) end
            task.wait(CHECKIN_CYCLE_COOLDOWN)
        else
            task.wait(0.5)
        end
    end
end)

-- ==========================================
-- NOCLIP
-- ==========================================

local function ToggleNoClip(enabled)
    local character = GetCharacter()
    if not character then return end
    
    for _, part in ipairs(character:FindFirstChild("Humanoid") and character:GetDescendants() or {}) do
        if part:IsA("BasePart") then
            if enabled then
                if not OriginalCollisions[part] then
                    OriginalCollisions[part] = part.CanCollide
                end
                part.CanCollide = false
            else
                if OriginalCollisions[part] ~= nil then
                    part.CanCollide = OriginalCollisions[part]
                end
            end
        end
    end
end

-- ==========================================
-- INTERFACE WINDUI
-- ==========================================

local WindUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"
))()

local Window = WindUI:CreateWindow({
    Title = "ANIMAL HOSPITAL HUB",
    Icon = "home",
    Author = "v3.0",
    Theme = "Dark",
})

-- ==========================================
-- TAB: PRINCIPAL
-- ==========================================

local MainTab = Window:Tab({ Title = "Principal", Icon = "home" })

MainTab:Toggle({
    Title = "Interacao Instantanea",
    Desc = "Interagir sem esperar",
    Value = Config.InstantAction,
    Callback = function(state)
        Config.InstantAction = state
    end,
})

MainTab:Toggle({
    Title = "Sanidade Infinita",
    Desc = "Manter sanidade sempre em 100",
    Value = Config.InfiniteSanity,
    Callback = function(state)
        Config.InfiniteSanity = state
    end,
})

MainTab:Toggle({
    Title = "Highlights de Personagens",
    Desc = "Vermelho: Anomalia | Verde: Paciente",
    Value = Config.EnableHighlights,
    Callback = function(state)
        Config.EnableHighlights = state
        if not state then
            for _, highlight in pairs(HighlightsEnabled) do
                if highlight then highlight:Destroy() end
            end
            HighlightsEnabled = {}
        end
    end,
})

MainTab:Toggle({
    Title = "Auto Deteccao Anomalias",
    Desc = "Detecta anomalias automaticamente",
    Value = Config.EnableAnomalyDetection,
    Callback = function(state)
        Config.EnableAnomalyDetection = state
    end,
})

MainTab:Toggle({
    Title = "Auto Fechar Portas",
    Desc = "Fecha portas ao detectar anomalia",
    Value = Config.AutoCloseDoors,
    Callback = function(state)
        Config.AutoCloseDoors = state
    end,
})

-- ==========================================
-- TAB: QUARTOS
-- ==========================================

local RoomsTab = Window:Tab({ Title = "Quartos", Icon = "door-open" })

RoomsTab:Toggle({
    Title = "Auto Quarto 6 (X-Ray)",
    Desc = "Automacao completa",
    Value = Config.AutoRoom6,
    Callback = function(state)
        Config.AutoRoom6 = state
    end,
})

RoomsTab:Toggle({
    Title = "Auto Quarto 7",
    Desc = "Pacientes na cama",
    Value = Config.AutoRoom7,
    Callback = function(state)
        Config.AutoRoom7 = state
    end,
})

RoomsTab:Toggle({
    Title = "Auto Quarto 8",
    Desc = "Emergencia",
    Value = Config.AutoRoom8,
    Callback = function(state)
        Config.AutoRoom8 = state
    end,
})

-- ==========================================
-- TAB: SECRETÁRIA
-- ==========================================

local SecretariaTab = Window:Tab({ Title = "Secretaria", Icon = "clipboard-list" })

SecretariaTab:Paragraph({
    Title = "CHECK-IN AUTOMATICO",
    Desc = "Carimbao > Foto > Registro > Impressao > Cracha",
})

SecretariaTab:Toggle({
    Title = "Auto Secretaria",
    Desc = "Automatiza todo o processo de check-in",
    Value = Config.AutoSecretaria,
    Callback = function(state)
        Config.AutoSecretaria = state
    end,
})

-- ==========================================
-- TAB: JOGADOR
-- ==========================================

local PlayerTab = Window:Tab({ Title = "Jogador", Icon = "user" })

PlayerTab:Input({
    Title = "Velocidade",
    Placeholder = "16-200",
    Value = tostring(Config.WalkSpeed),
    Callback = function(value)
        local speed = tonumber(value)
        if speed and speed > 0 and speed < 200 then
            Config.WalkSpeed = speed
            local hum = GetHumanoid()
            if hum then hum.WalkSpeed = speed end
        end
    end,
})

PlayerTab:Toggle({
    Title = "NoClip",
    Desc = "Atravessar paredes",
    Value = Config.NoClip,
    Callback = function(state)
        Config.NoClip = state
        ToggleNoClip(state)
    end,
})

-- ==========================================
-- TAB: SOBRE
-- ==========================================

local AboutTab = Window:Tab({ Title = "Sobre", Icon = "info" })

AboutTab:Paragraph({
    Title = "ANIMAL HOSPITAL HUB v3.0",
    Desc = "Hub completo com sanidade infinita, highlights, deteccao de anomalias e fechar de portas automatico.",
})

AboutTab:Paragraph({
    Title = "RECURSOS v3.0",
    Desc = "• Sanidade Infinita (100%)\n• Highlights Automaticos\n• Deteccao de Anomalias\n• Auto Close de Portas\n• Auto Secretaria\n• Auto Quartos 6, 7, 8",
})

AboutTab:Button({
    Title = "Desativar Tudo",
    Callback = function()
        Config.InstantAction = false
        Config.AutoRoom6 = false
        Config.AutoRoom7 = false
        Config.AutoRoom8 = false
        Config.AutoSecretaria = false
        Config.NoClip = false
        Config.EnableHighlights = false
        Config.AutoCloseDoors = false
        ToggleNoClip(false)
        Config.WalkSpeed = 16
    end,
})

print("Hospital Hub v3.0 carregado com sucesso!")
print("Sanidade: Infinita")
print("Highlights: Ativados")
print("Deteccao de Anomalias: Ativa")
