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
    HighlightVisitor = Color3.fromRGB(50, 255, 50),
    HighlightPaciente = Color3.fromRGB(50, 255, 50),
    HighlightAnomalia = Color3.fromRGB(220, 53, 69)
}

local FindGameElements

local HighlightSystem = {
    ActiveHighlights = {},
    Enabled = true,
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

function HighlightSystem:HighlightAnomalia(model, duration)
    if not model then return nil end
    return HighlightSystem:CreateHighlight(model, HighlightSystem.Settings.AnomaliaColor, {
        fillTransparency = 0.4,
        duration = duration
    })
end

function HighlightSystem:HighlightPaciente(model)
    if not model then return nil end
    return HighlightSystem:CreateHighlight(model, HighlightSystem.Settings.PacienteColor, {
        fillTransparency = 0.5
    })
end

function HighlightSystem:RefreshScan()
    local elements = FindGameElements()
    local seen = {}

    local function scanPool(pool, isAnomalyPool)
        if not pool then return end
        for _, child in ipairs(pool:GetChildren()) do
            if (child:IsA("Model") or child:IsA("Folder")) and child:FindFirstChild("Humanoid") then
                local id = child:GetFullName()
                seen[id] = true
                if not HighlightSystem.ActiveHighlights[id] then
                    if isAnomalyPool then
                        HighlightSystem:HighlightAnomalia(child)
                    else
                        HighlightSystem:HighlightPaciente(child)
                    end
                end
            end
        end
    end

    scanPool(elements.Visitors, false)
    scanPool(elements.NPCs, false)
    scanPool(elements.Anomalies, true)

    for id, highlight in pairs(HighlightSystem.ActiveHighlights) do
        if not seen[id] then
            if highlight and highlight.Parent then
                highlight:Destroy()
            end
            HighlightSystem.ActiveHighlights[id] = nil
        end
    end
end

function HighlightSystem:StartLiveScan()
    if HighlightSystem._scanning then return end
    HighlightSystem._scanning = true
    task.spawn(function()
        while HighlightSystem._scanning do
            if HighlightSystem.Enabled then
                pcall(function() HighlightSystem:RefreshScan() end)
            end
            task.wait(1)
        end
    end)
end

function HighlightSystem:StopLiveScan()
    HighlightSystem._scanning = false
    HighlightSystem:ClearAll()
end

function HighlightSystem:SetEnabled(state)
    HighlightSystem.Enabled = state
    if not state then
        HighlightSystem:ClearAll()
    end
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

local PrincipalModule = {}
local UtilidadesModule = {}
local PlayerModule = {}
local MiscModule = {}
local SobreModule = {}

FindGameElements = function()
    local elements = {
        CheckIn = nil,
        Camera = nil,
        Computer = nil,
        Printer = nil,
        FormStation = nil,
        PatientBadge = nil,
        VisitorBadge = nil,
        NPCs = nil,
        Visitors = nil,
        Anomalies = nil
    }

    if Workspace:FindFirstChild("Misc") then
        local misc = Workspace.Misc
        elements.CheckIn = misc:FindFirstChild("CheckIn")

        if elements.CheckIn then
            elements.Camera = elements.CheckIn:FindFirstChild("Camera")
            elements.Computer = elements.CheckIn:FindFirstChild("Computer")
            elements.Printer = elements.CheckIn:FindFirstChild("Printer")
            elements.PatientBadge = elements.CheckIn:FindFirstChild("PatientBadgeBase")
            elements.VisitorBadge = elements.CheckIn:FindFirstChild("VisitorBadgeBase")
            elements.FormStation = elements.CheckIn:FindFirstChild("Form") or elements.CheckIn:FindFirstChild("FormStation")
        end

        if not elements.Computer then
            elements.Computer = misc:FindFirstChild("Computer")
        end
        if not elements.Printer then
            elements.Printer = misc:FindFirstChild("Printer")
        end
        if not elements.FormStation then
            elements.FormStation = misc:FindFirstChild("FormStation")
        end
    end

    if not elements.FormStation and ReplicatedStorage:FindFirstChild("Misc") then
        elements.FormStation = ReplicatedStorage.Misc:FindFirstChild("Form")
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
        AutoSkipAnomalies = true,
        FichaPickupTimeout = 8
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

local function WaitAndFire(container, timeout)
    if not container then return false end
    timeout = timeout or 5

    local prompt
    local elapsed = 0

    repeat
        prompt = container:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt and prompt.Enabled then
            break
        end
        task.wait(0.2)
        elapsed += 0.2
    until elapsed >= timeout

    if prompt and typeof(fireproximityprompt) == "function" then
        return pcall(fireproximityprompt, prompt)
    end
    return false
end

local function GetWaitingPatients()
    local waiting = {}
    local elements = FindGameElements()
    local pools = {
        { pool = elements.Visitors, isVisitor = true },
        { pool = elements.NPCs, isVisitor = false }
    }

    if SecretariaModule.Settings.AutoSkipAnomalies and elements.Anomalies then
        table.insert(pools, { pool = elements.Anomalies, isVisitor = false })
    end

    for _, entry in ipairs(pools) do
        if entry.pool then
            for _, child in ipairs(entry.pool:GetChildren()) do
                if (child:IsA("Model") or child:IsA("Folder")) and child:FindFirstChild("Humanoid") then
                    if not child:GetAttribute("SecretariaProcessed") then
                        child:SetAttribute("SecretariaIsVisitor", entry.isVisitor)
                        table.insert(waiting, child)
                    end
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

    local elements = FindGameElements()
    local isVisitor = model:GetAttribute("SecretariaIsVisitor") == true

    if elements.CheckIn then
        WaitAndFire(elements.CheckIn, 3)
    end
    task.wait(0.4)

    if elements.FormStation then
        WaitAndFire(elements.FormStation, 3)
    end
    task.wait(0.4)

    UI:Flash(0.15, Color3.fromRGB(255, 255, 255))
    if elements.Camera then
        WaitAndFire(elements.Camera, 3)
    end
    task.wait(0.4)

    if elements.Computer then
        WaitAndFire(elements.Computer, 3)
    else
        warn("[Secretaria] Computer nao encontrado em Misc.CheckIn - registro pulado.")
    end
    task.wait(0.6)

    if elements.Printer then
        WaitAndFire(elements.Printer, 3)
    else
        warn("[Secretaria] Printer nao encontrado em Misc.CheckIn - impressao pulada.")
    end

    local badgeBase = isVisitor and elements.VisitorBadge or elements.PatientBadge
    if badgeBase then
        WaitAndFire(badgeBase, SecretariaModule.Settings.FichaPickupTimeout)
    else
        warn("[Secretaria] Badge base nao encontrado em Misc.CheckIn - entrega pulada.")
    end

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

    HighlightSystem:StartLiveScan()

    task.spawn(function()
        SecretariaModule:Loop()
    end)

    if SecretariaModule.Settings.ShowNotifications then
        UI:Notify("Secretaria Ativada", "Atendimento automatico iniciado.", 3, "success")
    end
end

function SecretariaModule:Stop()
    SecretariaModule.State.Enabled = false

    HighlightSystem:StopLiveScan()

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

local function LoadCustomAudio(url, filename)
    if typeof(writefile) ~= "function" or typeof(getcustomasset) ~= "function" then
        warn("[Secretaria] Executor sem suporte a writefile/getcustomasset - audio do menu nao sera carregado.")
        return nil
    end

    local ok, result = pcall(function()
        local data = game:HttpGet(url)
        writefile(filename, data)
        return getcustomasset(filename)
    end)

    if ok then return result end
    warn("[Secretaria] Falha ao carregar audio do menu: " .. tostring(result))
    return nil
end

local function PlayMenuAudio()
    local soundId = LoadCustomAudio("https://files.catbox.moe/llgli8.mp3", "receptionist_menu_audio.mp3")
    if not soundId then return end

    local sound = Instance.new("Sound")
    sound.Name = "MenuOpenSound"
    sound.SoundId = soundId
    sound.Volume = 1
    sound.Parent = PlayerGui

    sound:Play()
    sound.Ended:Connect(function()
        sound:Destroy()
    end)
end

local Window = WindUI:CreateWindow({
    Title = "Receptionist Script V3",
    Icon = "https://files.catbox.moe/4guca7.jpg",
    Folder = "ReceptionistScriptV3",
    Theme = "Dark"
})

PlayMenuAudio()

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

local VisualTab = Window:Tab({ Title = "Visual", Icon = "eye" })

VisualTab:Section({ Title = "Highlights" })

VisualTab:Paragraph({
    Title = "Como funciona",
    Desc = "Enquanto a Secretaria estiver ativa, pacientes e visitantes ficam marcados em verde e anomalias em vermelho. Desative aqui se quiser jogar sem os contornos."
})

VisualTab:Toggle({
    Title = "Ativar Highlights",
    Value = true,
    Callback = function(state)
        HighlightSystem:SetEnabled(state)
    end
})

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
