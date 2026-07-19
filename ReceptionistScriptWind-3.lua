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

    -- Nota: o jogo (Animal Hospital) esconde os "anomalies" disfarcados de
    -- pacientes normais de propósito - nao existe um jeito confiavel de
    -- detectar isso via script (precisa checar camera/foto na mao). Por isso
    -- so destacamos quem esta na fila, sem tentar adivinhar quem e anomalia.
    if elements.NPCs then
        for _, child in ipairs(elements.NPCs:GetChildren()) do
            if (child:IsA("Model") or child:IsA("Folder")) and child:FindFirstChild("Humanoid") then
                local id = child:GetFullName()
                seen[id] = true
                if not HighlightSystem.ActiveHighlights[id] then
                    HighlightSystem:HighlightPaciente(child)
                end
            end
        end
    end

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
            else
                if next(HighlightSystem.ActiveHighlights) then
                    HighlightSystem:ClearAll()
                end
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

HighlightSystem:StartLiveScan()

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
        NPCs = nil -- fila REAL de pacientes/visitantes aguardando atendimento
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
        end

        if not elements.Computer then
            elements.Computer = misc:FindFirstChild("Computer")
        end
        if not elements.Printer then
            elements.Printer = misc:FindFirstChild("Printer")
        end
    end

    -- FormStation e opcional/experimental: nao foi confirmado como parte do
    -- balcao de Check-In (fica em ReplicatedStorage.Misc.Form, separado).
    -- So e usado se SecretariaModule.Settings.UseFormStation estiver ativo.
    if ReplicatedStorage:FindFirstChild("Misc") then
        elements.FormStation = ReplicatedStorage.Misc:FindFirstChild("Form")
    end

    -- IMPORTANTE (causa do bug de "repetir atendimento"):
    -- ReplicatedStorage.NPCs.Visitors e ReplicatedStorage.NPCs.Anomalies sao
    -- apenas os MODELOS-MOLDE (templates) que o jogo usa pra clonar os NPCs.
    -- Eles nunca saem dali, entao usa-los como "fila de espera" fazia o script
    -- achar o mesmo "paciente fantasma" pra sempre e reprocessar em loop.
    -- A fila real (pacientes/visitantes de fato no mundo, na janela) fica em
    -- Workspace.NPCs - e a UNICA fonte usada agora.
    if Workspace:FindFirstChild("NPCs") then
        elements.NPCs = Workspace.NPCs
    end

    return elements
end

local SecretariaModule = {
    State = {
        Enabled = false,
        Running = false,
        CurrentPatient = nil,
        InProgress = {} -- trava por modelo, evita processar o mesmo 2x ao mesmo tempo
    },
    Settings = {
        LoopDelay = 1.5,
        ShowNotifications = true,
        FichaPickupTimeout = 8,
        UseFormStation = true,
        DefaultBadgeType = "Patient" -- "Patient" ou "Visitor", usado quando nao ha como saber o tipo do NPC
    },
    Stats = {
        processed = 0
    }
}

-- Nota importante sobre "anomalias":
-- O Animal Hospital foi feito de propósito pra anomalia se disfarçar de
-- paciente normal (Skinwalker etc.) - a deteccao real e visual (janela, foto
-- da Polaroid e camera de CCTV), nao existe uma flag/pasta no jogo que diga
-- "isso aqui e uma anomalia" acessivel por script. Por isso este script NAO
-- tenta mais "pular anomalias" automaticamente (a versao antiga achava que
-- fazia isso, mas estava lendo os MODELOS-MOLDE do jogo, nao pacientes reais,
-- entao nunca funcionou de verdade). Ele atende todo mundo que aparece na
-- fila. Se quiser rejeitar anomalias, isso ainda precisa ser feito na mao.

local ProcessedRegistry = {} -- [model] = true enquanto o NPC ainda esta na fila

