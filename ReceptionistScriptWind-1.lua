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

function HighlightSystem:HighlightAnomalia(model)
    if not model then return nil end
    return HighlightSystem:CreateHighlight(model, HighlightSystem.Settings.AnomaliaColor, {
        fillTransparency = 0.4,
        duration = HighlightSystem.Settings.Duration
    })
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

local PrincipalModule = {}
local UtilidadesModule = {}
local PlayerModule = {}
local MiscModule = {}
local SobreModule = {}

local function FindGameElements()
    local elements = {
        CheckIn = nil,
        Computer = nil,
        Printer = nil,
        FormStation = nil,
        NPCs = nil,
        Visitors = nil,
        Anomalies = nil
    }

    if Workspace:FindFirstChild("Misc") then
        local misc = Workspace.Misc
        elements.CheckIn = misc:FindFirstChild("CheckIn")
        elements.Computer = misc:FindFirstChild("Computer")
        elements.Printer = misc:FindFirstChild("Printer")
        elements.FormStation = misc:FindFirstChild("FormStation")
    end

    if Workspace:FindFirstChild("NPCs") then
        elements.NPCs = Workspace.NPCs
    end

    if ReplicatedStorage:FindFirstChild("NPCs") then
        local npcsRS = ReplicatedStorage.NPCs
        elements.Visitors = npcsRS:FindFirstChild("Visitors")
        elements.Anomalies = npcsRS:FindFirstChild("Anomalies")
    end

    return elements
end

local SecretariaModule = {
    State = {
        Enabled = false,
        Running = false,
        CurrentPatient = nil
    },
    Settings = {
        LoopDelay = 1.5,
        ShowNotifications = true,
        ShowProgress = true,
        AutoSkipAnomalies = true
    },
    Stats = {
        processed = 0,
        anomaliesSkipped = 0
    }
}

local function IsAnomaly(model)
    local elements = FindGameElements()
    if elements.Anomalies and model:IsDescendantOf(elements.Anomalies) then
        return true
    end
    return false
end

local function GetWaitingPatients()
    local waiting = {}
    local elements = FindGameElements()
    local pools = {}

    if elements.Visitors then table.insert(pools, elements.Visitors) end
    if elements.NPCs then table.insert(pools, elements.NPCs) end
    if SecretariaModule.Settings.AutoSkipAnomalies and elements.Anomalies then
        table.insert(pools, elements.Anomalies)
    end

    for _, pool in ipairs(pools) do
        for _, child in ipairs(pool:GetChildren()) do
            if (child:IsA("Model") or child:IsA("Folder")) and child:FindFirstChild("Humanoid") then
                if not child:GetAttribute("SecretariaProcessed") then
                    table.insert(waiting, child)
                end
            end
        end
    end

    return waiting
end

local function ProcessPatient(model)
    SecretariaModule.State.CurrentPatient = model

    if SecretariaModule.Settings.AutoSkipAnomalies and IsAnomaly(model) then
        HighlightSystem:HighlightAnomalia(model)
        model:SetAttribute("SecretariaProcessed", true)
        SecretariaModule.Stats.anomaliesSkipped += 1

        if SecretariaModule.Settings.ShowNotifications then
            UI:Notify("Anomalia Detectada", (model.Name or "Paciente") .. " foi sinalizado e NAO sera registrado.", 4, "warning")
        end

        SecretariaModule.State.CurrentPatient = nil
        return
    end

    HighlightSystem:HighlightVisitor(model)

    local elements = FindGameElements()

    if elements.CheckIn then
        local prompt = elements.CheckIn:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt and typeof(fireproximityprompt) == "function" then
            pcall(fireproximityprompt, prompt)
        end
    end

    if SecretariaModule.Settings.ShowProgress then UI:ProgressBar("Chamando paciente...", 0.6) end
    task.wait(0.6)

    UI:Flash(0.15, Color3.fromRGB(255, 255, 255))
    if SecretariaModule.Settings.ShowProgress then UI:ProgressBar("Tirando foto...", 0.5) end
    task.wait(0.5)

    if elements.Computer then
        local prompt = elements.Computer:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt and typeof(fireproximityprompt) == "function" then
            pcall(fireproximityprompt, prompt)
        end
    end
    if SecretariaModule.Settings.ShowProgress then UI:ProgressBar("Registrando no computador...", 1) end
    task.wait(1)

    if elements.Printer then
        local prompt = elements.Printer:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt and typeof(fireproximityprompt) == "function" then
            pcall(fireproximityprompt, prompt)
        end
    end
    if SecretariaModule.Settings.ShowProgress then UI:ProgressBar("Imprimindo ficha...", 1) end
    task.wait(1)

    model:SetAttribute("SecretariaProcessed", true)
    SecretariaModule.Stats.processed += 1
    SecretariaModule.State.CurrentPatient = nil

    if SecretariaModule.Settings.ShowNotifications then
        UI:Notify("Paciente Atendido", (model.Name or "Paciente") .. " registrado e liberado.", 3, "success")
    end
