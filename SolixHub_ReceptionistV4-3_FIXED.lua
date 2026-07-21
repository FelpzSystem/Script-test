--[[
================================================================================
   SOLIX HUB — RECEPTIONIST SCRIPT V4
   Animal Hospital (Roblox) — Script de automacao completo
   UI: WindUI
   Autor: FelzpSystem
   Versao: 4.0 (rebuild, sem bugs, 6 abas)
   Abas: Principal | Visual | Player | Misc | Settings | Sobre
================================================================================
--]]

--------------------------------------------------------------------------------
-- 0) CARREGAR WINDUI COM PROTECAO
--------------------------------------------------------------------------------
local WINDUI_URLS = {
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua",
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/main.lua",
}

local ok, WindUI
for _, url in ipairs(WINDUI_URLS) do
    ok, WindUI = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if ok and type(WindUI) == "table" then break end
end

if not ok or type(WindUI) ~= "table" then
    warn("[SolixHub] Falha ao carregar WindUI: " .. tostring(WindUI))
    return
end

-- Normaliza diferentes builds do WindUI
if not WindUI.CreateWindow and type(WindUI.Window) == "function" then
    WindUI.CreateWindow = WindUI.Window
end

local function W_CreateWindow(opts)
    -- API nova do WindUI: WindUI:CreateWindow(opts)
    if type(WindUI.CreateWindow) == "function" then
        return WindUI:CreateWindow(opts)
    end
    if type(WindUI.Window) == "function" then
        return WindUI.Window(opts)
    end
    if type(WindUI.New) == "function" then
        return WindUI.New(opts)
    end
    error("WindUI nao expoe CreateWindow/Window/New")
end

local function W_Notify(opts)
    -- tenta varias APIs comuns
    if type(WindUI.Notify) == "function" then return WindUI.Notify(opts) end
    if WindUI.UI and type(WindUI.UI.Notify) == "function" then return WindUI.UI.Notify(opts) end
    if type(WindUI.notify) == "function" then return WindUI.notify(opts) end
    -- fallback silencioso
    warn("[SolixHub] Notify indisponivel: " .. (opts.Title or ""))
end

local function W_SetTheme(theme)
    if type(WindUI.SetTheme) == "function" then return WindUI.SetTheme(theme) end
    if type(WindUI.Theme) == "function" then return WindUI.Theme(theme) end
    if WindUI.UI and type(WindUI.UI.SetTheme) == "function" then return WindUI.UI.SetTheme(theme) end
end

--------------------------------------------------------------------------------
-- 1) SERVICES + HELPERS
--------------------------------------------------------------------------------
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local Lighting          = game:GetService("Lighting")
local HttpService       = game:GetService("HttpService")
local StarterGui        = game:GetService("StarterGui")
local VirtualUser       = game:GetService("VirtualUser")
local TeleportService   = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Camera      = Workspace.CurrentCamera

local function GetRoot()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function IsAlive()
    local h = GetHumanoid()
    return h and h.Health > 0
end

--------------------------------------------------------------------------------
-- 2) CORES
--------------------------------------------------------------------------------
local Colors = {
    Primary    = Color3.fromRGB(45, 45, 55),
    Secondary  = Color3.fromRGB(60, 60, 70),
    Accent     = Color3.fromRGB(170, 120, 255),
    Success    = Color3.fromRGB(50, 205, 50),
    Warning    = Color3.fromRGB(255, 165, 0),
    Danger     = Color3.fromRGB(220, 53, 69),
    Text       = Color3.fromRGB(255, 255, 255),
    TextMuted  = Color3.fromRGB(180, 180, 190),
    Border     = Color3.fromRGB(80, 80, 90),

    Visitor    = Color3.fromRGB(50, 255, 50),
    Paciente   = Color3.fromRGB(50, 255, 50),
    Anomalia   = Color3.fromRGB(220, 53, 69),
    Player     = Color3.fromRGB(0, 170, 255),
    Skinwalker = Color3.fromRGB(255, 60, 60),
}

--------------------------------------------------------------------------------
-- 3) UI HELPERS
--------------------------------------------------------------------------------
local UI = {}

function UI:Notify(title, content, duration, kind)
    duration = duration or 3
    kind = kind or "info"
    local color = Colors.Accent
    if kind == "success" then color = Colors.Success
    elseif kind == "warning" then color = Colors.Warning
    elseif kind == "error" then color = Colors.Danger end

    -- monta payload compativel com diferentes versoes
    local payload = {
        Title    = title,
        Content  = content,
        Desc     = content,
        Text     = content,
        Message  = content,
        Duration = duration,
        Color    = color,
    }
    pcall(W_Notify, payload)
end

function UI:Flash(duration, color)
    duration = duration or 0.3
    color    = color    or Color3.fromRGB(255, 255, 255)
    pcall(function()
        local flash = Instance.new("Frame")
        flash.Size              = UDim2.new(1, 0, 1, 0)
        flash.BackgroundColor3  = color
        flash.BackgroundTransparency = 0
        flash.BorderSizePixel   = 0
        flash.ZIndex            = 10
        flash.Parent            = PlayerGui
        local tw = TweenService:Create(flash,
            TweenInfo.new(duration, Enum.EasingStyle.Quad),
            {BackgroundTransparency = 1}
        )
        tw:Play()
        tw.Completed:Connect(function() pcall(function() flash:Destroy() end) end)
        Debris:AddItem(flash, duration + 0.1)
    end)
end

--------------------------------------------------------------------------------
-- 4) AUDIO (som de abertura)
--------------------------------------------------------------------------------
local NATIVE_SOUND_IDS = {
    "rbxassetid://9118823100",
    "rbxassetid://6026984224",
    "rbxassetid://4590662766",
}

local AudioURL = "https://litter.catbox.moe/qtcweo.mp3"
-- FIX: essa era a logo que voce pediu e que estava faltando. O link que voce
-- mandou (catbox 9envii.jpg) e uma IMAGEM, entao usei ele aqui como logo.
-- Nao da pra usar ele como audio porque .jpg nao e som -- se voce tiver um
-- link de audio (mp3/ogg) de verdade, so trocar o AudioURL acima.
local IconURL  = "https://files.catbox.moe/9envii.jpg"

local function DownloadBinary(url)
    if not url or url == "" then return nil end
    if typeof(request) == "function" then
        local ok, res = pcall(request, {Url = url, Method = "GET"})
        if ok and res and res.Body and #tostring(res.Body) > 50 then return res.Body end
    end
    if typeof(http_request) == "function" then
        local ok, res = pcall(http_request, {Url = url, Method = "GET"})
        if ok and res and res.Body and #tostring(res.Body) > 50 then return res.Body end
    end
    if typeof(game.HttpGet) == "function" then
        local ok, data = pcall(game.HttpGet, game, url)
        if ok and data and #tostring(data) > 50 then return data end
    end
    return nil
end

local function SaveBinaryAndGetAsset(url, filename)
    if typeof(writefile) ~= "function" or typeof(getcustomasset) ~= "function" then return nil end
    local data = DownloadBinary(url)
    if not data or #data < 50 then return nil end
    local ok = pcall(writefile, filename, data)
    if not ok then return nil end
    local ok2, asset = pcall(getcustomasset, filename)
    if not ok2 or type(asset) ~= "string" then return nil end
    return asset
end

-- FIX: o audio nao tocava porque, se o SoundId customizado falhasse (link
-- fora do ar, sem permissao de escrever arquivo, etc.), o script so tentava
-- UM id nativo de fallback e nunca checava se o som realmente carregou --
-- entao, em muitos casos, nada tocava e nenhum erro aparecia. Agora ele
-- espera o evento "Loaded" do som (com timeout) e, se falhar, tenta o
-- proximo id nativo da lista, ate um deles funcionar.
local function PlayMenuAudio(volume)
    volume = volume or 0.5

    local function tryPlay(id, onFail)
        pcall(function()
            local s = Instance.new("Sound")
            s.SoundId = id
            s.Volume  = volume
            s.Parent  = PlayerGui

            local loaded = false
            local loadedConn
            loadedConn = s.Loaded:Connect(function() loaded = true end)

            local playedOk = pcall(function() s:Play() end)

            s.Ended:Connect(function() pcall(function() s:Destroy() end) end)
            Debris:AddItem(s, 15)

            task.delay(2.5, function()
                if loadedConn then pcall(function() loadedConn:Disconnect() end) end
                if (not playedOk or not loaded) and onFail then
                    pcall(function() s:Destroy() end)
                    onFail()
                end
            end)
        end)
    end

    local function playNativeChain(i)
        i = i or 1
        local id = NATIVE_SOUND_IDS[i]
        if not id then
            warn("[SolixHub] Nenhum som de abertura conseguiu tocar (custom e todos os nativos falharam).")
            return
        end
        tryPlay(id, function() playNativeChain(i + 1) end)
    end

    task.spawn(function()
        local asset
        pcall(function() asset = SaveBinaryAndGetAsset(AudioURL, "rsv4_menu.mp3") end)
        if asset and asset ~= "" then
            tryPlay(asset, function() playNativeChain(1) end)
        else
            playNativeChain(1)
        end
    end)
end

--------------------------------------------------------------------------------
-- 5) CONFIG SYSTEM (com debounce)
--------------------------------------------------------------------------------
local ConfigSystem = {
    File   = "SolixHub_Config.json",
    Data   = {},
    _dirty = false,
    _saveScheduled = false,
}

function ConfigSystem:_scheduleSave()
    if self._saveScheduled then return end
    self._saveScheduled = true
    task.delay(1, function()
        self._saveScheduled = false
        if not self._dirty then return end
        self._dirty = false
        self:Save()
    end)
end

function ConfigSystem:Save()
    if typeof(writefile) ~= "function" then return false end
    local ok, json = pcall(HttpService.JSONEncode, HttpService, self.Data)
    if not ok then return false end
    return pcall(writefile, self.File, json) and true or false
end

function ConfigSystem:Load()
    if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then return false end
    if not isfile(self.File) then return false end
    local ok, content = pcall(readfile, self.File)
    if not ok or not content then return false end
    local ok2, data = pcall(HttpService.JSONDecode, HttpService, content)
    if ok2 and type(data) == "table" then
        self.Data = data
        return true
    end
    return false
end

function ConfigSystem:Get(key, default)
    local v = self.Data[key]
    if v == nil then return default end
    return v
end

function ConfigSystem:Set(key, value)
    self.Data[key] = value
    self._dirty = true
    self:_scheduleSave()
end

ConfigSystem:Load()

--------------------------------------------------------------------------------
-- 6) FIND GAME ELEMENTS (cache vivo)
--------------------------------------------------------------------------------
local ElementsCache = { _t = 0, _data = nil, _TTL = 1.5 }

