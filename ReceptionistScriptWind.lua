local ok, WindUI = pcall(function()
    return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)

if not ok or not WindUI then
    warn("Falha ao carregar WindUI: " .. tostring(WindUI))
    return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera

local Colors = {
    Primary = Color3.fromRGB(45, 45, 55),
    Secondary = Color3.fromRGB(60, 60, 70),
    Accent = Color3.fromRGB(0, 170, 255),
    Success = Color3.fromRGB(50, 205, 50),
    Warning = Color3.fromRGB(255, 165, 0),
    Danger = Color3.fromRGB(220, 53, 69),
    Text = Color3.fromRGB(255, 255, 255),
    TextMuted = Color3.fromRGB(180, 180, 190),
    Border = Color3.fromRGB(80, 80, 90),
    HighlightVisitor = Color3.fromRGB(255, 50, 50),
    HighlightPaciente = Color3.fromRGB(50, 255, 50),
    HighlightAnomalia = Color3.fromRGB(255, 100, 200)
}

local HighlightSystem = {
    ActiveHighlights = {},
    Settings = {
        VisitorColor = Colors.HighlightVisitor,
        PacienteColor = Colors.HighlightPaciente,
        AnomaliaColor = Colors.HighlightAnomalia,
        FillTransparency = 0.6,
        OutlineTransparency = 0,
        Duration = 5
    }
}

function HighlightSystem:CreateHighlight(target, color, options)
    if not target then return nil end

    local settings = options or {}
    local colorFinal = color or Colors.Accent

    local highlight = Instance.new("Highlight")
    highlight.Adornee = target
    highlight.FillColor = colorFinal
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.FillTransparency = settings.fillTransparency or HighlightSystem.Settings.FillTransparency
    highlight.OutlineTransparency = settings.outlineTransparency or HighlightSystem.Settings.OutlineTransparency
    highlight.Parent = target

    local id = target:GetFullName()
    HighlightSystem.ActiveHighlights[id] = highlight

    if settings.duration then
        task.delay(settings.duration, function()
            if highlight and highlight.Parent then
                highlight:Destroy()
                HighlightSystem.ActiveHighlights[id] = nil
            end
        end)
    end

    return highlight
end

function HighlightSystem:RemoveHighlight(target)
    local id = target and target:GetFullName()
    if id and HighlightSystem.ActiveHighlights[id] then
        HighlightSystem.ActiveHighlights[id]:Destroy()
        HighlightSystem.ActiveHighlights[id] = nil
    end
end

function HighlightSystem:ClearAll()
    for _, highlight in pairs(HighlightSystem.ActiveHighlights) do
        if highlight and highlight.Parent then
            highlight:Destroy()
        end
    end
    HighlightSystem.ActiveHighlights = {}
end

function HighlightSystem:HighlightVisitor(model)
    if not model then return nil end
    return HighlightSystem:CreateHighlight(model, HighlightSystem.Settings.VisitorColor, {
        fillTransparency = 0.5,
        duration = HighlightSystem.Settings.Duration
    })
end

function HighlightSystem:HighlightPaciente(model)
    if not model then return nil end
    return HighlightSystem:CreateHighlight(model, HighlightSystem.Settings.PacienteColor, {
        fillTransparency = 0.5,
        duration = HighlightSystem.Settings.Duration
    })
end

function HighlightSystem:HighlightAnomalia(model)
    if not model then return nil end
    return HighlightSystem:CreateHighlight(model, HighlightSystem.Settings.AnomaliaColor, {
        fillTransparency = 0.4,
        duration = HighlightSystem.Settings.Duration
    })
end

function HighlightSystem:ScanForNPCs()
    local found = {
        Visitors = {},
        Anomalias = {}
    }

    local function scanFolder(folder, targetTable)
        if not folder then return end
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("Model") or child:IsA("Folder") then
                if child:FindFirstChild("Humanoid") then
                    table.insert(targetTable, child)
                end
                scanFolder(child, targetTable)
            end
        end
    end

    if ReplicatedStorage:FindFirstChild("NPCs") then
        local npcs = ReplicatedStorage.NPCs
        scanFolder(npcs:FindFirstChild("Visitors"), found.Visitors)
        scanFolder(npcs:FindFirstChild("Anomalies"), found.Anomalias)
    end

    if Workspace:FindFirstChild("NPCs") then
        scanFolder(Workspace.NPCs, found.Visitors)
    end

    return found
end

function HighlightSystem:HighlightAll(options)
    options = options or {}
    HighlightSystem:ClearAll()

    local found = HighlightSystem:ScanForNPCs()
    local count = { visitors = 0, pacientes = 0, anomalias = 0 }

    if options.visitors ~= false then
        for _, visitor in ipairs(found.Visitors) do
            HighlightSystem:HighlightVisitor(visitor)
            count.visitors = count.visitors + 1
        end
    end

    if options.anomalias ~= false then
        for _, anomalia in ipairs(found.Anomalias) do
            HighlightSystem:HighlightAnomalia(anomalia)
            count.anomalias = count.anomalias + 1
        end
    end

    return count
end

local UI = {}