local function MarkProcessed(model)
    if ProcessedRegistry[model] then return end
    ProcessedRegistry[model] = true

    local conn
    conn = model.AncestryChanged:Connect(function(_, parent)
        if not parent then
            ProcessedRegistry[model] = nil
            if conn then conn:Disconnect() end
        end
    end)

    -- trava de seguranca: se o NPC nunca sumir do jogo por algum motivo,
    -- libera o registro depois de um tempo generoso pra nao vazar memoria
    task.delay(180, function()
        ProcessedRegistry[model] = nil
        if conn then conn:Disconnect() end
    end)
end

local function IsMarkedProcessed(model)
    return ProcessedRegistry[model] == true
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
        local ok = pcall(fireproximityprompt, prompt, prompt.HoldDuration)
        if ok and prompt.HoldDuration and prompt.HoldDuration > 0 then
            task.wait(prompt.HoldDuration + 0.1)
        end
        return ok
    end
    return false
end

local function GetAnchorPart(target)
    if not target then return nil end
    if target:IsA("BasePart") then return target end

    local prompt = target:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt and prompt.Parent and prompt.Parent:IsA("BasePart") then
        return prompt.Parent
    end

    return (target:IsA("Model") and target.PrimaryPart) or target:FindFirstChildWhichIsA("BasePart", true)
end

local function TeleportCharacterTo(part, offset)
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or not part then return nil end

    local original = root.CFrame
    root.CFrame = CFrame.new(part.Position + (offset or Vector3.new(0, 3, 0)))
    return original
end

-- Da TP em cima do objeto e dispara o ProximityPrompt dele.
local function TeleportAndFire(target, timeout)
    if not target then return false end

    local anchor = GetAnchorPart(target)
    if anchor then
        TeleportCharacterTo(anchor)
        task.wait(0.2)
    end

    return WaitAndFire(target, timeout)
end

local function GetWaitingPatients()
    local waiting = {}
    local elements = FindGameElements()

    if elements.NPCs then
        for _, child in ipairs(elements.NPCs:GetChildren()) do
            if (child:IsA("Model") or child:IsA("Folder")) and child:FindFirstChild("Humanoid") then
                if not IsMarkedProcessed(child) and not SecretariaModule.State.InProgress[child] then
                    table.insert(waiting, child)
                end
            end
        end
    end

    return waiting
end

local function GetBadgeBase(elements, model)
    -- Se algum dia o jogo/outro script marcar o tipo via atributo, respeita ele.
    local explicitType = model:GetAttribute("SecretariaBadgeType")
    local badgeType = explicitType or SecretariaModule.Settings.DefaultBadgeType

    if badgeType == "Visitor" and elements.VisitorBadge then
        return elements.VisitorBadge
    end

    return elements.PatientBadge or elements.VisitorBadge
end

local function DeliverFicha(model, badgeBase)
    if not badgeBase then
        warn("[Secretaria] Badge base nao encontrado em Misc.CheckIn - entrega pulada.")
        return
    end

    -- TP em cima da ficha e pega ela
    local grabbed = TeleportAndFire(badgeBase, SecretariaModule.Settings.FichaPickupTimeout)
    if not grabbed then
        warn("[Secretaria] Nao consegui pegar a ficha (" .. badgeBase:GetFullName() .. ").")
        return
    end

    task.wait(0.4)

    -- TP em cima do paciente pra entregar
    local targetPart = GetAnchorPart(model)
        or (model:IsA("Model") and model.PrimaryPart)
        or model:FindFirstChild("HumanoidRootPart", true)

    if targetPart then
        TeleportCharacterTo(targetPart, Vector3.new(0, 0, 2))
        task.wait(0.2)
    end

    local deliverPrompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
    if deliverPrompt then
        WaitAndFire(model, 3)
        return
    end

    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if root and targetPart and typeof(firetouchinterest) == "function" then
        local originalCFrame = root.CFrame
        root.CFrame = targetPart.CFrame + Vector3.new(0, 0, 2)

        task.wait(0.15)
        pcall(firetouchinterest, root, targetPart, 0)
        task.wait(0.15)
        pcall(firetouchinterest, root, targetPart, 1)
        task.wait(0.2)

        root.CFrame = originalCFrame
    else
        warn("[Secretaria] Nao encontrei um jeito de entregar a ficha em " .. model:GetFullName() .. " - peguei a ficha mas nao entreguei.")
    end