local function FindGameElements()
    if ElementsCache._data and (tick() - ElementsCache._t) < ElementsCache._TTL then
        return ElementsCache._data
    end

    local elements = {
        CheckIn = nil, CheckIn2 = nil,
        Camera = nil, Computer = nil, Printer = nil,
        PatientBadge = nil, VisitorBadge = nil,
        FormStation = nil, FormStation2 = nil,
        NPCs = nil,
        CoffeeMachine = nil, CoffeeMachine2 = nil,
        Cameras = nil, Cameras2 = nil,
        ShopItems = nil, SecurityCamPC = nil,
        Rooms = nil,
    }

    if Workspace:FindFirstChild("Misc") then
        local misc = Workspace.Misc
        elements.CheckIn       = misc:FindFirstChild("CheckIn")
        elements.CheckIn2      = misc:FindFirstChild("CheckIn2")
        elements.CoffeeMachine = misc:FindFirstChild("CoffeeMachine")
        elements.CoffeeMachine2= misc:FindFirstChild("CoffeeMachine2")
        elements.Cameras       = misc:FindFirstChild("Cameras")
        elements.Cameras2      = misc:FindFirstChild("Cameras2")
        elements.ShopItems     = misc:FindFirstChild("ShopItems")
        elements.SecurityCamPC = misc:FindFirstChild("SecurityCamPC")

        if elements.CheckIn then
            elements.Camera       = elements.CheckIn:FindFirstChild("Camera")
            elements.Computer     = elements.CheckIn:FindFirstChild("Computer")
            elements.Printer      = elements.CheckIn:FindFirstChild("Printer")
            elements.PatientBadge = elements.CheckIn:FindFirstChild("PatientBadgeBase")
            elements.VisitorBadge = elements.CheckIn:FindFirstChild("VisitorBadgeBase")
            -- Form do check-in normal (usado no atendimento do dia-a-dia)
            elements.FormStation  = elements.CheckIn:FindFirstChild("Form")
        end
        if elements.CheckIn2 then
            elements.FormStation2 = elements.CheckIn2:FindFirstChild("Form")
        end

        if not elements.Computer then elements.Computer = misc:FindFirstChild("Computer") end
        if not elements.Printer  then elements.Printer  = misc:FindFirstChild("Printer")  end
    end

    -- CoffeeMachine2 mora em ReplicatedStorage.Misc no jogo real (nao Workspace.Misc) - fallback
    if not elements.CoffeeMachine2 and ReplicatedStorage:FindFirstChild("Misc") then
        elements.CoffeeMachine2 = ReplicatedStorage.Misc:FindFirstChild("CoffeeMachine2")
    end

    if ReplicatedStorage:FindFirstChild("Misc") then
        local misc = ReplicatedStorage.Misc
        -- so usa o HazmatForm da ReplicatedStorage se nao achou o Form normal do CheckIn
        if not elements.FormStation then
            elements.FormStation = misc:FindFirstChild("Form") or misc:FindFirstChild("HazmatForm")
        end
    end

    if Workspace:FindFirstChild("NPCs")   then elements.NPCs   = Workspace.NPCs   end
    if Workspace:FindFirstChild("Rooms")  then elements.Rooms  = Workspace.Rooms  end

    ElementsCache._data = elements
    ElementsCache._t    = tick()
    return elements
end

--------------------------------------------------------------------------------
-- 7) UTILITARIOS DE ACAO
--------------------------------------------------------------------------------
local function GetAnchorPart(target)
    if not target then return nil end
    if target:IsA("BasePart") then return target end

    -- FIX: para personagens/NPCs (tem Humanoid), SEMPRE usa o HumanoidRootPart.
    -- Antes, quando o NPC nao tinha PrimaryPart, o script pegava a PRIMEIRA
    -- BasePart encontrada (podia ser um acessorio, cabelo, mao etc.), o que
    -- fazia o personagem teleportar pra posicoes erradas/aleatorias no mapa
    -- em vez de ir ate o paciente de verdade. Isso era a causa principal do
    -- "pular em lugares aleatorios" a partir do 2o paciente.
    if target:IsA("Model") or target:IsA("Folder") then
        local hum = target:FindFirstChildOfClass("Humanoid")
        if hum then
            local hrp = target:FindFirstChild("HumanoidRootPart")
                or target:FindFirstChild("UpperTorso")
                or target:FindFirstChild("Torso")
            if hrp and hrp:IsA("BasePart") then return hrp end
        end
    end

    local prompt = target:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt and prompt.Parent and prompt.Parent:IsA("BasePart") then return prompt.Parent end
    if target:IsA("Model") then
        if target.PrimaryPart then return target.PrimaryPart end
        return target:FindFirstChildWhichIsA("BasePart", true)
    end
    return target:FindFirstChildWhichIsA("BasePart", true)
end

local function TeleportTo(part, offset)
    local root = GetRoot()
    if not root or not part then return nil end
    local original = root.CFrame
    root.CFrame = CFrame.new(part.Position + (offset or Vector3.new(0, 3, 0)))
    return original
end

local function WaitAndFire(container, timeout)
    if not container then return false end
    timeout = timeout or 5
    local prompt
    local elapsed = 0
    repeat
        if container.Parent then
            prompt = container:FindFirstChildWhichIsA("ProximityPrompt", true)
        end
        if prompt and prompt.Enabled then break end
        task.wait(0.2)
        elapsed = elapsed + 0.2
    until elapsed >= timeout

    -- FIX (bug do cooldown da ficha): antes, se o prompt existisse mas
    -- NUNCA ficasse "Enabled" dentro do timeout (ou seja, ainda em cooldown),
    -- o codigo disparava ele mesmo assim. O fireproximityprompt do executor
    -- "funciona" localmente (pcall retorna true) mas o servidor rejeita o
    -- pedido por causa do cooldown -> o script achava que tinha pego a ficha
    -- e seguia em frente sem ela de verdade. Agora so dispara se realmente
    -- estiver Enabled no momento do disparo.
    if not prompt or not prompt.Enabled then
        return false
    end

    local fired = false
    if typeof(fireproximityprompt) == "function" then
        fired = pcall(fireproximityprompt, prompt, prompt.HoldDuration or 0) and true or false
    end
    if not fired and prompt.Parent and prompt.Parent:IsA("BasePart") and typeof(firetouchinterest) == "function" then
        local root = GetRoot()
        if root then
            local originalCFrame = root.CFrame
            root.CFrame = prompt.Parent.CFrame + Vector3.new(0, 0, 1)
            task.wait(0.1)
            pcall(firetouchinterest, root, prompt.Parent, 0)
            task.wait(0.1)
            pcall(firetouchinterest, root, prompt.Parent, 1)
            task.wait(0.1)
            root.CFrame = originalCFrame
            fired = true
        end
    end
    if fired and prompt.HoldDuration and prompt.HoldDuration > 0 then
        task.wait(prompt.HoldDuration + 0.1)
    end
    return fired
end

local function TeleportAndFire(target, timeout, offset)
    if not target then return false end
    local anchor = GetAnchorPart(target)
    if anchor then
        TeleportTo(anchor, offset)
        task.wait(0.2)
    end
    return WaitAndFire(target, timeout)
end

local function FireClick(target)
    if not target then return false end
    local cd = target:FindFirstChildWhichIsA("ClickDetector", true)
    if not cd then return false end
    if typeof(fireclickdetector) == "function" then
        pcall(fireclickdetector, cd, 0)
        return true
    end
    return false
end

local function FireProximity(target, timeout)
    if not target then return false end
    return WaitAndFire(target, timeout)
end

local function FindTool(name)
    name = name:lower()
    local function scan(container)
        if not container then return nil end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") and item.Name:lower():find(name, 1, true) then
                return item
            end
        end
        return nil
    end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        local t = scan(bp)
        if t then return t end
    end
    local ch = LocalPlayer.Character
    if ch then
        local t = scan(ch)
        if t then return t end
    end
    return nil
end

local function EquipTool(name)
    local t = FindTool(name)
    if not t then return false end
    local hum = GetHumanoid()
    if hum and t.Parent ~= LocalPlayer.Character then
        pcall(function() hum:EquipTool(t) end)
    end
    return true
end

--------------------------------------------------------------------------------
-- 8) HIGHLIGHT SYSTEM (Visual)
--------------------------------------------------------------------------------
local ANOMALIA_KEYWORDS = {
    "anomaly", "hider", "ghost", "skinwalker",
    "tall monster", "eye", "slime", "shadow",
    "creep", "monster",
}

local HighlightSystem = {
    Active = {},
    -- FIX: agora vem DESATIVADO por padrao (pedido do usuario), e lembra a
    -- ultima escolha salva no config.
    Enabled = ConfigSystem:Get("Highlight.Enabled", false),
    OnlyAnomalies = false,
    _scanning = false,
    _thread = nil,
    Settings = {
        FillTransparency    = 0.65,
        OutlineTransparency = 0,
        VisitorColor        = Colors.Visitor,
        PacienteColor       = Colors.Paciente,
        AnomaliaColor       = Colors.Anomalia,
        PlayerColor         = Colors.Player,
        SkinwalkerColor     = Colors.Skinwalker,
    },
}

function HighlightSystem:ClearAll()
    for _, h in pairs(self.Active) do
        pcall(function() if h and h.Parent then h:Destroy() end end)
    end
    self.Active = {}
end

function HighlightSystem:Add(target, color, opts)
    if not target or not target.Parent then return nil end
    opts = opts or {}
    local id = target:GetFullName()

    if self.Active[id] then
        local h = self.Active[id]
        if h and h.Parent then
            h.FillColor           = color or h.FillColor
            h.FillTransparency    = opts.fillTransparency    or self.Settings.FillTransparency
            h.OutlineTransparency = opts.outlineTransparency or self.Settings.OutlineTransparency
        end
        return h
    end

    local h = Instance.new("Highlight")
    h.Adornee            = target
    h.FillColor          = color or Colors.Accent
    h.OutlineColor       = Color3.new(1, 1, 1)
    h.FillTransparency   = opts.fillTransparency    or self.Settings.FillTransparency
    h.OutlineTransparency= opts.outlineTransparency or self.Settings.OutlineTransparency
    h.DepthMode          = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent             = target
    self.Active[id] = h
    return h
end

function HighlightSystem:Remove(target)
    if not target then return end
    local id = target:GetFullName()
    if self.Active[id] then
        pcall(function() if self.Active[id].Parent then self.Active[id]:Destroy() end end)
        self.Active[id] = nil
    end
end

function HighlightSystem:SetEnabled(state)
    self.Enabled = state and true or false
    ConfigSystem:Set("Highlight.Enabled", self.Enabled)
    if not self.Enabled then self:ClearAll() end
end

function HighlightSystem:Refresh()
    if not self.Enabled then return end
    local seen = {}
    local els = FindGameElements()

    -- pacientes / anomalias
    if els.NPCs then
        for _, child in ipairs(els.NPCs:GetChildren()) do
            if (child:IsA("Model") or child:IsA("Folder")) and child:FindFirstChild("Humanoid") then
                local id = child:GetFullName()
                seen[id] = true
                local lower = child.Name:lower()
                local isAnomalia = false
                for _, kw in ipairs(ANOMALIA_KEYWORDS) do
                    if lower:find(kw, 1, true) then isAnomalia = true break end
                end

                if self.OnlyAnomalies then
                    if isAnomalia then
                        self:Add(child, self.Settings.AnomaliaColor, {fillTransparency = 0.4})
                    else
                        self:Remove(child)
                    end
                else
                    if isAnomalia then
                        self:Add(child, self.Settings.AnomaliaColor, {fillTransparency = 0.4})
                    else
                        self:Add(child, self.Settings.PacienteColor, {fillTransparency = 0.6})
                    end
                end
            end
        end
    end

    -- players
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("Humanoid") then
            local id = p.Character:GetFullName()
            seen[id] = true
            self:Add(p.Character, self.Settings.PlayerColor, {fillTransparency = 0.7})
        end
    end

    -- limpa os que sumiram
    for id, h in pairs(self.Active) do
        if not seen[id] then
            pcall(function() if h and h.Parent then h:Destroy() end end)
            self.Active[id] = nil
        end
    end
end