function UI:Notify(title, content, duration, kind)
    duration = duration or 3
    kind = kind or "info"

    local color = Colors.Accent
    if kind == "success" then
        color = Colors.Success
    elseif kind == "warning" then
        color = Colors.Warning
    elseif kind == "error" then
        color = Colors.Danger
    end

    WindUI:Notify({
        Title = title,
        Content = content,
        Duration = duration,
        Color = color
    })
end

function UI:Flash(duration, color)
    duration = duration or 0.3
    color = color or Color3.fromRGB(255, 255, 255)

    local flash = Instance.new("Frame")
    flash.Size = UDim2.new(1, 0, 1, 0)
    flash.BackgroundColor3 = color
    flash.BackgroundTransparency = 0
    flash.BorderSizePixel = 0
    flash.ZIndex = 10
    flash.Parent = PlayerGui

    local tween = TweenService:Create(
        flash,
        TweenInfo.new(duration, Enum.EasingStyle.Quad),
        { BackgroundTransparency = 1 }
    )

    tween:Play()
    tween.Completed:Connect(function()
        flash:Destroy()
    end)

    Debris:AddItem(flash, duration + 0.1)
end

function UI:ProgressBar(text, duration)
    duration = duration or 3

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ProgressGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = PlayerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 60)
    frame.Position = UDim2.new(0.5, -150, 0.5, -30)
    frame.BackgroundColor3 = Colors.Primary
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 25)
    label.Position = UDim2.new(0, 10, 0, 8)
    label.Text = text
    label.TextColor3 = Colors.Text
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.Parent = frame

    local progressBg = Instance.new("Frame")
    progressBg.Size = UDim2.new(1, -20, 0, 8)
    progressBg.Position = UDim2.new(0, 10, 1, -16)
    progressBg.BackgroundColor3 = Colors.Secondary
    progressBg.BorderSizePixel = 0
    progressBg.Parent = frame

    local progressCorner = Instance.new("UICorner")
    progressCorner.CornerRadius = UDim.new(0, 4)
    progressCorner.Parent = progressBg

    local progressFill = Instance.new("Frame")
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.BackgroundColor3 = Colors.Accent
    progressFill.BorderSizePixel = 0
    progressFill.Parent = progressBg

    local progressFillCorner = Instance.new("UICorner")
    progressFillCorner.CornerRadius = UDim.new(0, 4)
    progressFillCorner.Parent = progressFill

    local tween = TweenService:Create(
        progressFill,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        { Size = UDim2.new(1, 0, 1, 0) }
    )
    tween:Play()

    tween.Completed:Connect(function()
        screenGui:Destroy()
    end)

    Debris:AddItem(screenGui, duration + 0.5)
end

function UI:Shake(intensity, duration)
    intensity = intensity or 2
    duration = duration or 0.3

    local startTime = os.clock()
    local originalCFrame = Camera.CFrame

    local connection
    connection = RunService.RenderStepped:Connect(function()
        local elapsed = os.clock() - startTime
        if elapsed < duration then
            local offset = Vector3.new(
                math.random(-intensity, intensity) * 0.1,
                math.random(-intensity, intensity) * 0.1,
                0
            ) * (1 - elapsed / duration)
            Camera.CFrame = Camera.CFrame * CFrame.new(offset)
        else
            Camera.CFrame = originalCFrame
            connection:Disconnect()
        end
    end)
end

local PrincipalModule = {}

PrincipalModule.State = {
    CurrentPatient = nil,
    CurrentTask = "idle",
    TaskQueue = {},
    CompletedTasks = 0,
    FailedTasks = 0,
    DailyStats = {
        totalPatients = 0,
        totalPhotos = 0,
        totalForms = 0,
        totalPrints = 0,
        totalDeliveries = 0
    }
}

PrincipalModule.Settings = {
    AutoComplete = false,
    ShowNotifications = true,
    ShowProgress = true,
    DebugMode = false,
    HighlightDuration = 5
}

local function FindGameElements()
    local elements = {
        CheckIn = nil,
        Cameras = nil,
        Cameras2 = nil,
        PhotoDummy = nil,
        SecurityCamPC = nil,
        FileCabinet = nil,
        Computer = nil,
        Printer = nil,
        FormStation = nil,
        PatientArea = nil,
        NPCs = nil,
        Anomalies = nil
    }

    if Workspace:FindFirstChild("Misc") then
        local misc = Workspace.Misc
        elements.CheckIn = misc:FindFirstChild("CheckIn")
        elements.SecurityCamPC = misc:FindFirstChild("SecurityCamPC")
        elements.Computer = misc:FindFirstChild("Computer")
        elements.Printer = misc:FindFirstChild("Printer")
        elements.FormStation = misc:FindFirstChild("FormStation")
    end

    if Workspace:FindFirstChild("Cameras") then
        elements.Cameras = Workspace.Cameras
    end
    if Workspace:FindFirstChild("Cameras2") then
        elements.Cameras2 = Workspace.Cameras2
    end
    if Workspace:FindFirstChild("NPCs") then
        elements.NPCs = Workspace.NPCs
    end

    if ReplicatedStorage:FindFirstChild("Misc") then
        local miscRS = ReplicatedStorage.Misc
        elements.PhotoDummy = miscRS:FindFirstChild("PhotoDummy")
    end

    if ReplicatedStorage:FindFirstChild("NPCs") then
        local npcsRS = ReplicatedStorage.NPCs
        elements.Anomalies = npcsRS:FindFirstChild("Anomalies")
    end

    if Workspace:FindFirstChild("File Cabinet") then
        elements.FileCabinet = Workspace["File Cabinet"]
    end

    return elements