end

local function ProcessPatient(model)
    if SecretariaModule.State.InProgress[model] or IsMarkedProcessed(model) then
        return
    end

    SecretariaModule.State.InProgress[model] = true
    SecretariaModule.State.CurrentPatient = model

    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local originalCFrame = root and root.CFrame

    local ok, err = pcall(function()
        local elements = FindGameElements()

        -- Sequencia pedida: formulario -> camera (foto) -> computador (registro)
        -- -> impressora -> ficha (pega) -> paciente (entrega). Da TP em cima de
        -- cada objeto antes de disparar o ProximityPrompt dele.

        if SecretariaModule.Settings.UseFormStation and elements.FormStation then
            TeleportAndFire(elements.FormStation, 3)
            task.wait(0.3)
        end

        UI:Flash(0.15, Color3.fromRGB(255, 255, 255))

        if elements.Camera then
            TeleportAndFire(elements.Camera, 3)
        end
        task.wait(0.4)

        if elements.Computer then
            TeleportAndFire(elements.Computer, 3)
        else
            warn("[Secretaria] Computer nao encontrado em Misc.CheckIn - registro pulado.")
        end
        task.wait(0.6)

        if elements.Printer then
            TeleportAndFire(elements.Printer, 3)
        else
            warn("[Secretaria] Printer nao encontrado em Misc.CheckIn - impressao pulada.")
        end
        task.wait(0.4)

        local badgeBase = GetBadgeBase(elements, model)
        DeliverFicha(model, badgeBase)
    end)

    if not ok then
        warn("[Secretaria] Erro ao processar " .. model:GetFullName() .. ": " .. tostring(err))
    end

    if root and originalCFrame then
        root.CFrame = originalCFrame
    end

    MarkProcessed(model)
    SecretariaModule.Stats.processed += 1
    SecretariaModule.State.CurrentPatient = nil
    SecretariaModule.State.InProgress[model] = nil

    if ok and SecretariaModule.Settings.ShowNotifications then
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
        processed = SecretariaModule.Stats.processed
    }
end

local function DownloadBinary(url)
    local requestFn = (typeof(request) == "function" and request)
        or (typeof(http_request) == "function" and http_request)
        or (syn and typeof(syn.request) == "function" and syn.request)

    if requestFn then
        local ok, response = pcall(requestFn, { Url = url, Method = "GET" })
        if ok and response and response.Body then
            return response.Body
        end
    end

    local ok, data = pcall(game.HttpGet, game, url)
    if ok then return data end
    return nil
end

local function LoadCustomAudio(url, filename)
    if typeof(writefile) ~= "function" or typeof(getcustomasset) ~= "function" then
        warn("[Secretaria] Executor sem suporte a writefile/getcustomasset - audio do menu nao sera carregado.")
        return nil
    end

    local ok, result = pcall(function()
        local data = DownloadBinary(url)
        if not data then
            error("download falhou")
        end
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

local AntiAFK = {
    Enabled = false,
    _idleConn = nil
}

function AntiAFK:Enable()
    if AntiAFK.Enabled then return end
    AntiAFK.Enabled = true

    local ok, VirtualUser = pcall(function()
        return game:GetService("VirtualUser")
    end)

    if not ok or not VirtualUser then
        warn("[AntiAFK] VirtualUser indisponivel neste executor.")
        AntiAFK.Enabled = false
        return
    end

    AntiAFK._idleConn = LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)
end

function AntiAFK:Disable()
    AntiAFK.Enabled = false
    if AntiAFK._idleConn then
        AntiAFK._idleConn:Disconnect()
        AntiAFK._idleConn = nil
    end
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

SecretariaTab:Toggle({
    Title = "Notificacoes de Atendimento",
    Value = true,
    Callback = function(state)
        SecretariaModule.Settings.ShowNotifications = state
    end
})

SecretariaTab:Dropdown({
    Title = "Tipo de Ficha Padrao",
    Values = { "Patient", "Visitor" },
    Value = "Patient",
    Callback = function(value)
        SecretariaModule.Settings.DefaultBadgeType = value
    end
})