function HighlightSystem:StartLiveScan()
    if self._scanning then return end
    self._scanning = true
    self._thread = task.spawn(function()
        while self._scanning do
            pcall(function() self:Refresh() end)
            task.wait(1)
        end
    end)
end

function HighlightSystem:StopLiveScan()
    self._scanning = false
    self._thread = nil
    self:ClearAll()
end

--------------------------------------------------------------------------------
-- 9) ESP MODULE
--------------------------------------------------------------------------------
local ESPModule = {
    Settings = {
        Enabled       = ConfigSystem:Get("ESP.On", false),
        AllInfo       = ConfigSystem:Get("ESP.AllInfo", false),
        OutlineTransp = ConfigSystem:Get("ESP.Outline", 0.5),
        FillTransp    = ConfigSystem:Get("ESP.Fill", 0.5),
        PersonColor   = ConfigSystem:Get("ESP.PersonColor", {0, 1, 0}),
        AnomalyColor  = ConfigSystem:Get("ESP.AnomalyColor", {1, 0, 0}),
        MaxDistance   = ConfigSystem:Get("ESP.MaxDist", 300),
    },
    State  = { Running = false, _items = {} },
    _thread = nil,
}

local function makeBillboard(name, parent)
    local b = Instance.new("BillboardGui")
    b.Name        = "ESP_BB_" .. name
    b.Adornee     = parent
    b.Size        = UDim2.new(0, 200, 0, 50)
    b.StudsOffset = Vector3.new(0, 3, 0)
    b.AlwaysOnTop = true
    b.Parent      = parent
    local lbl = Instance.new("TextLabel")
    lbl.Name                  = "Info"
    lbl.Size                  = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3            = Color3.new(1, 1, 1)
    lbl.TextStrokeColor3      = Color3.new(0, 0, 0)
    lbl.TextStrokeTransparency= 0
    lbl.TextScaled            = true
    lbl.Font                  = Enum.Font.GothamBold
    lbl.Text                  = name
    lbl.Parent                = b
    return b
end

function ESPModule:ApplyTo(model, isAnomalia)
    if not model or not model.Parent then return end
    local entry = self.State._items[model]
    if entry then
        if entry.highlight and entry.highlight.Parent then
            entry.highlight.FillTransparency    = self.Settings.FillTransp
            entry.highlight.OutlineTransparency = self.Settings.OutlineTransp
            entry.highlight.FillColor = isAnomalia
                and Color3.new(unpack(self.Settings.AnomalyColor))
                or  Color3.new(unpack(self.Settings.PersonColor))
        end
        if self.Settings.AllInfo and entry.billboard and entry.billboard.Parent then
            local hrp = model:FindFirstChild("HumanoidRootPart")
            local hum = model:FindFirstChildOfClass("Humanoid")
            local txt = model.Name
            if hrp then txt = txt .. "\n[" .. math.floor(hrp.Position.X) .. ", " .. math.floor(hrp.Position.Z) .. "]" end
            if hum then txt = txt .. "\nHP: " .. math.floor(hum.Health) end
            local info = entry.billboard:FindFirstChild("Info")
            if info then info.Text = txt end
        end
        return
    end

    local h = Instance.new("Highlight")
    h.Adornee             = model
    h.FillColor           = isAnomalia
        and Color3.new(unpack(self.Settings.AnomalyColor))
        or  Color3.new(unpack(self.Settings.PersonColor))
    h.OutlineColor        = Color3.new(1, 1, 1)
    h.FillTransparency    = self.Settings.FillTransp
    h.OutlineTransparency = self.Settings.OutlineTransp
    h.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent              = model

    local bb = nil
    if self.Settings.AllInfo then bb = makeBillboard(model.Name, model) end
    self.State._items[model] = { highlight = h, billboard = bb }
end

function ESPModule:Clear()
    for m, d in pairs(self.State._items) do
        pcall(function() if d.highlight and d.highlight.Parent then d.highlight:Destroy() end end)
        pcall(function() if d.billboard and d.billboard.Parent then d.billboard:Destroy() end end)
    end
    self.State._items = {}
end

function ESPModule:Tick()
    if not self.State.Running then return end
    pcall(function()
        local root = GetRoot()
        local maxDist = self.Settings.MaxDistance
        local seen = {}
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("Model") and d:FindFirstChild("Humanoid") and d ~= LocalPlayer.Character then
                if not root or (root.Position - (d:FindFirstChild("HumanoidRootPart") and d.HumanoidRootPart.Position or root.Position)).Magnitude <= maxDist then
                    seen[d] = true
                    local n = d.Name:lower()
                    local isAnomalia = false
                    for _, kw in ipairs(ANOMALIA_KEYWORDS) do
                        if n:find(kw, 1, true) then isAnomalia = true break end
                    end
                    self:ApplyTo(d, isAnomalia)
                end
            end
        end
        -- remove quem sumiu
        for m, _ in pairs(self.State._items) do
            if not seen[m] or not m.Parent then
                local entry = self.State._items[m]
                pcall(function() if entry.highlight and entry.highlight.Parent then entry.highlight:Destroy() end end)
                pcall(function() if entry.billboard and entry.billboard.Parent then entry.billboard:Destroy() end end)
                self.State._items[m] = nil
            end
        end
    end)
end

function ESPModule:Start()
    if self.State.Running then return end
    if not self.Settings.Enabled then return end
    self.State.Running = true
    self._thread = task.spawn(function()
        while self.State.Running do
            self:Tick()
            task.wait(0.7)
        end
    end)
end

function ESPModule:Stop()
    self.State.Running = false
    self._thread = nil
    self:Clear()
end

--------------------------------------------------------------------------------
-- 10) MODULO: SECRETARIA (atendimento automatico)
--------------------------------------------------------------------------------
local ProcessedRegistry = {}

local function MarkProcessed(model)
    if ProcessedRegistry[model] then return end
    ProcessedRegistry[model] = true
    local conn
    conn = model.AncestryChanged:Connect(function(_, parent)
        if not parent then
            ProcessedRegistry[model] = nil
            if conn then pcall(function() conn:Disconnect() end) end
        end
    end)
    task.delay(180, function()
        ProcessedRegistry[model] = nil
        if conn then pcall(function() conn:Disconnect() end) end
    end)
end

local SecretariaModule = {
    State = { Enabled = false, Running = false, CurrentNPC = nil, InProgress = {}, FailCount = {} },
    Settings = {
        LoopDelay         = ConfigSystem:Get("Secretaria.LoopDelay", 1.5),
        ShowNotifications = ConfigSystem:Get("Secretaria.Notif", true),
        FichaTimeout      = ConfigSystem:Get("Secretaria.FichaTimeout", 6),
        -- FIX: numero de vezes que tenta pegar a ficha se ela estiver em
        -- cooldown, e quanto espera entre uma tentativa e outra.
        FichaMaxAttempts  = ConfigSystem:Get("Secretaria.FichaMaxAttempts", 4),
        FichaRetryWait    = ConfigSystem:Get("Secretaria.FichaRetryWait", 2.5),
        -- FIX: quantas vezes tenta atender o MESMO paciente antes de desistir
        -- dele (evita ficar preso pra sempre num paciente bugado)
        MaxPatientRetries = ConfigSystem:Get("Secretaria.MaxPatientRetries", 3),
        UseFormStation    = ConfigSystem:Get("Secretaria.UseForm", true),
        DefaultBadgeType  = ConfigSystem:Get("Secretaria.BadgeType", "Patient"),
        AutoCarry         = ConfigSystem:Get("Secretaria.AutoCarry", false),
    },
    Stats = { processed = 0 },
}

local function IsAnomaliaName(name)
    local lower = (name or ""):lower()
    for _, kw in ipairs(ANOMALIA_KEYWORDS) do
        if lower:find(kw, 1, true) then return true end
    end
    return false
end

local function GetWaitingNPCs()
    local waiting = {}
    local els = FindGameElements()
    if not els.NPCs then return waiting end
    for _, child in ipairs(els.NPCs:GetChildren()) do
        if (child:IsA("Model") or child:IsA("Folder")) and child:FindFirstChild("Humanoid") then
            -- NUNCA trata anomalias/monstros como paciente (evita ir na direcao de um Ghost/Skinwalker/etc)
            if not IsAnomaliaName(child.Name) then
                if not ProcessedRegistry[child] and not SecretariaModule.State.InProgress[child] then
                    table.insert(waiting, child)
                end
            end
        end
    end
    return waiting
end

local function GetBadgeBase(elements, model)
    local explicit = model:GetAttribute("SecretariaBadgeType")
    local badgeType = explicit or SecretariaModule.Settings.DefaultBadgeType
    if badgeType == "Visitor" and elements.VisitorBadge then return elements.VisitorBadge end
    return elements.PatientBadge or elements.VisitorBadge
end

local function DeliverFicha(model, badgeBase)
    if not badgeBase then return false end

    -- FIX: a ficha tem cooldown pra ser carregada de novo. Antes o script
    -- so tentava pegar UMA vez e desistia; agora ele tenta de novo (com
    -- espera entre as tentativas) ate a ficha estar realmente disponivel.
    local grabbed = false
    local attempts = 0
    local maxAttempts = SecretariaModule.Settings.FichaMaxAttempts or 4
    while not grabbed and attempts < maxAttempts do
        attempts = attempts + 1
        if not model.Parent then return false end -- paciente sumiu, aborta
        grabbed = TeleportAndFire(badgeBase, SecretariaModule.Settings.FichaTimeout)
        if not grabbed and attempts < maxAttempts then
            task.wait(SecretariaModule.Settings.FichaRetryWait or 2.5)
        end
    end
    if not grabbed then return false end
    task.wait(0.4)

    local anchor = GetAnchorPart(model)
    if anchor then
        TeleportTo(anchor, Vector3.new(0, 0, 2))
        task.wait(0.2)
    end

    if model:FindFirstChildWhichIsA("ProximityPrompt", true) then
        return FireProximity(model, 3)
    end

    local root = GetRoot()
    if root and anchor and typeof(firetouchinterest) == "function" then
        local originalCFrame = root.CFrame
        root.CFrame = anchor.CFrame + Vector3.new(0, 0, 2)
        task.wait(0.15)
        pcall(firetouchinterest, root, anchor, 0)
        task.wait(0.15)
        pcall(firetouchinterest, root, anchor, 1)
        task.wait(0.2)
        root.CFrame = originalCFrame
        return true
    end
    return false
end