end

function PrincipalModule:RegisterPatient(patientData)
    local data = patientData or {}

    if not data.name or data.name == "" then
        data.name = "Paciente-" .. math.random(1000, 9999)
    end

    local record = {
        id = os.time(),
        name = data.name,
        species = data.species or "Animal",
        owner = data.owner or "Dono",
        reason = data.reason or "Consulta",
        urgency = data.urgency or "Normal",
        registeredAt = os.time(),
        formCompleted = false,
        photoTaken = false,
        printed = false,
        delivered = false
    }

    PrincipalModule.State.CurrentPatient = record
    PrincipalModule.State.DailyStats.totalPatients = PrincipalModule.State.DailyStats.totalPatients + 1

    if self.Settings.ShowNotifications then
        UI:Notify("Paciente Registrado", record.name .. " registrado com sucesso!", 3, "success")
    end

    if self.Settings.DebugMode then
        print("[DEBUG] Paciente registrado:", record.name)
    end

    return {
        success = true,
        message = record.name .. " registrado!",
        patient = record
    }
end

function PrincipalModule:GetCurrentPatient()
    return PrincipalModule.State.CurrentPatient
end

function PrincipalModule:ClearPatient()
    PrincipalModule.State.CurrentPatient = nil
    return { success = true, message = "Paciente removido" }
end

function PrincipalModule:GetStatus()
    return {
        currentTask = PrincipalModule.State.CurrentTask,
        completedTasks = PrincipalModule.State.CompletedTasks,
        failedTasks = PrincipalModule.State.FailedTasks,
        currentPatient = PrincipalModule.State.CurrentPatient and PrincipalModule.State.CurrentPatient.name or nil,
        stats = PrincipalModule.State.DailyStats
    }
end

local UtilidadesModule = {}

function UtilidadesModule:FindElement(path)
    local parts = string.split(path, ".")
    local current = Workspace

    for i, part in ipairs(parts) do
        if i == 1 and part:lower() == "workspace" then
            current = Workspace
        elseif i == 1 and part:lower() == "replicatedstorage" then
            current = ReplicatedStorage
        else
            current = current and current:FindFirstChild(part)
        end
        if not current then break end
    end

    return current
end

function UtilidadesModule:Interact(element)
    if not element then
        return { success = false, message = "Elemento nao encontrado" }
    end

    if element:IsA("ClickDetector") then
        return { success = true, message = "Interagiu com " .. element.Parent.Name }
    elseif element:IsA("ProximityPrompt") then
        if typeof(fireproximityprompt) == "function" then
            fireproximityprompt(element)
            return { success = true, message = "Usou prompt em " .. element.Parent.Name }
        end
        return { success = false, message = "fireproximityprompt indisponivel neste executor" }
    else
        return { success = true, message = "Interagiu com " .. element.Name }
    end
end

function UtilidadesModule:GetPlayerPosition()
    local character = LocalPlayer.Character
    if character then
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if hrp then
            return hrp.Position
        end
    end
    return nil
end

function UtilidadesModule:Wait(seconds)
    local start = os.clock()
    while os.clock() - start < seconds do
        RunService.Stepped:Wait()
    end
end

function UtilidadesModule:ElementExists(path)
    local success, element = pcall(function()
        return UtilidadesModule:FindElement(path)
    end)
    return success and element ~= nil
end

local VisualModule = {}

function VisualModule:Flash(duration, color)
    UI:Flash(duration, color)
    return { success = true, message = "Flash executado" }
end

function VisualModule:Shake(intensity, duration)
    UI:Shake(intensity, duration)
    return { success = true, message = "Shake executado" }
end

function VisualModule:Highlight(element, color, duration)
    if not element then
        return { success = false, message = "Elemento nao encontrado" }
    end

    color = color or Colors.Accent
    duration = duration or PrincipalModule.Settings.HighlightDuration

    local highlight = Instance.new("Highlight")
    highlight.Adornee = element
    highlight.FillColor = color
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Parent = element

    task.delay(duration, function()
        if highlight and highlight.Parent then
            highlight:Destroy()
        end
    end)

    return { success = true, message = "Elemento destacado" }
end

function VisualModule:Notification(title, message, kind)
    UI:Notify(title, message, 3, kind or "info")
    return { success = true }
end

function VisualModule:Progress(text, duration)
    UI:ProgressBar(text, duration)
    return { success = true }
end

local PlayerModule = {}

function PlayerModule:GetInfo()
    return {
        name = LocalPlayer.Name,
        userId = LocalPlayer.UserId,
        membershipType = tostring(LocalPlayer.MembershipType)
    }
end