end

function SecretariaModule:Loop()
    while SecretariaModule.State.Enabled do
        local success, waiting = pcall(GetWaitingPatients)

        if success and waiting and #waiting > 0 then
            for _, patient in ipairs(waiting) do
                if not SecretariaModule.State.Enabled then break end

                local processOk, processErr = pcall(ProcessPatient, patient)
                if not processOk then
                    warn("[Secretaria] Erro ao processar paciente: " .. tostring(processErr))
                end

                task.wait(SecretariaModule.Settings.LoopDelay)
            end
        else
            task.wait(1)
        end
    end

    SecretariaModule.State.Running = false
end

function SecretariaModule:Start()
    if SecretariaModule.State.Running then return end

    SecretariaModule.State.Enabled = true
    SecretariaModule.State.Running = true

    task.spawn(function()
        SecretariaModule:Loop()
    end)

    if SecretariaModule.Settings.ShowNotifications then
        UI:Notify("Secretaria Ativada", "Atendimento automatico iniciado.", 3, "success")
    end
end

function SecretariaModule:Stop()
    SecretariaModule.State.Enabled = false

    if SecretariaModule.Settings.ShowNotifications then
        UI:Notify("Secretaria Desativada", "Atendimento automatico parado.", 3, "warning")
    end
end

function SecretariaModule:GetStatus()
    return {
        enabled = SecretariaModule.State.Enabled,
        running = SecretariaModule.State.Running,
        currentPatient = SecretariaModule.State.CurrentPatient and SecretariaModule.State.CurrentPatient.Name or nil,
        processed = SecretariaModule.Stats.processed,
        anomaliesSkipped = SecretariaModule.Stats.anomaliesSkipped
    }
end

local Window = WindUI:CreateWindow({
    Title = "Receptionist Script V3",
    Icon = "hospital",
    Folder = "ReceptionistScriptV3",
    Theme = "Dark"
})

local SecretariaTab = Window:Tab({ Title = "Secretaria", Icon = "user-round" })

SecretariaTab:Section({ Title = "Atendimento Automatico" })

SecretariaTab:Paragraph({
    Title = "Como funciona",
    Desc = "Ao ativar, o script chama pacientes na fila, tira foto, registra no computador e imprime a ficha automaticamente.\nPacientes marcados como Anomalia (pasta Anomalies) sao sinalizados em rosa e NAO sao registrados, para nao deixar nada perigoso entrar."
})

SecretariaTab:Toggle({
    Title = "Ativar Secretaria Automatica",
    Value = false,
    Callback = function(state)
        if state then
            SecretariaModule:Start()
        else
            SecretariaModule:Stop()
        end
    end
})

SecretariaTab:Section({ Title = "Configuracoes" })