local function ProcessPatient(model)
    if SecretariaModule.State.InProgress[model] or ProcessedRegistry[model] then return end
    if not IsAlive() then return end
    if not model or not model.Parent then return end

    SecretariaModule.State.InProgress[model] = true
    SecretariaModule.State.CurrentNPC       = model

    local root = GetRoot()
    local originalCFrame = root and root.CFrame

    -- FIX: agora guardamos se a ficha foi REALMENTE entregue. Antes o
    -- script marcava o paciente como "processado" (por 3 minutos) mesmo
    -- quando nada tinha dado certo, entao ele era "perdido" silenciosamente.
    local delivered = false

    local ok, err = pcall(function()
        local els = FindGameElements()
        if SecretariaModule.Settings.UseFormStation and els.FormStation then
            TeleportAndFire(els.FormStation, 3)
            task.wait(0.3)
        end
        UI:Flash(0.15, Color3.fromRGB(255, 255, 255))
        if els.Camera   then TeleportAndFire(els.Camera, 3) end
        task.wait(0.4)
        if els.Computer then TeleportAndFire(els.Computer, 3) end
        task.wait(0.6)
        if els.Printer  then TeleportAndFire(els.Printer, 3) end
        task.wait(0.4)

        if model.Parent then -- paciente pode ter sumido durante o processo
            local badge = GetBadgeBase(els, model)
            delivered = DeliverFicha(model, badge)
        end
    end)

    if not ok then warn("[Secretaria] Erro: " .. tostring(err)) end

    if root and originalCFrame then root.CFrame = originalCFrame end

    SecretariaModule.State.CurrentNPC        = nil
    SecretariaModule.State.InProgress[model] = nil

    if ok and delivered then
        SecretariaModule.State.FailCount[model] = nil
        MarkProcessed(model)
        SecretariaModule.Stats.processed = SecretariaModule.Stats.processed + 1
        if SecretariaModule.Settings.ShowNotifications then
            UI:Notify("Secretaria", (model.Name or "Paciente") .. " atendido.", 3, "success")
        end
    else
        -- FIX: em vez de abandonar o paciente de vez, tenta de novo algumas
        -- vezes (a proxima iteracao do loop principal ja pega ele de novo,
        -- pois ele NAO foi marcado como processado). So desiste depois de
        -- "MaxPatientRetries" falhas seguidas, pra nao travar pra sempre
        -- num paciente bugado.
        local fails = (SecretariaModule.State.FailCount[model] or 0) + 1
        SecretariaModule.State.FailCount[model] = fails
        if fails >= (SecretariaModule.Settings.MaxPatientRetries or 3) then
            MarkProcessed(model)
            SecretariaModule.State.FailCount[model] = nil
            if SecretariaModule.Settings.ShowNotifications then
                UI:Notify("Secretaria",
                    "Nao consegui atender " .. (model.Name or "paciente") ..
                    " apos " .. fails .. " tentativas. Pulando.", 4, "error")
            end
        elseif SecretariaModule.Settings.ShowNotifications then
            UI:Notify("Secretaria",
                "Ficha em cooldown, vou tentar " .. (model.Name or "paciente") ..
                " de novo em instantes...", 3, "warning")
        end
    end
end

function SecretariaModule:Start()
    if self.State.Running then return end
    self.State.Enabled = true
    self.State.Running = true
    task.spawn(function()
        while self.State.Enabled do
            if IsAlive() then
                local waiting = GetWaitingNPCs()
                if #waiting > 0 then
                    for _, p in ipairs(waiting) do
                        if not self.State.Enabled or not IsAlive() then break end
                        pcall(ProcessPatient, p)
                        task.wait(self.Settings.LoopDelay)
                    end
                else
                    task.wait(1)
                end
            else
                task.wait(1)
            end
        end
        self.State.Running = false
    end)
    if self.Settings.ShowNotifications then
        UI:Notify("Secretaria", "Atendimento automatico ON.", 3, "success")
    end
end

function SecretariaModule:Stop()
    self.State.Enabled = false
    if self.Settings.ShowNotifications then
        UI:Notify("Secretaria", "Atendimento automatico OFF.", 3, "warning")
    end
end

function SecretariaModule:GetStatus()
    return {
        enabled   = self.State.Enabled,
        running   = self.State.Running,
        current   = self.State.CurrentNPC and self.State.CurrentNPC.Name or nil,
        processed = self.Stats.processed,
    }
end

--------------------------------------------------------------------------------
-- 11) MODULO: SHOP
--------------------------------------------------------------------------------
local ShopModule = {
    State = { Enabled = false, Buying = false, _loop = false },
    Settings = {
        SelectedItem = ConfigSystem:Get("Shop.Item", "X-Taser"),
        AutoBuy      = ConfigSystem:Get("Shop.AutoBuy", false),
    },
}

local SHOP_ITEMS = {
    "X-Taser", "Taser", "Vial", "Vial 2", "Gun",
    "Shoes", "Computer", "Scanner", "SecondCheckInBell", "Special Technique",
}

local function BuyShopItem(itemName)
    -- 1) procura remotes com nome plausivel
    local candidates = {}
    pcall(function()
        for _, root in ipairs({ReplicatedStorage, Workspace}) do
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                    local n = d.Name:lower()
                    if n:find("shop") or n:find("buy") or n:find("purchase") then
                        table.insert(candidates, d)
                    end
                end
            end
        end
    end)
    for _, r in ipairs(candidates) do
        local ok = pcall(function()
            if r:IsA("RemoteEvent") then r:FireServer(itemName)
            else r:InvokeServer(itemName) end
        end)
        if ok then return true end
    end

    -- 2) fallback: clicar no item da prateleira
    local els = FindGameElements()
    if els.ShopItems then
        local item = els.ShopItems:FindFirstChild(itemName, true)
        if item then
            return TeleportAndFire(item, 3)
        end
    end
    return false
end

function ShopModule:Tick()
    if not self.State.Enabled or self.State.Buying then return end
    self.State.Buying = true
    task.spawn(function()
        local ok = BuyShopItem(self.Settings.SelectedItem)
        if ok and self.Settings.AutoBuy then
            task.wait(2)
        end
        self.State.Buying = false
    end)
end

function ShopModule:Start()
    self.State.Enabled = true
    if not self.State._loop then
        self.State._loop = true
        task.spawn(function()
            while self.State._loop do
                self:Tick()
                task.wait(1)
            end
        end)
    end
    UI:Notify("Shop", "Auto-buy de item ON.", 3, "success")
end

function ShopModule:Stop()
    self.State.Enabled = false
    self.State._loop = false
    UI:Notify("Shop", "Auto-buy de item OFF.", 3, "warning")
end

--------------------------------------------------------------------------------
-- 12) MODULO: INFO
--------------------------------------------------------------------------------
local InfoModule = {
    State = { DeathCount = 0, Skinwalkers = 0, CurrentShift = "?", _running = false },
}

function InfoModule:Start()
    if self.State._running then return end
    self.State._running = true
    task.spawn(function()
        while self.State._running do
            pcall(function()
                local ls = LocalPlayer:FindFirstChild("leaderstats")
                if ls then
                    local d = ls:FindFirstChild("Deaths") or ls:FindFirstChild("DeathCount")
                    if d and d.Value then self.State.DeathCount = d.Value end
                    local sh = ls:FindFirstChild("Shift") or ls:FindFirstChild("Shifts")
                    if sh and sh.Value then self.State.CurrentShift = sh.Value end
                end

                -- tenta inferir shift pela GUI
                local sg = LocalPlayer:FindFirstChild("PlayerGui")
                if sg then
                    for _, gui in ipairs(sg:GetDescendants()) do
                        if gui:IsA("TextLabel") then
                            local t = gui.Text and gui.Text:lower() or ""
                            if t:find("shift") and t:match("%d+") then
                                self.State.CurrentShift = t:match("%d+")
                            end
                        end
                    end
                end

                -- conta skinwalkers no mundo
                local sw = 0
                for _, d in ipairs(Workspace:GetDescendants()) do
                    if d:IsA("Model") and d:FindFirstChild("Humanoid") then
                        if d.Name:lower():find("skinwalker", 1, true) then sw = sw + 1 end
                    end
                end
                self.State.Skinwalkers = sw
            end)
            task.wait(2)
        end
    end)
end

function InfoModule:Stop()
    self.State._running = false
end

--------------------------------------------------------------------------------
-- 13) MODULO: PLAY (auto play + replay)
--------------------------------------------------------------------------------
local PlayModule = {
    Settings = {
        AutoPlay   = ConfigSystem:Get("Play.AutoPlay", false),
        AutoReplay = ConfigSystem:Get("Play.AutoReplay", false),
        Shifts     = ConfigSystem:Get("Play.Shifts", 15),
    },
    State = { _loop = false },
}

function PlayModule:Tick()
    pcall(function()
        local sg = LocalPlayer:FindFirstChild("PlayerGui")
        if not sg then return end

        if self.Settings.AutoPlay then
            for _, gui in ipairs(sg:GetDescendants()) do
                if gui:IsA("TextButton") or gui:IsA("ImageButton") then
                    local n  = gui.Name:lower()
                    local tx = (gui.Text or ""):lower()
                    if n:find("play") or tx:find("play") or tx:find("jogar") then
                        pcall(function() gui.Activated:FireServer() end)
                        pcall(function()
                            for _, c in ipairs(getconnections(gui.Activated)) do c:Fire() end
                        end)
                    end
                end
            end
        end

        if self.Settings.AutoReplay then
            local hum = GetHumanoid()
            if hum and hum.Health <= 0 then
                for _, gui in ipairs(sg:GetDescendants()) do
                    if gui:IsA("TextButton") or gui:IsA("ImageButton") then
                        local n  = gui.Name:lower()
                        local tx = (gui.Text or ""):lower()
                        if n:find("replay") or tx:find("replay")
                            or tx:find("again") or tx:find("jogar") then
                            pcall(function() gui.Activated:FireServer() end)
                        end
                    end
                end
            end
        end
    end)
end

function PlayModule:Start()
    if self.State._loop then return end
    self.State._loop = true
    task.spawn(function()
        while self.State._loop do
            self:Tick()
            task.wait(0.5)
        end
    end)
end

function PlayModule:Stop()
    self.State._loop = false
end

--------------------------------------------------------------------------------
-- 14) MODULO: SHIFTS
--------------------------------------------------------------------------------
local ShiftModule = {
    Settings = {
        AutoShift   = ConfigSystem:Get("Shift.AutoShift", false),
        FireStrat   = ConfigSystem:Get("Shift.FireStrat", false),
        MultiFarm   = ConfigSystem:Get("Shift.MultiFarm", false),
        RoomNumbers = ConfigSystem:Get("Shift.Rooms", "1,2,3,4,5"),
    },
    State = { Running = false },
}

local _shiftRemoteWarned = false
function ShiftModule:StartShift()
    -- alvo: só RemoteEvents que combinam "start" e "shift" juntos
    local found = false
    pcall(function()
        for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
            if d:IsA("RemoteEvent") then
                local n = d.Name:lower()
                if (n:find("start") and n:find("shift"))
                    or n == "startshift" or n == "beginshift" then
                    d:FireServer()
                    found = true
                end
            end
        end
    end)
    if not found and not _shiftRemoteWarned then
        _shiftRemoteWarned = true
        warn("[SolixHub] Auto Shift: nenhum RemoteEvent 'start+shift' encontrado neste jogo. Essa funcao nao tem efeito na versao atual do mapa.")
        UI:Notify("Auto Shift", "Nenhum evento de shift encontrado neste jogo. Feature sem efeito.", 4, "warning")
    end
end

function ShiftModule:Start()
    if self.State.Running then return end
    self.State.Running = true
    task.spawn(function()
        while self.State.Running do
            if self.Settings.AutoShift then self:StartShift() end

            if self.Settings.FireStrat then
                pcall(function()
                    local els = FindGameElements()
                    if els.Rooms then
                        for _, f in ipairs(els.Rooms:GetDescendants()) do
                            -- no jogo real o fogo e um Model chamado "Fire" (nao a classe nativa Fire)
                            if f and (f:IsA("Model") or f:IsA("Folder")) and f.Name == "Fire" then
                                pcall(function() f:Destroy() end)
                            end
                        end
                    end
                end)
            end

            task.wait(3)
        end
    end)
    UI:Notify("Shifts", "Auto-Shift ON.", 3, "success")
end

function ShiftModule:Stop()
    self.State.Running = false
    UI:Notify("Shifts", "Auto-Shift OFF.", 3, "warning")
end