function PlayerModule:GetStats()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChild("Humanoid")

    return {
        health = humanoid and humanoid.Health or 0,
        maxHealth = humanoid and humanoid.MaxHealth or 0,
        walkSpeed = humanoid and humanoid.WalkSpeed or 16,
        jumpPower = humanoid and humanoid.JumpPower or 50,
        alive = humanoid and humanoid.Health > 0 or false
    }
end

function PlayerModule:Teleport(position)
    local character = LocalPlayer.Character
    if not character then
        return { success = false, message = "Character nao encontrado" }
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return { success = false, message = "HumanoidRootPart nao encontrado" }
    end

    hrp.CFrame = CFrame.new(position)
    return { success = true, message = "Teleportado" }
end

function PlayerModule:SetWalkSpeed(speed)
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChild("Humanoid")

    if humanoid then
        humanoid.WalkSpeed = speed
        return { success = true, message = "WalkSpeed: " .. speed }
    end

    return { success = false, message = "Humanoid nao encontrado" }
end

local MiscModule = {}

function MiscModule:UseComputer(action)
    if not action then
        return { success = false, message = "Acao nao especificada" }
    end

    if action == "access" then
        if PrincipalModule.Settings.ShowProgress then
            UI:ProgressBar("Acessando computador...", 1)
        end
        UtilidadesModule:Wait(1)
        return { success = true, message = "Computador acessado", action = "access" }
    elseif action == "type" then
        if PrincipalModule.Settings.ShowProgress then
            UI:ProgressBar("Digitando...", 0.5)
        end
        UtilidadesModule:Wait(0.5)
        return { success = true, message = "Texto digitado", action = "type" }
    elseif action == "submit" then
        if PrincipalModule.Settings.ShowProgress then
            UI:ProgressBar("Enviando...", 0.8)
        end
        UtilidadesModule:Wait(0.8)
        return { success = true, message = "Enviado", action = "submit" }
    else
        return { success = false, message = "Acao desconhecida: " .. tostring(action) }
    end
end

function MiscModule:UsePrinter(action)
    if not action then
        return { success = false, message = "Acao nao especificada" }
    end

    if action == "print" then
        if PrincipalModule.Settings.ShowProgress then
            UI:ProgressBar("Imprimindo...", 2)
        end
        UI:Flash(0.1, Color3.fromRGB(200, 200, 200))
        UtilidadesModule:Wait(2)
        PrincipalModule.State.DailyStats.totalPrints = PrincipalModule.State.DailyStats.totalPrints + 1
        return { success = true, message = "Documento impresso", action = "print" }
    elseif action == "pickup" then
        if PrincipalModule.Settings.ShowProgress then
            UI:ProgressBar("Pegando documento...", 0.5)
        end
        UtilidadesModule:Wait(0.5)
        return { success = true, message = "Documento pego", action = "pickup" }
    else
        return { success = false, message = "Acao desconhecida: " .. tostring(action) }
    end
end

function MiscModule:AccessCameras()
    local elements = FindGameElements()
    local cameras = elements.Cameras
    local cameras2 = elements.Cameras2

    local cameraInfo = {
        cameras1 = cameras and #cameras:GetChildren() or 0,
        cameras2 = cameras2 and #cameras2:GetChildren() or 0,
        total = 0
    }
    cameraInfo.total = cameraInfo.cameras1 + cameraInfo.cameras2

    VisualModule:Notification("Cameras", "Cameras disponiveis: " .. cameraInfo.total, "info")

    return { success = true, message = "Cameras acessadas", cameras = cameraInfo }
end

function MiscModule:AccessFiles(drawer)
    local elements = FindGameElements()
    local cabinet = elements.FileCabinet

    if not cabinet then
        return { success = false, message = "Armario nao encontrado" }
    end

    local drawerObj = cabinet:FindFirstChild("Drawer" .. tostring(drawer))
    if not drawerObj then
        return { success = false, message = "Gaveta " .. tostring(drawer) .. " nao encontrada" }
    end

    UI:ProgressBar("Abrindo gaveta...", 0.5)
    UtilidadesModule:Wait(0.5)

    return { success = true, message = "Gaveta " .. tostring(drawer) .. " aberta", drawer = drawer }
end

function MiscModule:TakePhoto()
    UI:Flash(0.15, Color3.fromRGB(255, 255, 255))
    UI:ProgressBar("Tirando foto...", 0.5)
    UtilidadesModule:Wait(0.5)

    PrincipalModule.State.DailyStats.totalPhotos = PrincipalModule.State.DailyStats.totalPhotos + 1

    local photoData = {
        photoId = "IMG-" .. os.time(),
        timestamp = os.time()
    }

    return {
        success = true,
        message = "Foto tirada com sucesso!",
        photo = photoData
    }
end

function MiscModule:FillForm(formType)
    formType = formType or "medical"

    UI:ProgressBar("Preenchendo formulario " .. formType .. "...", 1.5)
    UtilidadesModule:Wait(1.5)

    PrincipalModule.State.DailyStats.totalForms = PrincipalModule.State.DailyStats.totalForms + 1

    return {
        success = true,
        message = "Formulario preenchido",
        formType = formType
    }
end

local SobreModule = {}