SecretariaTab:Slider({
    Title = "Delay Entre Atendimentos (s)",
    Step = 0.1,
    Value = { Min = 0.5, Max = 5, Default = 1.5 },
    Callback = function(value)
        SecretariaModule.Settings.LoopDelay = value
    end
})

SecretariaTab:Paragraph({
    Title = "Sobre deteccao de anomalia",
    Desc = "O jogo esconde as anomalias disfarcadas de paciente normal de proposito (precisa checar janela/foto/CCTV na mao). Este script NAO consegue identificar isso automaticamente, entao ele atende todo mundo que aparece na fila."
})

local PrincipalTab = Window:Tab({ Title = "Principal", Icon = "clipboard-list" })
PrincipalTab:Paragraph({ Title = "Principal", Desc = "Em desenvolvimento." })

local UtilidadesTab = Window:Tab({ Title = "Utilidades", Icon = "wrench" })
UtilidadesTab:Paragraph({ Title = "Utilidades", Desc = "Em desenvolvimento." })

local PlayerTab = Window:Tab({ Title = "Player", Icon = "user" })
PlayerTab:Paragraph({ Title = "Player", Desc = "Em desenvolvimento." })

local VisualTab = Window:Tab({ Title = "Visual", Icon = "eye" })

VisualTab:Section({ Title = "Highlights" })

VisualTab:Toggle({
    Title = "Ativar Highlights",
    Value = true,
    Callback = function(state)
        HighlightSystem:SetEnabled(state)
    end
})

local MiscTab = Window:Tab({ Title = "Misc", Icon = "layers" })

MiscTab:Section({ Title = "Anti-AFK" })
MiscTab:Toggle({
    Title = "Ativar Anti-AFK",
    Value = false,
    Callback = function(state)
        if state then
            AntiAFK:Enable()
        else
            AntiAFK:Disable()
        end
    end
})
MiscTab:Paragraph({
    Title = "Anti-AFK",
    Desc = "Evita ser desconectado por inatividade, pra secretaria continuar atendendo mesmo com voce parado/afk."
})

local WHATSAPP_LINK = "https://chat.whatsapp.com/COLOQUE_SEU_LINK_AQUI"
local DISCORD_LINK = "https://discord.gg/COLOQUE_SEU_LINK_AQUI"

local SobreTab = Window:Tab({ Title = "Sobre", Icon = "info" })
SobreTab:Paragraph({
    Title = "Receptionist Script V3",
    Desc = "Criado por FelzpSystem\nBiblioteca: WindUI\nModulo ativo: Secretaria (automacao de atendimento)"
})

SobreTab:Paragraph({
    Title = "Comunidade",
    Desc = "Entre nos nossos grupos para acompanhar atualizacoes, tirar duvidas e sugerir melhorias.",
    Buttons = {
        {
            Title = "Copiar link do WhatsApp",
            Icon = "message-circle",
            Variant = "Primary",
            Callback = function()
                if typeof(setclipboard) == "function" then
                    setclipboard(WHATSAPP_LINK)
                    UI:Notify("WhatsApp", "Link copiado! Cole no navegador.", 3, "success")
                else
                    UI:Notify("WhatsApp", WHATSAPP_LINK, 5, "info")
                end
            end
        },
        {
            Title = "Copiar link do Discord",
            Icon = "message-square",
            Variant = "Primary",
            Callback = function()
                if typeof(setclipboard) == "function" then
                    setclipboard(DISCORD_LINK)
                    UI:Notify("Discord", "Link copiado! Cole no navegador.", 3, "success")
                else
                    UI:Notify("Discord", DISCORD_LINK, 5, "info")
                end
            end
        }
    }
})

_G.ReceptionistScript = {
    Principal = PrincipalModule,
    Utilidades = UtilidadesModule,
    Player = PlayerModule,
    Misc = MiscModule,
    Sobre = SobreModule,
    Highlights = HighlightSystem,
    Secretaria = SecretariaModule,
    AntiAFK = AntiAFK,

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