--------------------------------------------------------------------------------
-- 15) MODULO: TASER
--------------------------------------------------------------------------------
local TaserModule = {
    Settings = {
        AutoTase    = ConfigSystem:Get("Taser.Auto", false),
        InfiniteAll = ConfigSystem:Get("Taser.InfiniteAll", false),
        MaxDistance = ConfigSystem:Get("Taser.MaxDist", 30),
    },
    State = { Running = false },
}

function TaserModule:Start()
    if self.State.Running then return end
    self.State.Running = true
    task.spawn(function()
        while self.State.Running do
            if self.Settings.AutoTase or self.Settings.InfiniteAll then
                pcall(function()
                    if EquipTool("taser") or EquipTool("X-Taser") then
                        local tool = LocalPlayer.Character
                            and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                        if tool then
                            local root = GetRoot()
                            if root then
                                local best, bestDist = nil, self.Settings.MaxDistance
                                for _, d in ipairs(Workspace:GetDescendants()) do
                                    if d:IsA("Model") and d:FindFirstChild("Humanoid")
                                        and d ~= LocalPlayer.Character then
                                        local hrp = d:FindFirstChild("HumanoidRootPart")
                                        if hrp then
                                            local dist = (root.Position - hrp.Position).Magnitude
                                            if dist < bestDist then
                                                best, bestDist = d, dist
                                            end
                                        end
                                    end
                                end
                                if best then
                                    local hrp = best:FindFirstChild("HumanoidRootPart")
                                    if hrp then
                                        TeleportTo(hrp, Vector3.new(0, 0, 1))
                                        task.wait(0.2)
                                    end
                                    pcall(function() tool:Activate() end)
                                end
                            end
                        end
                    end
                end)
            end
            task.wait(0.7)
        end
    end)
    UI:Notify("Taser", "Auto-Tase ON.", 3, "success")
end

function TaserModule:Stop()
    self.State.Running = false
    UI:Notify("Taser", "Auto-Tase OFF.", 3, "warning")
end

--------------------------------------------------------------------------------
-- 16) MODULO: COFFEE
--------------------------------------------------------------------------------
local CoffeeModule = {
    Settings = { Enabled = ConfigSystem:Get("Coffee.Auto", false) },
    State    = { Running = false },
}

function CoffeeModule:Start()
    if self.State.Running then return end
    self.State.Running = true
    task.spawn(function()
        while self.State.Running do
            if self.Settings.Enabled then
                pcall(function()
                    local els = FindGameElements()
                    local machine = els.CoffeeMachine or els.CoffeeMachine2
                    if machine and els.NPCs then
                        local got = TeleportAndFire(machine, 3)
                        if got then
                            task.wait(0.3)
                            local root = GetRoot()
                            if root then
                                local best, bestDist = nil, math.huge
                                for _, n in ipairs(els.NPCs:GetChildren()) do
                                    if n:FindFirstChild("Humanoid") then
                                        local hrp = n:FindFirstChild("HumanoidRootPart")
                                        if hrp then
                                            local dist = (root.Position - hrp.Position).Magnitude
                                            if dist < bestDist then best, bestDist = n, dist end
                                        end
                                    end
                                end
                                if best then
                                    local anchor = GetAnchorPart(best)
                                    if anchor then
                                        TeleportTo(anchor, Vector3.new(0, 0, 2))
                                        task.wait(0.2)
                                        local fired = FireProximity(best, 3) or FireClick(best)
                                        if not fired then WaitAndFire(best, 2) end
                                    end
                                end
                            end
                        end
                    end
                end)
            end
            task.wait(2)
        end
    end)
    UI:Notify("Coffee", "Auto-Coffee ON.", 3, "success")
end

function CoffeeModule:Stop()
    self.State.Running = false
    UI:Notify("Coffee", "Auto-Coffee OFF.", 3, "warning")
end

--------------------------------------------------------------------------------
-- 17) MODULO: CARRY
--------------------------------------------------------------------------------
local CarryModule = {
    Settings = { Enabled = ConfigSystem:Get("Carry.Auto", false), MaxDistance = 10 },
    State    = { Running = false },
}

function CarryModule:Start()
    if self.State.Running then return end
    self.State.Running = true
    task.spawn(function()
        while self.State.Running do
            if self.Settings.Enabled then
                pcall(function()
                    local els = FindGameElements()
                    if els.NPCs then
                        local root = GetRoot()
                        if root then
                            for _, n in ipairs(els.NPCs:GetChildren()) do
                                if n:FindFirstChild("Humanoid") then
                                    local hrp = n:FindFirstChild("HumanoidRootPart")
                                    if hrp and (root.Position - hrp.Position).Magnitude < self.Settings.MaxDistance then
                                        local fired = FireClick(n) or FireProximity(n, 2)
                                        if fired then break end
                                    end
                                end
                            end
                        end
                    end
                end)
            end
            task.wait(0.5)
        end
    end)
    UI:Notify("Carry", "Auto-Carry ON.", 3, "success")
end

function CarryModule:Stop()
    self.State.Running = false
    UI:Notify("Carry", "Auto-Carry OFF.", 3, "warning")
end

--------------------------------------------------------------------------------
-- 18) MODULO: EMERGENCY
--------------------------------------------------------------------------------
local EmergencyModule = {
    Settings = { Enabled = ConfigSystem:Get("Emergency.Auto", false) },
    State    = { Running = false },
}

function EmergencyModule:Start()
    if self.State.Running then return end
    self.State.Running = true
    task.spawn(function()
        while self.State.Running do
            if self.Settings.Enabled then
                pcall(function()
                    local els = FindGameElements()
                    if els.Rooms then
                        local emergency = els.Rooms:FindFirstChild("Emergency")
                        if emergency then
                            for _, room in ipairs(emergency:GetChildren()) do
                                pcall(function()
                                    for _, d in ipairs(room:GetDescendants()) do
                                        if d:IsA("ProximityPrompt") and d.Enabled then
                                            TeleportAndFire(room, 2)
                                            break
                                        end
                                    end
                                end)
                            end
                        end
                    end
                end)
            end
            task.wait(1)
        end
    end)
    UI:Notify("Emergency", "Auto-Emergency ON.", 3, "success")
end

function EmergencyModule:Stop()
    self.State.Running = false
    UI:Notify("Emergency", "Auto-Emergency OFF.", 3, "warning")
end

--------------------------------------------------------------------------------
-- 19) MODULO: SANITY
--------------------------------------------------------------------------------
local SanityModule = {
    Settings = { Infinite = ConfigSystem:Get("Sanity.Infinite", false) },
    State    = { Running = false },
}

function SanityModule:Start()
    if self.State.Running then return end
    self.State.Running = true
    task.spawn(function()
        while self.State.Running do
            if self.Settings.Infinite then
                pcall(function()
                    local hum = GetHumanoid()
                    if hum and hum.Health > 0 and hum.Health < hum.MaxHealth then
                        hum.Health = hum.MaxHealth
                    end
                end)
            end
            task.wait(0.5)
        end
    end)
    UI:Notify("Sanity", "Infinite Sanity ON.", 3, "success")
end

function SanityModule:Stop()
    self.State.Running = false
    UI:Notify("Sanity", "Infinite Sanity OFF.", 3, "warning")
end

--------------------------------------------------------------------------------
-- 20) MODULO: CREEPS
--------------------------------------------------------------------------------
local CreepsModule = {
    Settings = {
        HelpLiz       = ConfigSystem:Get("Creep.Liz", false),
        AvoidHiders   = ConfigSystem:Get("Creep.NoHider", false),
        AutoAvoidSW   = ConfigSystem:Get("Creep.NoSkinwalker", false),
        AvoidSlime    = ConfigSystem:Get("Creep.NoSlime", false),
        GiveCoffee    = ConfigSystem:Get("Creep.Coffee", false),
        AvoidEyeMass  = ConfigSystem:Get("Creep.NoEye", false),
        PutOutFire    = ConfigSystem:Get("Creep.NoFire", false),
        AutoAskLeaves = ConfigSystem:Get("Creep.Leaves", false),
    },
    State = { Running = false },
}

local function FindCreepByName(name)
    name = name:lower()
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("Model") and d:FindFirstChild("Humanoid") then
            if d.Name:lower():find(name, 1, true) then return d end
        end
    end
    return nil
end

function CreepsModule:Tick()
    if not self.State.Running then return end
    local root = GetRoot()
    if not root then return end

    pcall(function()
        if self.Settings.HelpLiz then
            local liz = FindCreepByName("liz")
            if liz then
                local anchor = GetAnchorPart(liz)
                if anchor and (root.Position - anchor.Position).Magnitude < 5 then
                    if not FireClick(liz) then FireProximity(liz, 2) end
                end
            end
        end

        local threats = {}
        if self.Settings.AvoidHiders  then table.insert(threats, "hider")      end
        if self.Settings.AutoAvoidSW  then table.insert(threats, "skinwalker") end
        if self.Settings.AvoidSlime   then table.insert(threats, "slime")      end
        if self.Settings.AvoidEyeMass then table.insert(threats, "eye")        end

        if #threats > 0 then
            local closest, closestDist = nil, math.huge
            for _, d in ipairs(Workspace:GetDescendants()) do
                if d:IsA("Model") and d:FindFirstChild("Humanoid") then
                    for _, kw in ipairs(threats) do
                        if d.Name:lower():find(kw, 1, true) then
                            local hrp = d:FindFirstChild("HumanoidRootPart")
                            if hrp then
                                local dist = (root.Position - hrp.Position).Magnitude
                                if dist < closestDist then closest, closestDist = d, dist end
                            end
                            break
                        end
                    end
                end
            end
            if closest and closestDist < 20 then
                local pivot = closest:GetPivot().Position
                local dir = (root.Position - pivot)
                if dir.Magnitude < 0.01 then dir = Vector3.new(0, 0, 1) end
                root.CFrame = CFrame.new(root.Position + dir.Unit * 30)
            end
        end

        if self.Settings.PutOutFire then
            local els = FindGameElements()
            if els.Rooms then
                for _, f in ipairs(els.Rooms:GetDescendants()) do
                    if f:IsA("Fire") then pcall(function() f:Destroy() end) end
                end
            end
        end
    end)
end

function CreepsModule:Start()
    if self.State.Running then return end
    self.State.Running = true
    task.spawn(function()
        while self.State.Running do
            self:Tick()
            task.wait(0.5)
        end
    end)
    UI:Notify("Creeps", "Modulo Creeps ON.", 3, "success")
end

function CreepsModule:Stop()
    self.State.Running = false
end

--------------------------------------------------------------------------------
-- 21) PLAYER MODULE
--------------------------------------------------------------------------------
local PlayerModule = {
    Settings = {
        WalkSpeed = ConfigSystem:Get("Player.Walk", 16),
        JumpPower = ConfigSystem:Get("Player.Jump", 50),
        Noclip    = ConfigSystem:Get("Player.Noclip", false),
    },
    State = { Running = false, _noclipConn = nil },
}

function PlayerModule:Apply()
    pcall(function()
        local hum = GetHumanoid()
        if hum then
            hum.WalkSpeed = self.Settings.WalkSpeed
            -- suporta tanto JumpPower quanto JumpHeight
            pcall(function() hum.JumpPower = self.Settings.JumpPower end)
            pcall(function() hum.JumpHeight = self.Settings.JumpPower / 3 end)
            pcall(function() hum.UseJumpPower = true end)
        end
    end)
end