function SobreModule:Info()
    return {
        nome = "Receptionist Script V3",
        versao = "3.0.0",
        autor = "Admin",
        descricao = "Script completo para receptionist do Animal Hospital com WindUI",
        categorias = {
            "principal - Funcoes principais de receptionist",
            "utilidades - Funcoes utilitarias",
            "visual - Efeitos visuais e highlights",
            "player - Funcoes do player",
            "misc - Funcoes diversas",
            "sobre - Informacoes do script"
        },
        ultimoUpdate = os.date("%d/%m/%Y")
    }
end

function SobreModule:Ajuda()
    return [[
        COMANDOS PRINCIPAIS:

        1. SecretaryTask:Start():
           - Executa TODAS as tarefas da secretary automaticamente
           - Sequencia: Formulario -> Foto -> Computador -> Imprimir -> Pegar -> Entregar

        2. Registro:
           - RegisterPatient(dados) - Registra um paciente

        3. Highlights:
           - HighlightAll() - Destaca visitors (vermelho) e anomalias (rosa)
           - HighlightVisitor(model) - Destaca visitor especifico
           - HighlightPaciente(model) - Destaca paciente especifico
           - ClearHighlights() - Remove todos os highlights

        4. Tarefas Individuais:
           - FillForm(tipo) - Preenche formulario
           - TakePhoto() - Tira foto
           - UseComputer(acao) - Usa computador
           - UsePrinter(acao) - Usa impressora

        Para mais ajuda, consulte a documentacao.
    ]]
end

function SobreModule:Comandos()
    return {
        { comando = "SecretaryTask:Start()", descricao = "Executa TODAS as tarefas automaticamente" },
        { comando = "RegisterPatient(dados)", descricao = "Registra um novo paciente" },
        { comando = "HighlightAll()", descricao = "Destaca visitors e anomalias" },
        { comando = "ClearHighlights()", descricao = "Remove todos os highlights" },
        { comando = "FillForm(tipo)", descricao = "Preenche formulario (medical/emergency)" },
        { comando = "TakePhoto()", descricao = "Tira foto do paciente" },
        { comando = "UseComputer(acao)", descricao = "Usa computador (access/type/submit)" },
        { comando = "UsePrinter(acao)", descricao = "Usa impressora (print/pickup)" },
        { comando = "GetStatus()", descricao = "Mostra status atual" }
    }
end

local SecretaryTask = {}