SecretariaTab:Slider({
    Title = "Intervalo entre pacientes (s)",
    Value = { Min = 1, Max = 10, Default = 1.5 },
    Callback = function(value)
        SecretariaModule.Settings.LoopDelay = value
    end
})

SecretariaTab:Toggle({
    Title = "Pular Anomalias Automaticamente",
    Desc = "Recomendado manter ativado",
    Value = true,
    Callback = function(state)
        SecretariaModule.Settings.AutoSkipAnomalies = state
    end
})

SecretariaTab:Toggle({
    Title = "Mostrar Notificacoes",
    Value = true,
    Callback = function(state)
        SecretariaModule.Settings.ShowNotifications = state
    end
})

SecretariaTab:Toggle({
    Title = "Mostrar Progresso",
    Value = true,
    Callback = function(state)
        SecretariaModule.Settings.ShowProgress = state
    end
})

SecretariaTab:Section({ Title = "Status" })

local function BuildStatusText()
    local status = SecretariaModule:GetStatus()
    return "Ativo: " .. tostring(status.enabled) .. "\n" ..
        "Paciente Atual: " .. (status.currentPatient or "Nenhum") .. "\n" ..
        "Pacientes Atendidos: " .. status.processed .. "\n" ..
        "Anomalias Barradas: " .. status.anomaliesSkipped
end

local StatusParagraph = SecretariaTab:Paragraph({
    Title = "Status Atual",
    Desc = BuildStatusText()
})

SecretariaTab:Button({
    Title = "Atualizar Status",
    Callback = function()
        if StatusParagraph and StatusParagraph.SetDesc then
            StatusParagraph:SetDesc(BuildStatusText())
        end
    end
})

task.spawn(function()
    while true do
        task.wait(2)
        if StatusParagraph and StatusParagraph.SetDesc then
            StatusParagraph:SetDesc(BuildStatusText())
        end
    end
end)

local PrincipalTab = Window:Tab({ Title = "Principal", Icon = "clipboard-list" })
PrincipalTab:Paragraph({ Title = "Principal", Desc = "Em desenvolvimento." })

local UtilidadesTab = Window:Tab({ Title = "Utilidades", Icon = "wrench" })
UtilidadesTab:Paragraph({ Title = "Utilidades", Desc = "Em desenvolvimento." })

local PlayerTab = Window:Tab({ Title = "Player", Icon = "user" })
PlayerTab:Paragraph({ Title = "Player", Desc = "Em desenvolvimento." })

local MiscTab = Window:Tab({ Title = "Misc", Icon = "layers" })
MiscTab:Paragraph({ Title = "Misc", Desc = "Em desenvolvimento." })

local SobreTab = Window:Tab({ Title = "Sobre", Icon = "info" })
SobreTab:Paragraph({
    Title = "Receptionist Script V3",
    Desc = "Biblioteca: WindUI\nModulo ativo: Secretaria (automacao de atendimento)\nDemais modulos (Principal, Utilidades, Player, Misc) serao adicionados nas proximas versoes."
})

_G.ReceptionistScript = {
    Principal = PrincipalModule,
    Utilidades = UtilidadesModule,
    Player = PlayerModule,
    Misc = MiscModule,
    Sobre = SobreModule,
    Highlights = HighlightSystem,
    Secretaria = SecretariaModule,

    StartSecretaria = function() return SecretariaModule:Start() end,
    StopSecretaria = function() return SecretariaModule:Stop() end,
    GetSecretariaStatus = function() return SecretariaModule:GetStatus() end
}

_G.RS = _G.ReceptionistScript
_G.Secretaria = SecretariaModule

task.spawn(function()
    print("================================================")
    print("RECEPTIONIST SCRIPT V3 CARREGADO")
    print("Modulo ativo: Secretaria (atendimento automatico)")
    print("Use o Toggle na aba Secretaria ou _G.Secretaria:Start() / :Stop()")
    print("================================================")
end)

return _G.ReceptionistScript