function PlayerModule:StartNoclip()
    if self.State.Running then return end
    self.State.Running = true
    local noclipFlag = self.Settings.Noclip
    self.State._noclipConn = RunService.Stepped:Connect(function()
        if not noclipFlag then return end
        pcall(function()
            local c = LocalPlayer.Character
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
        end)
    end)
    -- atualiza o flag quando o user mexer no toggle
    task.spawn(function()
        while self.State.Running do
            noclipFlag = self.Settings.Noclip
            task.wait(0.5)
        end
    end)
end

function PlayerModule:StopNoclip()
    self.State.Running = false
    if self.State._noclipConn then
        pcall(function() self.State._noclipConn:Disconnect() end)
        self.State._noclipConn = nil
    end
    -- restaura colisao do proprio char
    pcall(function()
        local c = LocalPlayer.Character
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                    p.CanCollide = true
                end
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- 22) CAMERA MODULE
--------------------------------------------------------------------------------
local CameraModule = {
    Settings = { Mode = ConfigSystem:Get("Camera.Mode", "Classic") },
    _savedSubject = nil,
}

function CameraModule:Apply()
    pcall(function()
        local c = LocalPlayer.Character
        if not c then return end
        local hum = c:FindFirstChildOfClass("Humanoid")
        local root = c:FindFirstChild("HumanoidRootPart")

        if self._savedSubject == nil then
            self._savedSubject = Camera.CameraSubject
        end

        if self.Settings.Mode == "First Person" and hum then
            Camera.CameraType = Enum.CameraType.Custom
            Camera.CameraSubject = hum
        elseif self.Settings.Mode == "Third Person" and hum then
            Camera.CameraType = Enum.CameraType.Custom
            Camera.CameraSubject = hum
        elseif self.Settings.Mode == "Free Cam" then
            Camera.CameraType = Enum.CameraType.Scriptable
            Camera.CameraSubject = nil
        elseif self.Settings.Mode == "Top Down" then
            if root then
                Camera.CameraType = Enum.CameraType.Scriptable
                Camera.CFrame = CFrame.new(root.Position + Vector3.new(0, 30, 0), root.Position)
            end
        else -- Classic
            Camera.CameraType = Enum.CameraType.Custom
            if hum then Camera.CameraSubject = hum end
        end
    end)
end

function CameraModule:Restore()
    pcall(function()
        Camera.CameraType = Enum.CameraType.Custom
        if self._savedSubject then Camera.CameraSubject = self._savedSubject end
    end)
end

--------------------------------------------------------------------------------
-- 23) FPS MODULE
--------------------------------------------------------------------------------
local FPSModule = {
    Settings = {
        Disable3D = ConfigSystem:Get("FPS.Disable3D", false),
        FPSBoost  = ConfigSystem:Get("FPS.Boost", false),
    },
    State = { _origQuality = nil, _origTerrain = nil, _origShadows = nil, _origFog = nil },
}

function FPSModule:Apply()
    pcall(function()
        if self.Settings.FPSBoost then
            self.State._origQuality = settings().Rendering.QualityLevel
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            if Workspace.Terrain then
                self.State._origTerrain = Workspace.Terrain.Decoration
                Workspace.Terrain.Decoration = false
            end
            self.State._origShadows = Lighting.GlobalShadows
            self.State._origFog     = Lighting.FogEnd
            Lighting.GlobalShadows = false
            Lighting.FogEnd        = 1000
        end
        if self.Settings.Disable3D then
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        end
    end)
end

function FPSModule:Restore()
    pcall(function()
        if self.State._origQuality then
            settings().Rendering.QualityLevel = self.State._origQuality
        else
            settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
        end
        if Workspace.Terrain and self.State._origTerrain ~= nil then
            Workspace.Terrain.Decoration = self.State._origTerrain
        end
        if self.State._origShadows ~= nil then Lighting.GlobalShadows = self.State._origShadows end
        if self.State._origFog     ~= nil then Lighting.FogEnd        = self.State._origFog     end
    end)
end

--------------------------------------------------------------------------------
-- 24) REJOIN / SERVERHOP
--------------------------------------------------------------------------------
local RejoinModule = {}

function RejoinModule:CopyJobId()
    local ok = pcall(function() if setclipboard then setclipboard(game.JobId) end end)
    UI:Notify("JobID", ok and ("Copiado: " .. game.JobId) or "Falha ao copiar.", 3, "info")
end

function RejoinModule:Rejoin()
    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)
end

function RejoinModule:JoinJobId(jobId)
    if not jobId or jobId == "" or jobId:lower():find("put jobid") then
        UI:Notify("JobID", "Cole um JobID valido primeiro.", 3, "warning")
        return
    end
    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer)
    end)
end

function RejoinModule:ServerHop()
    pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local data
        if typeof(request) == "function" then
            local r = request({Url = url, Method = "GET"})
            if r and r.Body then data = HttpService:JSONDecode(r.Body) end
        elseif typeof(game.HttpGet) == "function" then
            data = HttpService:JSONDecode(game:HttpGet(url))
        end
        if data and data.data and #data.data > 0 then
            local servers = {}
            for _, s in ipairs(data.data) do
                if s.id ~= game.JobId and s.playing < s.maxPlayers then
                    table.insert(servers, s)
                end
            end
            if #servers > 0 then
                local target = servers[math.random(1, #servers)]
                TeleportService:TeleportToPlaceInstance(game.PlaceId, target.id, LocalPlayer)
                return
            end
        end
        self:Rejoin()
    end)
end

--------------------------------------------------------------------------------
-- 25) ANTI-AFK
--------------------------------------------------------------------------------
local AntiAFK = { Enabled = false, _idleConn = nil }

function AntiAFK:Enable()
    if self.Enabled then return end
    self.Enabled = true
    pcall(function()
        self._idleConn = LocalPlayer.Idled:Connect(function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end)
    end)
    UI:Notify("Anti-AFK", "Ativado.", 3, "success")
end

function AntiAFK:Disable()
    self.Enabled = false
    if self._idleConn then
        pcall(function() self._idleConn:Disconnect() end)
        self._idleConn = nil
    end
    UI:Notify("Anti-AFK", "Desativado.", 3, "warning")
end

--------------------------------------------------------------------------------
-- 26) WINDUI WINDOW
--------------------------------------------------------------------------------
-- FIX: a logo estava faltando porque essa variavel (IconURL) era baixada
-- em lugar nenhum -- ela existia mas nunca era usada de verdade na janela.
-- Agora baixamos a imagem e transformamos num asset local pra usar como
-- icone da janela. Se falhar por qualquer motivo, cai pro icone padrao.
local WindowIconAsset
pcall(function()
    WindowIconAsset = SaveBinaryAndGetAsset(IconURL, "rsv4_logo.jpg")
end)

local Window
local okW, errW = pcall(function()
    Window = W_CreateWindow({
        Title    = "Solix Hub — Receptionist V4",
        Icon     = WindowIconAsset or "door-open",  -- sua logo; cai pro icone lucide se a imagem falhar
        Author   = "FelzpSystem",              -- subtitulo da janela
        Folder   = "SolixHubReceptionistV4",   -- onde salva keys/imagens

        Size     = UDim2.fromOffset(620, 480),
        MinSize  = Vector2.new(560, 360),
        MaxSize  = Vector2.new(900, 620),
        Resizable = true,
        Transparent = true,

        Theme    = "Dark",
        SideBarWidth = 200,
        HideSearchBar = false,
        ScrollBarEnabled = false,

        BackgroundImageTransparency = 0.42,
        -- Background = "rbxassetid://1234",  -- opcional, deixa comentado

        User = {
            Enabled   = true,
            Anonymous = false,
            Callback  = function()
                print("[SolixHub] user icon clicado")
            end,
        },

        -- KeySystem desligado (script publico)
        -- KeySystem = { ... },
    })
end)

if not okW or not Window then
    warn("[SolixHub] Falha ao criar janela: " .. tostring(errW))
    return
end

task.spawn(function() PlayMenuAudio(0.4) end)
task.spawn(function() HighlightSystem:StartLiveScan() end)
InfoModule:Start()

--------------------------------------------------------------------------------
-- 27) TABS
--------------------------------------------------------------------------------

-- =========================
-- ABA: PRINCIPAL
-- =========================
local PrincipalTab = Window:Tab({Title = "Principal", Icon = "house"})

PrincipalTab:Section({Title = "Identidade"})
PrincipalTab:Paragraph({
    Title = "Player",
    Desc  = string.format(
        "Username: %s\nUserId: %d\nConta: %d dias\nPlaceId: %d\nJobId: %s",
        LocalPlayer.Name, LocalPlayer.UserId, LocalPlayer.AccountAge,
        game.PlaceId, game.JobId
    )
})

PrincipalTab:Section({Title = "Status da Sessao"})

local function BuildSecretariaDesc()
    local s = SecretariaModule:GetStatus()
    return string.format(
        "Estado: %s\nProcessados: %d\nAtual: %s",
        s.enabled and "ATIVA" or "parada",
        s.processed,
        s.current or "-"
    )
end

local function BuildInfoDesc()
    return string.format(
        "Deaths: %d\nSkinwalkers no mapa: %d\nShift atual: %s",
        InfoModule.State.DeathCount,
        InfoModule.State.Skinwalkers,
        tostring(InfoModule.State.CurrentShift)
    )
end

local SecretariaParagraph = PrincipalTab:Paragraph({
    Title = "Secretaria",
    Desc  = BuildSecretariaDesc(), -- string estatica na criacao (WindUI nao aceita function aqui)
})
local InfoParagraph = PrincipalTab:Paragraph({
    Title = "Info do Jogo",
    Desc  = BuildInfoDesc(),
})

-- Atualiza os dois paragraphs periodicamente de forma segura (sem quebrar se a API nao suportar)
task.spawn(function()
    while true do
        task.wait(2)
        pcall(function()
            if SecretariaParagraph then
                local newDesc = BuildSecretariaDesc()
                if type(SecretariaParagraph.SetDesc) == "function" then
                    SecretariaParagraph:SetDesc(newDesc)
                elseif type(SecretariaParagraph.Set) == "function" then
                    SecretariaParagraph:Set({Desc = newDesc})
                elseif SecretariaParagraph.Desc ~= nil then
                    SecretariaParagraph.Desc = newDesc
                end
            end
        end)
        pcall(function()
            if InfoParagraph then
                local newDesc = BuildInfoDesc()
                if type(InfoParagraph.SetDesc) == "function" then
                    InfoParagraph:SetDesc(newDesc)
                elseif type(InfoParagraph.Set) == "function" then
                    InfoParagraph:Set({Desc = newDesc})
                elseif InfoParagraph.Desc ~= nil then
                    InfoParagraph.Desc = newDesc
                end
            end
        end)
    end
end)

PrincipalTab:Section({Title = "Atalhos Rapidos"})
PrincipalTab:Toggle({
    Title = "Secretaria (atendimento automatico)",
    Value = SecretariaModule.State.Enabled,
    Callback = function(v)
        if v then SecretariaModule:Start() else SecretariaModule:Stop() end
    end,
})
PrincipalTab:Toggle({
    Title = "Anti-AFK",
    Value = false,
    Callback = function(v) if v then AntiAFK:Enable() else AntiAFK:Disable() end end,
})
PrincipalTab:Toggle({
    Title = "Highlights (Visual)",
    Value = HighlightSystem.Enabled,
    Callback = function(v) HighlightSystem:SetEnabled(v) end,
})
PrincipalTab:Toggle({
    Title = "ESP (separado do Highlight)",
    Value = ESPModule.Settings.Enabled,
    Callback = function(v)
        ESPModule.Settings.Enabled = v
        ConfigSystem:Set("ESP.On", v)
        if v then ESPModule:Start() else ESPModule:Stop() end
    end,
})