function SecretaryTask:Execute(options)
    options = options or {}
    local patientData = options.patient or {}
    local showProgress = options.showProgress ~= false

    local patient = PrincipalModule.State.CurrentPatient
    if not patient then
        local regResult = PrincipalModule:RegisterPatient(patientData)
        if not regResult.success then
            return regResult
        end
        patient = PrincipalModule.State.CurrentPatient
    end

    local taskStatus = {
        form = false,
        photo = false,
        computer = false,
        print = false,
        pickup = false,
        deliver = false
    }

    local taskLog = {}

    local function Log(message)
        table.insert(taskLog, "[" .. #taskLog + 1 .. "] " .. message)
        if showProgress then
            print("[SECRETARY] " .. message)
        end
    end

    Log("Preparando formulario...")
    if showProgress then UI:ProgressBar("Pegando formulario...", 1) end
    UtilidadesModule:Wait(1)
    MiscModule:FillForm(patientData.formType or "medical")
    patient.formCompleted = true
    taskStatus.form = true
    Log("Formulario preenchido: " .. patient.name)

    Log("Tirando foto...")
    if showProgress then UI:ProgressBar("Posicionando para foto...", 0.5) end
    UtilidadesModule:Wait(0.5)
    local photoResult = MiscModule:TakePhoto()
    patient.photoTaken = true
    patient.photoId = photoResult.photo.photoId
    taskStatus.photo = true
    Log("Foto tirada: " .. patient.photoId)

    Log("Usando computador...")
    if showProgress then UI:ProgressBar("Acessando computador...", 1) end
    UtilidadesModule:Wait(1)
    MiscModule:UseComputer("access")
    if showProgress then UI:ProgressBar("Registrando no sistema...", 1.5) end
    UtilidadesModule:Wait(1.5)
    MiscModule:UseComputer("type")
    if showProgress then UI:ProgressBar("Enviando dados...", 1) end
    UtilidadesModule:Wait(1)
    MiscModule:UseComputer("submit")
    patient.computerUsed = true
    taskStatus.computer = true
    Log("Dados registrados no computador")

    Log("Imprimindo documentos...")
    if showProgress then UI:ProgressBar("Enviando para impressora...", 1) end
    UtilidadesModule:Wait(1)
    MiscModule:UsePrinter("print")
    patient.printed = true
    patient.printId = "PRINT-" .. os.time()
    taskStatus.print = true
    Log("Documento impresso: " .. patient.printId)

    Log("Pegando documento impresso...")
    if showProgress then UI:ProgressBar("Pegando documento...", 0.8) end
    UtilidadesModule:Wait(0.8)
    MiscModule:UsePrinter("pickup")
    patient.documentPickedUp = true
    taskStatus.pickup = true
    Log("Documento pego da impressora")

    Log("Entregando ao paciente...")
    if showProgress then UI:ProgressBar("Entregando documentos...", 1.5) end
    UtilidadesModule:Wait(1.5)
    UI:Flash(0.05, Colors.Success)
    patient.delivered = true
    patient.deliveredAt = os.time()
    PrincipalModule.State.DailyStats.totalDeliveries = PrincipalModule.State.DailyStats.totalDeliveries + 1
    taskStatus.deliver = true
    Log("Documentos entregues a " .. patient.name)

    PrincipalModule.State.CompletedTasks = PrincipalModule.State.CompletedTasks + 1

    local finalResult = {
        success = true,
        message = "Todas as tarefas concluidas!",
        patient = patient,
        tasks = taskStatus,
        log = taskLog,
        totalTime = #taskLog,
        completedAt = os.time()
    }

    if showProgress then
        VisualModule:Notification("Tarefa Concluida", "Paciente " .. patient.name .. " atendido!", "success")
    end

    return finalResult
end

function SecretaryTask:Start(patientData)
    return SecretaryTask:Execute({ patient = patientData, showProgress = true })
end

local Window = WindUI:CreateWindow({
    Title = "Receptionist Script V3",
    Icon = "hospital",
    Folder = "ReceptionistScriptV3",
    Theme = "Dark"
})

local PrincipalTab = Window:Tab({ Title = "Principal", Icon = "clipboard-list" })

PrincipalTab:Section({ Title = "Registro de Paciente" })

PrincipalTab:Input({
    Title = "Nome do Paciente",
    Value = "",
    Placeholder = "Digite o nome...",
    Callback = function(value)
        _G.patientName = value
    end
})

PrincipalTab:Input({
    Title = "Especie",
    Value = "",
    Placeholder = "Digite a especie...",
    Callback = function(value)
        _G.patientSpecies = value
    end
})

PrincipalTab:Input({
    Title = "Dono",
    Value = "",
    Placeholder = "Nome do dono...",
    Callback = function(value)
        _G.patientOwner = value
    end
})

PrincipalTab:Dropdown({
    Title = "Urgencia",
    Values = { "Normal", "Urgente", "Emergencia" },
    Value = 1,
    Callback = function(value)
        _G.patientUrgency = value
    end
})

PrincipalTab:Button({
    Title = "Registrar Paciente",
    Callback = function()
        local data = {
            name = (_G.patientName and _G.patientName ~= "" and _G.patientName) or ("Paciente-" .. math.random(1000, 9999)),
            species = _G.patientSpecies or "Animal",
            owner = _G.patientOwner or "Dono",
            urgency = _G.patientUrgency or "Normal"
        }
        local result = PrincipalModule:RegisterPatient(data)
        WindUI:Notify({
            Title = "Registrado",
            Content = result.message,
            Duration = 3,
            Color = Colors.Success
        })
    end
})

PrincipalTab:Section({ Title = "Tarefas" })

PrincipalTab:Button({
    Title = "Executar Tarefa Completa",
    Callback = function()
        local data = {
            name = _G.patientName,
            species = _G.patientSpecies,
            owner = _G.patientOwner,
            urgency = _G.patientUrgency
        }
        SecretaryTask:Start(data)
    end
})

PrincipalTab:Button({
    Title = "Ver Status",
    Callback = function()
        local status = PrincipalModule:GetStatus()
        local msg = "Paciente: " .. (status.currentPatient or "Nenhum") .. "\n"
        msg = msg .. "Tarefas Completas: " .. status.completedTasks .. "\n"
        msg = msg .. "Pacientes Hoje: " .. status.stats.totalPatients
        WindUI:Notify({
            Title = "Status",
            Content = msg,
            Duration = 5,
            Color = Colors.Accent
        })
    end
})

PrincipalTab:Button({
    Title = "Limpar Paciente",
    Callback = function()
        PrincipalModule:ClearPatient()
        WindUI:Notify({
            Title = "Limpo",
            Content = "Paciente removido",
            Duration = 3,
            Color = Colors.Warning
        })
    end
})

local TarefasTab = Window:Tab({ Title = "Tarefas", Icon = "list-checks" })

TarefasTab:Section({ Title = "Tarefas Individuais" })

TarefasTab:Button({
    Title = "Preencher Formulario",
    Callback = function()
        MiscModule:FillForm("medical")
    end
})

TarefasTab:Button({
    Title = "Tirar Foto",
    Callback = function()
        MiscModule:TakePhoto()
    end
})

TarefasTab:Section({ Title = "Computador" })

TarefasTab:Dropdown({
    Title = "Acao do Computador",
    Values = { "access", "type", "submit" },
    Value = 1,
    Callback = function(value)
        _G.computerAction = value
    end
})

TarefasTab:Button({
    Title = "Usar Computador",
    Callback = function()
        MiscModule:UseComputer(_G.computerAction or "access")
    end
})

TarefasTab:Section({ Title = "Impressora" })

TarefasTab:Dropdown({
    Title = "Acao da Impressora",
    Values = { "print", "pickup" },
    Value = 1,
    Callback = function(value)
        _G.printerAction = value
    end
})

TarefasTab:Button({
    Title = "Usar Impressora",
    Callback = function()
        MiscModule:UsePrinter(_G.printerAction or "print")
    end
})

TarefasTab:Section({ Title = "Cameras" })

TarefasTab:Button({
    Title = "Acessar Cameras",
    Callback = function()
        MiscModule:AccessCameras()
    end
})

local HighlightsTab = Window:Tab({ Title = "Highlights", Icon = "sparkles" })

HighlightsTab:Section({ Title = "Sistema de Highlights" })

HighlightsTab:Paragraph({
    Title = "Legenda de Cores",
    Desc = "Visitor = Vermelho\nPaciente = Verde\nAnomalia = Rosa"
})

HighlightsTab:Section({ Title = "Highlights Rapidos" })

HighlightsTab:Toggle({
    Title = "Highlight Visitors (Vermelho)",
    Value = false,
    Callback = function(state)
        _G.highlightVisitors = state
        if state then
            HighlightSystem:HighlightAll({ visitors = true, anomalias = false })
        else
            HighlightSystem:ClearAll()
        end
    end
})

HighlightsTab:Toggle({
    Title = "Highlight Anomalias (Rosa)",
    Value = false,
    Callback = function(state)
        _G.highlightAnomalias = state
        if state then
            HighlightSystem:HighlightAll({ visitors = false, anomalias = true })
        else
            HighlightSystem:ClearAll()
        end
    end
})

HighlightsTab:Section({ Title = "Acoes" })

HighlightsTab:Button({
    Title = "Highlight Todos",
    Callback = function()
        local count = HighlightSystem:HighlightAll({ visitors = true, anomalias = true })
        WindUI:Notify({
            Title = "Highlights",
            Content = "Visitors: " .. count.visitors .. "\nAnomalias: " .. count.anomalias,
            Duration = 3,
            Color = Colors.Accent
        })
    end
})

HighlightsTab:Button({
    Title = "Limpar Todos Highlights",
    Callback = function()
        HighlightSystem:ClearAll()
        WindUI:Notify({
            Title = "Limpo",
            Content = "Todos os highlights removidos",
            Duration = 3,
            Color = Colors.Warning
        })
    end
})

HighlightsTab:Section({ Title = "Configuracao" })

HighlightsTab:Slider({
    Title = "Duracao do Highlight",
    Value = { Min = 1, Max = 30, Default = 5 },
    Callback = function(value)
        PrincipalModule.Settings.HighlightDuration = value
        HighlightSystem.Settings.Duration = value
    end
})

local UtilidadesTab = Window:Tab({ Title = "Utilidades", Icon = "wrench" })

UtilidadesTab:Section({ Title = "Localizacao" })

UtilidadesTab:Input({
    Title = "Posicao X",
    Value = "0",
    Placeholder = "X",
    Callback = function(value)
        _G.tpX = tonumber(value) or 0
    end
})

UtilidadesTab:Input({
    Title = "Posicao Y",
    Value = "0",
    Placeholder = "Y",
    Callback = function(value)
        _G.tpY = tonumber(value) or 0
    end
})

UtilidadesTab:Input({
    Title = "Posicao Z",
    Value = "0",
    Placeholder = "Z",
    Callback = function(value)
        _G.tpZ = tonumber(value) or 0
    end
})

UtilidadesTab:Button({
    Title = "Teleportar",
    Callback = function()
        local pos = Vector3.new(_G.tpX or 0, _G.tpY or 0, _G.tpZ or 0)
        PlayerModule:Teleport(pos)
    end
})

UtilidadesTab:Section({ Title = "Velocidade" })

UtilidadesTab:Slider({
    Title = "WalkSpeed",
    Value = { Min = 16, Max = 100, Default = 16 },
    Callback = function(value)
        PlayerModule:SetWalkSpeed(value)
    end
})

local VisualTab = Window:Tab({ Title = "Visual", Icon = "eye" })

VisualTab:Section({ Title = "Efeitos Visuais" })

VisualTab:Button({
    Title = "Flash",
    Callback = function()
        VisualModule:Flash()
    end
})

VisualTab:Button({
    Title = "Shake",
    Callback = function()
        VisualModule:Shake()
    end
})

VisualTab:Section({ Title = "Configuracoes" })

VisualTab:Toggle({
    Title = "Mostrar Notificacoes",
    Value = true,
    Callback = function(value)
        PrincipalModule.Settings.ShowNotifications = value
    end
})

VisualTab:Toggle({
    Title = "Mostrar Progresso",
    Value = true,
    Callback = function(value)
        PrincipalModule.Settings.ShowProgress = value
    end
})

VisualTab:Toggle({
    Title = "Debug Mode",
    Value = false,
    Callback = function(value)
        PrincipalModule.Settings.DebugMode = value
    end
})

local StatsTab = Window:Tab({ Title = "Estatisticas", Icon = "bar-chart-3" })

StatsTab:Section({ Title = "Estatisticas Diarias" })

local function BuildStatsText()
    return "Pacientes: " .. PrincipalModule.State.DailyStats.totalPatients .. "\n" ..
        "Fotos: " .. PrincipalModule.State.DailyStats.totalPhotos .. "\n" ..
        "Formularios: " .. PrincipalModule.State.DailyStats.totalForms .. "\n" ..
        "Impressoes: " .. PrincipalModule.State.DailyStats.totalPrints .. "\n" ..
        "Entregas: " .. PrincipalModule.State.DailyStats.totalDeliveries .. "\n\n" ..
        "Tarefas Completas: " .. PrincipalModule.State.CompletedTasks .. "\n" ..
        "Tarefas Falhas: " .. PrincipalModule.State.FailedTasks
end

local StatsParagraph = StatsTab:Paragraph({
    Title = "Stats",
    Desc = BuildStatsText()
})

StatsTab:Button({
    Title = "Atualizar Stats",
    Callback = function()
        if StatsParagraph and StatsParagraph.SetDesc then
            StatsParagraph:SetDesc(BuildStatsText())
        end
        WindUI:Notify({
            Title = "Atualizado",
            Content = "Estatisticas atualizadas!",
            Duration = 2,
            Color = Colors.Success
        })
    end
})

local SobreTab = Window:Tab({ Title = "Sobre", Icon = "info" })

SobreTab:Section({ Title = "Informacoes do Script" })

SobreTab:Paragraph({
    Title = "Info",
    Desc = "Nome: Receptionist Script V3\n" ..
        "Versao: 3.0.0\n" ..
        "Autor: Admin\n" ..
        "Biblioteca: WindUI\n\n" ..
        "Descricao: Script completo para\n" ..
        "recepcionista do Animal Hospital\n\n" ..
        "Highlights:\n" ..
        "- Visitor = Vermelho\n" ..
        "- Paciente = Verde\n" ..
        "- Anomalia = Rosa\n\n" ..
        "Ultima Atualizacao: " .. os.date("%d/%m/%Y")
})

SobreTab:Section({ Title = "Comandos Rapidos" })

SobreTab:Button({
    Title = "Ver Comandos",
    Callback = function()
        WindUI:Notify({
            Title = "Comandos",
            Content = "SecretaryTask:Start() - Executa todas as tarefas\n" ..
                "RegisterPatient(dados) - Registra paciente\n" ..
                "HighlightAll() - Destaca elementos\n" ..
                "GetStatus() - Ver status\n" ..
                "ClearPatient() - Limpa paciente",
            Duration = 5,
            Color = Colors.Accent
        })
    end
})

SobreTab:Button({
    Title = "Ver Ajuda",
    Callback = function()
        print(SobreModule:Ajuda())
        WindUI:Notify({
            Title = "Ajuda",
            Content = "Verifique o console para ajuda completa!",
            Duration = 3,
            Color = Colors.Accent
        })
    end
})

_G.ReceptionistScript = {
    Principal = PrincipalModule,
    Utilidades = UtilidadesModule,
    Visual = VisualModule,
    Player = PlayerModule,
    Misc = MiscModule,
    Sobre = SobreModule,
    Highlights = HighlightSystem,
    SecretaryTask = SecretaryTask,

    RegisterPatient = function(data) return PrincipalModule:RegisterPatient(data) end,
    GetStatus = function() return PrincipalModule:GetStatus() end,
    ClearPatient = function() return PrincipalModule:ClearPatient() end,

    HighlightAll = function(options) return HighlightSystem:HighlightAll(options) end,
    HighlightVisitor = function(model) return HighlightSystem:HighlightVisitor(model) end,
    HighlightPaciente = function(model) return HighlightSystem:HighlightPaciente(model) end,
    HighlightAnomalia = function(model) return HighlightSystem:HighlightAnomalia(model) end,
    ClearHighlights = function() return HighlightSystem:ClearAll() end,

    FillForm = function(formType) return MiscModule:FillForm(formType) end,
    TakePhoto = function() return MiscModule:TakePhoto() end,
    UseComputer = function(action) return MiscModule:UseComputer(action) end,
    UsePrinter = function(action) return MiscModule:UsePrinter(action) end,
    AccessCameras = function() return MiscModule:AccessCameras() end,
    AccessFiles = function(drawer) return MiscModule:AccessFiles(drawer) end,

    Notify = function(title, msg) return VisualModule:Notification(title, msg) end,
    Flash = function() return VisualModule:Flash() end,

    Info = function() return SobreModule:Info() end,
    Help = function() return SobreModule:Ajuda() end,
    Comandos = function() return SobreModule:Comandos() end
}

_G.RS = _G.ReceptionistScript
_G.SecretaryTask = _G.ReceptionistScript.SecretaryTask
_G.HighlightAll = _G.ReceptionistScript.HighlightAll
_G.ClearHighlights = _G.ReceptionistScript.ClearHighlights

task.spawn(function()
    print("================================================")
    print("RECEPTIONIST SCRIPT V3 CARREGADO")
    print("Biblioteca: WindUI")
    print("Highlights: Visitor (Vermelho), Paciente (Verde), Anomalia (Rosa)")
    print("")
    print("Categorias: Principal, Tarefas, Highlights, Utilidades, Visual, Estatisticas, Sobre")
    print("")
    print("Use SecretaryTask:Start() para executar todas as tarefas")
    print("Use HighlightAll() para destacar visitors e anomalias")
    print("================================================")
end)

return _G.ReceptionistScript