PrincipalTab:Section({Title = "Tema"})
local themeChoices = {"Dark", "Light", "Cubic", "Rose", "Plasma"}
PrincipalTab:Dropdown({
    Title  = "Tema do Menu",
    Values = themeChoices,
    Value  = "Dark",
    Callback = function(v) pcall(function() W_SetTheme(v) end) end,
})

PrincipalTab:Section({Title = "Unload"})
PrincipalTab:Button({
    Title = "Descarregar Script",
    Callback = function()
        UI:Notify("Unload", "Encerrando todos os modulos...", 3, "warning")
        HighlightSystem:StopLiveScan()
        SecretariaModule:Stop()
        ShopModule:Stop()
        ShiftModule:Stop()
        TaserModule:Stop()
        CoffeeModule:Stop()
        CarryModule:Stop()
        EmergencyModule:Stop()
        SanityModule:Stop()
        CreepsModule:Stop()
        ESPModule:Stop()
        PlayerModule:StopNoclip()
        FPSModule:Restore()
        CameraModule:Restore()
        AntiAFK:Disable()
        InfoModule:Stop()
        PlayModule:Stop()
        task.wait(0.5)
        pcall(function()
            for _, gui in ipairs(PlayerGui:GetDescendants()) do
                if gui.Name:find("WindUI") or gui.Name:find("Solix") then
                    pcall(function() gui:Destroy() end)
                end
            end
        end)
    end,
})

-- =========================
-- ABA: VISUAL
-- =========================
local VisualTab = Window:Tab({Title = "Visual", Icon = "eye"})

VisualTab:Section({Title = "Highlights do Mapa"})
VisualTab:Toggle({
    Title = "Ativar Highlights",
    Value = HighlightSystem.Enabled,
    Callback = function(v) HighlightSystem:SetEnabled(v) end,
})
VisualTab:Toggle({
    Title = "Apenas Anomalias",
    Value = HighlightSystem.OnlyAnomalies,
    Callback = function(v) HighlightSystem.OnlyAnomalies = v end,
})
VisualTab:Slider({
    Title = "Fill Transparency",
    Step  = 0.05,
    Value = {Min = 0, Max = 1, Default = HighlightSystem.Settings.FillTransparency},
    Callback = function(v) HighlightSystem.Settings.FillTransparency = v end,
})
VisualTab:Slider({
    Title = "Outline Transparency",
    Step  = 0.05,
    Value = {Min = 0, Max = 1, Default = HighlightSystem.Settings.OutlineTransparency},
    Callback = function(v) HighlightSystem.Settings.OutlineTransparency = v end,
})

VisualTab:Section({Title = "ESP (com nome e HP)"})
VisualTab:Toggle({
    Title = "Ativar ESP",
    Value = ESPModule.Settings.Enabled,
    Callback = function(v)
        ESPModule.Settings.Enabled = v
        ConfigSystem:Set("ESP.On", v)
        if v then ESPModule:Start() else ESPModule:Stop() end
    end,
})
VisualTab:Toggle({
    Title = "Mostrar info (nome / coords / HP)",
    Value = ESPModule.Settings.AllInfo,
    Callback = function(v)
        ESPModule.Settings.AllInfo = v
        ConfigSystem:Set("ESP.AllInfo", v)
    end,
})
VisualTab:Slider({
    Title = "ESP Fill",
    Step  = 0.05,
    Value = {Min = 0, Max = 1, Default = ESPModule.Settings.FillTransp},
    Callback = function(v)
        ESPModule.Settings.FillTransp = v
        ConfigSystem:Set("ESP.Fill", v)
    end,
})
VisualTab:Slider({
    Title = "ESP Outline",
    Step  = 0.05,
    Value = {Min = 0, Max = 1, Default = ESPModule.Settings.OutlineTransp},
    Callback = function(v)
        ESPModule.Settings.OutlineTransp = v
        ConfigSystem:Set("ESP.Outline", v)
    end,
})
VisualTab:Slider({
    Title = "Distancia maxima (studs)",
    Step  = 10,
    Value = {Min = 50, Max = 1000, Default = ESPModule.Settings.MaxDistance},
    Callback = function(v)
        ESPModule.Settings.MaxDistance = v
        ConfigSystem:Set("ESP.MaxDist", v)
    end,
})

-- =========================
-- ABA: PLAYER
-- =========================
local PlayerTab = Window:Tab({Title = "Player", Icon = "user-round"})

PlayerTab:Section({Title = "Movimento"})
PlayerTab:Slider({
    Title = "WalkSpeed",
    Step  = 1,
    Value = {Min = 0, Max = 250, Default = PlayerModule.Settings.WalkSpeed},
    Callback = function(v)
        PlayerModule.Settings.WalkSpeed = v
        ConfigSystem:Set("Player.Walk", v)
        PlayerModule:Apply()
    end,
})
PlayerTab:Slider({
    Title = "JumpPower",
    Step  = 1,
    Value = {Min = 0, Max = 250, Default = PlayerModule.Settings.JumpPower},
    Callback = function(v)
        PlayerModule.Settings.JumpPower = v
        ConfigSystem:Set("Player.Jump", v)
        PlayerModule:Apply()
    end,
})
PlayerTab:Toggle({
    Title = "Noclip",
    Value = PlayerModule.Settings.Noclip,
    Callback = function(v)
        PlayerModule.Settings.Noclip = v
        ConfigSystem:Set("Player.Noclip", v)
        if v then PlayerModule:StartNoclip() else PlayerModule:StopNoclip() end
    end,
})

PlayerTab:Section({Title = "Camera"})
PlayerTab:Dropdown({
    Title  = "Modo de Camera",
    Values = {"Classic", "First Person", "Third Person", "Free Cam", "Top Down"},
    Value  = CameraModule.Settings.Mode,
    Callback = function(v)
        CameraModule.Settings.Mode = v
        ConfigSystem:Set("Camera.Mode", v)
        CameraModule:Apply()
    end,
})
PlayerTab:Button({
    Title = "Restaurar Camera",
    Callback = function() CameraModule:Restore() end,
})

PlayerTab:Section({Title = "Funcoes do Jogo"})
PlayerTab:Section({Title = "Secretaria (atendimento)"})
PlayerTab:Toggle({
    Title = "Auto Front Desk",
    Value = SecretariaModule.State.Enabled,
    Callback = function(v) if v then SecretariaModule:Start() else SecretariaModule:Stop() end end,
})
PlayerTab:Dropdown({
    Title  = "Tipo de Ficha",
    Values = {"Patient", "Visitor"},
    Value  = SecretariaModule.Settings.DefaultBadgeType,
    Callback = function(v)
        SecretariaModule.Settings.DefaultBadgeType = v
        ConfigSystem:Set("Secretaria.BadgeType", v)
    end,
})
PlayerTab:Slider({
    Title = "Delay entre atendimentos (s)",
    Step  = 0.1,
    Value = {Min = 0.5, Max = 5, Default = SecretariaModule.Settings.LoopDelay},
    Callback = function(v)
        SecretariaModule.Settings.LoopDelay = v
        ConfigSystem:Set("Secretaria.LoopDelay", v)
    end,
})
PlayerTab:Slider({
    Title = "Timeout de espera da ficha (s)",
    Step  = 1,
    Value = {Min = 3, Max = 15, Default = SecretariaModule.Settings.FichaTimeout},
    Callback = function(v)
        SecretariaModule.Settings.FichaTimeout = v
        ConfigSystem:Set("Secretaria.FichaTimeout", v)
    end,
})
PlayerTab:Slider({
    Title = "Tentativas se a ficha estiver em cooldown",
    Step  = 1,
    Value = {Min = 1, Max = 8, Default = SecretariaModule.Settings.FichaMaxAttempts},
    Callback = function(v)
        SecretariaModule.Settings.FichaMaxAttempts = v
        ConfigSystem:Set("Secretaria.FichaMaxAttempts", v)
    end,
})
PlayerTab:Toggle({
    Title = "Notificacoes de atendimento",
    Value = SecretariaModule.Settings.ShowNotifications,
    Callback = function(v)
        SecretariaModule.Settings.ShowNotifications = v
        ConfigSystem:Set("Secretaria.Notif", v)
    end,
})
PlayerTab:Toggle({
    Title = "Usar Form Station",
    Value = SecretariaModule.Settings.UseFormStation,
    Callback = function(v)
        SecretariaModule.Settings.UseFormStation = v
        ConfigSystem:Set("Secretaria.UseForm", v)
    end,
})

PlayerTab:Section({Title = "Play / Shift"})
PlayerTab:Toggle({
    Title = "Auto Play",
    Value = PlayModule.Settings.AutoPlay,
    Callback = function(v)
        PlayModule.Settings.AutoPlay = v
        ConfigSystem:Set("Play.AutoPlay", v)
        if v then PlayModule:Start() end
    end,
})
PlayerTab:Toggle({
    Title = "Auto RePlay",
    Value = PlayModule.Settings.AutoReplay,
    Callback = function(v)
        PlayModule.Settings.AutoReplay = v
        ConfigSystem:Set("Play.AutoReplay", v)
        if v then PlayModule:Start() end
    end,
})
PlayerTab:Slider({
    Title = "Shifts para rodar",
    Step  = 1,
    Value = {Min = 1, Max = 50, Default = PlayModule.Settings.Shifts},
    Callback = function(v)
        PlayModule.Settings.Shifts = v
        ConfigSystem:Set("Play.Shifts", v)
    end,
})

PlayerTab:Section({Title = "Shifts Automaticos"})
PlayerTab:Toggle({
    Title = "Auto Shift",
    Value = ShiftModule.Settings.AutoShift,
    Callback = function(v)
        ShiftModule.Settings.AutoShift = v
        ConfigSystem:Set("Shift.AutoShift", v)
        if v then ShiftModule:Start() else ShiftModule:Stop() end
    end,
})
PlayerTab:Toggle({
    Title = "Fire Strat (apaga fogo nas Rooms)",
    Value = ShiftModule.Settings.FireStrat,
    Callback = function(v)
        ShiftModule.Settings.FireStrat = v
        ConfigSystem:Set("Shift.FireStrat", v)
        if v then ShiftModule:Start() else ShiftModule:Stop() end
    end,
})
PlayerTab:Toggle({
    Title = "Multi Farm",
    Value = ShiftModule.Settings.MultiFarm,
    Callback = function(v)
        ShiftModule.Settings.MultiFarm = v
        ConfigSystem:Set("Shift.MultiFarm", v)
        if v then ShiftModule:Start() else ShiftModule:Stop() end
    end,
})
PlayerTab:Input({
    Title = "Room Numbers",
    Value = ShiftModule.Settings.RoomNumbers,
    Placeholder = "1,2,3,4,5",
    Callback = function(v)
        ShiftModule.Settings.RoomNumbers = v
        ConfigSystem:Set("Shift.Rooms", v)
    end,
})

PlayerTab:Section({Title = "Taser"})
PlayerTab:Toggle({
    Title = "Auto Tase",
    Value = TaserModule.Settings.AutoTase,
    Callback = function(v)
        TaserModule.Settings.AutoTase = v
        ConfigSystem:Set("Taser.Auto", v)
        if v then TaserModule:Start() else TaserModule:Stop() end
    end,
})
PlayerTab:Toggle({
    Title = "Infinite Tase All",
    Value = TaserModule.Settings.InfiniteAll,
    Callback = function(v)
        TaserModule.Settings.InfiniteAll = v
        ConfigSystem:Set("Taser.InfiniteAll", v)
        if v then TaserModule:Start() else TaserModule:Stop() end
    end,
})
PlayerTab:Slider({
    Title = "Distancia maxima do alvo (studs)",
    Step  = 1,
    Value = {Min = 5, Max = 100, Default = TaserModule.Settings.MaxDistance},
    Callback = function(v)
        TaserModule.Settings.MaxDistance = v
        ConfigSystem:Set("Taser.MaxDist", v)
    end,
})

PlayerTab:Section({Title = "Coffee / Carry / Emergency / Sanity"})
PlayerTab:Toggle({
    Title = "Auto Coffee",
    Value = CoffeeModule.Settings.Enabled,
    Callback = function(v)
        CoffeeModule.Settings.Enabled = v
        ConfigSystem:Set("Coffee.Auto", v)
        if v then CoffeeModule:Start() else CoffeeModule:Stop() end
    end,
})
PlayerTab:Toggle({
    Title = "Auto Carry (pegar pacientes proximos)",
    Value = CarryModule.Settings.Enabled,
    Callback = function(v)
        CarryModule.Settings.Enabled = v
        ConfigSystem:Set("Carry.Auto", v)
        if v then CarryModule:Start() else CarryModule:Stop() end
    end,
})
PlayerTab:Toggle({
    Title = "Auto Emergency Rooms",
    Value = EmergencyModule.Settings.Enabled,
    Callback = function(v)
        EmergencyModule.Settings.Enabled = v
        ConfigSystem:Set("Emergency.Auto", v)
        if v then EmergencyModule:Start() else EmergencyModule:Stop() end
    end,
})
PlayerTab:Toggle({
    Title = "Infinite Sanity (mantem vida cheia)",
    Value = SanityModule.Settings.Infinite,
    Callback = function(v)
        SanityModule.Settings.Infinite = v
        ConfigSystem:Set("Sanity.Infinite", v)
        if v then SanityModule:Start() else SanityModule:Stop() end
    end,
})

PlayerTab:Section({Title = "Creeps"})
local creepToggles = {
    {Key = "HelpLiz",       Title = "Help Liz"},
    {Key = "AvoidHiders",   Title = "Avoid Hiders"},
    {Key = "AutoAvoidSW",   Title = "Auto Avoid SkinWalkers"},
    {Key = "AvoidSlime",    Title = "Avoid Slime"},
    {Key = "GiveCoffee",    Title = "Give Coffee"},
    {Key = "AvoidEyeMass",  Title = "Avoid Eye Mass"},
    {Key = "PutOutFire",    Title = "Put Out Fire (Rooms)"},
    {Key = "AutoAskLeaves", Title = "Auto Ask To Leaves"},
}
for _, t in ipairs(creepToggles) do
    PlayerTab:Toggle({
        Title = t.Title,
        Value = CreepsModule.Settings[t.Key] or false,
        Callback = function(v)
            CreepsModule.Settings[t.Key] = v
            ConfigSystem:Set("Creep." .. t.Key, v)
            local any = false
            for _, t2 in ipairs(creepToggles) do
                if CreepsModule.Settings[t2.Key] then any = true break end
            end
            if any then CreepsModule:Start() else CreepsModule:Stop() end
        end,
    })
end

-- =========================
-- ABA: MISC
-- =========================
local MiscTab = Window:Tab({Title = "Misc", Icon = "layers"})

MiscTab:Section({Title = "Anti-AFK"})
MiscTab:Toggle({
    Title = "Ativar Anti-AFK",
    Value = false,
    Callback = function(v) if v then AntiAFK:Enable() else AntiAFK:Disable() end end,
})
MiscTab:Paragraph({
    Title = "Sobre",
    Desc  = "Mantem o personagem ativo pra nao ser kickado por inatividade.",
})

MiscTab:Section({Title = "Rejoin / Serverhop"})
local jobIdValue = ""
MiscTab:Input({
    Title = "JobID",
    Value = "",
    Placeholder = "Cole o JobID aqui",
    Callback = function(v) jobIdValue = v end,
})
MiscTab:Button({Title = "Copy JobID",   Callback = function() RejoinModule:CopyJobId() end})
MiscTab:Button({Title = "Join JobID",   Callback = function() RejoinModule:JoinJobId(jobIdValue) end})
MiscTab:Button({Title = "Server Hop",   Callback = function() RejoinModule:ServerHop() end})
MiscTab:Button({Title = "Rejoin",       Callback = function() RejoinModule:Rejoin() end})

MiscTab:Section({Title = "FPS Boost"})
MiscTab:Toggle({
    Title = "FPS Boost",
    Value = FPSModule.Settings.FPSBoost,
    Callback = function(v)
        FPSModule.Settings.FPSBoost = v
        ConfigSystem:Set("FPS.Boost", v)
        if v then FPSModule:Apply() else FPSModule:Restore() end
    end,
})
MiscTab:Toggle({
    Title = "Disable 3D (low quality)",
    Value = FPSModule.Settings.Disable3D,
    Callback = function(v)
        FPSModule.Settings.Disable3D = v
        ConfigSystem:Set("FPS.Disable3D", v)
        FPSModule:Apply()
    end,
})

MiscTab:Section({Title = "Shop"})
MiscTab:Dropdown({
    Title  = "Item",
    Values = SHOP_ITEMS,
    Value  = ShopModule.Settings.SelectedItem,
    Callback = function(v)
        ShopModule.Settings.SelectedItem = v
        ConfigSystem:Set("Shop.Item", v)
    end,
})
MiscTab:Toggle({
    Title = "Auto Buy",
    Value = ShopModule.Settings.AutoBuy,
    Callback = function(v)
        ShopModule.Settings.AutoBuy = v
        ConfigSystem:Set("Shop.AutoBuy", v)
        if v then ShopModule:Start() else ShopModule:Stop() end
    end,
})
MiscTab:Button({
    Title = "Comprar Agora",
    Callback = function()
        local ok = BuyShopItem(ShopModule.Settings.SelectedItem)
        UI:Notify("Shop",
            ok and ("Tentou comprar: " .. ShopModule.Settings.SelectedItem) or "Falha ao comprar.",
            3, ok and "success" or "error")
    end,
})

-- =========================
-- ABA: SETTINGS
-- =========================
local SettingsTab = Window:Tab({Title = "Settings", Icon = "settings"})

SettingsTab:Section({Title = "Config Save/Load"})
SettingsTab:Input({
    Title = "Nome do config",
    Value = "default",
    Placeholder = "ex: meuSetup",
    Callback = function(v) ConfigSystem.File = "SolixHub_" .. v .. ".json" end,
})
SettingsTab:Button({
    Title = "Salvar Config",
    Callback = function()
        if ConfigSystem:Save() then
            UI:Notify("Config", "Salvo em " .. ConfigSystem.File, 3, "success")
        else
            UI:Notify("Config", "Falha ao salvar (sem permissao de escrita).", 3, "error")
        end
    end,
})
SettingsTab:Button({
    Title = "Carregar Config",
    Callback = function()
        if ConfigSystem:Load() then
            UI:Notify("Config", "Carregado!", 3, "success")
        else
            UI:Notify("Config", "Arquivo nao encontrado.", 3, "warning")
        end
    end,
})

SettingsTab:Section({Title = "Auto Save"})
SettingsTab:Paragraph({
    Title = "Sobre",
    Desc  = "Suas preferencias ja sao salvas automaticamente (com debounce de 1s) sempre que voce mexe num toggle/slider/input.",
})

SettingsTab:Section({Title = "Reset"})
SettingsTab:Button({
    Title = "Resetar TUDO (padrao)",
    Callback = function()
        ConfigSystem.Data = {}
        pcall(function() writefile(ConfigSystem.File, HttpService:JSONEncode({})) end)
        UI:Notify("Config", "Reset feito. Re-execute o script para aplicar.", 3, "warning")
    end,
})

-- =========================
-- ABA: SOBRE
-- =========================
local SobreTab = Window:Tab({Title = "Sobre", Icon = "info"})

SobreTab:Paragraph({
    Title = "Solix Hub — Receptionist V4",
    Desc  = "Versao 4.0 — totalmente reescrito do zero.\n"
         .. "UI: WindUI\n"
         .. "Autor: FelzpSystem\n\n"
         .. "Modulos: Secretaria, Shop, Play, Shifts, Taser, Coffee, Carry, "
         .. "Emergency, Sanity, Creeps, ESP, Highlights, FPS, Player, Camera, "
         .. "Rejoin, Anti-AFK, Config.",
})
SobreTab:Paragraph({
    Title = "Novidades da V4",
    Desc  = "- 6 abas separadas (Principal / Visual / Player / Misc / Settings / Sobre)\n"
         .. "- Todos os bugs da V3 corrigidos\n"
         .. "- Notify nunca mais quebra (multiplas APIs com fallback)\n"
         .. "- Noclip via RunService.Stepped (sem flood de chamadas)\n"
         .. "- Fire Strat restrito ao Rooms (nao apaga decoracao do mapa)\n"
         .. "- AutoShift so dispara RemoteEvents certos (start+shift)\n"
         .. "- ESP com limite de distancia e cleanup automatico\n"
         .. "- Config com debounce de 1s",
})
SobreTab:Paragraph({
    Title = "Comunidade",
    Desc  = "Atualizacoes e suporte:",
    Buttons = {
        {Title = "Copiar WhatsApp", Variant = "Primary",
         Callback = function()
             pcall(function() setclipboard("https://chat.whatsapp.com/COLOQUE_SEU_LINK_AQUI") end)
             UI:Notify("WhatsApp", "Link copiado!", 3, "success")
         end},
        {Title = "Copiar Discord", Variant = "Primary",
         Callback = function()
             pcall(function() setclipboard("https://discord.gg/COLOQUE_SEU_LINK_AQUI") end)
             UI:Notify("Discord", "Link copiado!", 3, "success")
         end},
    },
})

--------------------------------------------------------------------------------
-- 28) EXPORT _G + LOG
--------------------------------------------------------------------------------
_G.SolixHub = {
    Version = "4.0",
    Window           = Window,
    WindUI           = WindUI,
    HighlightSystem  = HighlightSystem,
    ConfigSystem     = ConfigSystem,
    Secretaria       = SecretariaModule,
    Shop             = ShopModule,
    Info             = InfoModule,
    Play             = PlayModule,
    Shifts           = ShiftModule,
    Taser            = TaserModule,
    Coffee           = CoffeeModule,
    Carry            = CarryModule,
    Emergency        = EmergencyModule,
    Sanity           = SanityModule,
    Creeps           = CreepsModule,
    ESP              = ESPModule,
    FPS              = FPSModule,
    Player           = PlayerModule,
    Camera           = CameraModule,
    Rejoin           = RejoinModule,
    AntiAFK          = AntiAFK,
    AudioURL         = AudioURL,
    IconURL          = IconURL,
    StartSecretaria  = function() SecretariaModule:Start() end,
    StopSecretaria   = function() SecretariaModule:Stop() end,
}
_G.RS = _G.SolixHub
_G.ReceptionistScript = _G.SolixHub  -- retro-compat

task.spawn(function()
    print("================================================")
    print("SOLIX HUB — RECEPTIONIST V4 CARREGADO")
    print("UI: WindUI  |  Versao: 4.0")
    print("Aba 'Player' > Secretaria para auto-atendimento")
    print("Use _G.RS para acessar modulos via script")
    print("================================================")
end)

return _G.SolixHub
