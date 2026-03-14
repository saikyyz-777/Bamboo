-- Build a Bamboo Factory Hub v2.5
-- AutoCollect | AutoBuy | AutoCash | Config | Rebirth
-- v2.5: Aba Rebirth integrada nativamente (manual + auto + contador)
-- FIX: preset agora salva/carrega estado do toggle AutoRebirth

local TweenService     = game:GetService("TweenService")
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local HttpService      = game:GetService("HttpService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local character = player.Character or player.CharacterAdded:Wait()
local hrp       = character:WaitForChild("HumanoidRootPart")
local humanoid  = character:WaitForChild("Humanoid")

-- ════════════════════════════════════════════════════════════════
-- STATE
-- ════════════════════════════════════════════════════════════════
local tpwalkSpeed    = 80
local jpower         = 110
local infJumpEnabled = false
local antiAfkEnabled = false

-- ════════════════════════════════════════════════════════════════
-- BRIDGE GLOBAL: expoe estado do Rebirth para presets
-- ════════════════════════════════════════════════════════════════
_G._BFHub_RebirthState = { enabled = false, start = nil, stop = nil }

-- ════════════════════════════════════════════════════════════════
-- SAVE / LOAD GERAL
-- ════════════════════════════════════════════════════════════════
local SAVE_FILE_AUTOBUY  = "drhub_autobuy.txt"
local SAVE_FILE_SETTINGS = "drhub_settings.txt"
local PROFILES_FILE      = "drhub_profiles.json"
local AUTOLOAD_FILE      = "drhub_autoload.txt"
local REBIRTH_SAVE       = "drhub_rebirth.json"

local function saveSettings(s)
    pcall(function()
        local lines = {}
        for k, v in pairs(s) do table.insert(lines, k.."="..tostring(v)) end
        writefile(SAVE_FILE_SETTINGS, table.concat(lines, "\n"))
    end)
end
local function loadSettings()
    local ok, data = pcall(function() return readfile(SAVE_FILE_SETTINGS) end)
    if not ok or not data or data == "" then return {} end
    local s = {}
    for line in data:gmatch("[^\n]+") do
        local k, v = line:match("^(.-)=(.+)$")
        if k and v then s[k] = v end
    end
    return s
end
local savedSettings = loadSettings()

local function saveAutoload(name)
    pcall(function()
        if name and name ~= "" then
            writefile(AUTOLOAD_FILE, name)
        else
            if isfile and isfile(AUTOLOAD_FILE) then writefile(AUTOLOAD_FILE, "") end
        end
    end)
end
local function loadAutoload()
    if not (isfile and readfile) then return nil end
    if isfile(AUTOLOAD_FILE) then
        local ok, data = pcall(function() return readfile(AUTOLOAD_FILE) end)
        if ok and data then
            local name = data:match("^%s*(.-)%s*$")
            return (name ~= "") and name or nil
        end
    end
    return nil
end

-- ════════════════════════════════════════════════════════════════
-- REBIRTH SAVE
-- ════════════════════════════════════════════════════════════════
local rebirthData = { delay = 5, targetCount = 0, totalDone = 0 }
local function saveRebirthData()
    pcall(function() writefile(REBIRTH_SAVE, HttpService:JSONEncode(rebirthData)) end)
end
local function loadRebirthData()
    if not (isfile and readfile) then return end
    if isfile(REBIRTH_SAVE) then
        local ok, res = pcall(function() return HttpService:JSONDecode(readfile(REBIRTH_SAVE)) end)
        if ok and res then
            rebirthData.delay       = tonumber(res.delay)       or 5
            rebirthData.targetCount = tonumber(res.targetCount) or 0
            rebirthData.totalDone   = tonumber(res.totalDone)   or 0
        end
    end
end
loadRebirthData()

-- ════════════════════════════════════════════════════════════════
-- PROFILE SYSTEM
-- ════════════════════════════════════════════════════════════════
local ProfileSystem = { profiles = {}, currentProfile = "Default" }
function ProfileSystem:save()
    pcall(function() writefile(PROFILES_FILE, HttpService:JSONEncode(self.profiles)) end)
end
function ProfileSystem:load()
    if not (isfile and readfile) then return end
    if isfile(PROFILES_FILE) then
        local ok, res = pcall(function() return HttpService:JSONDecode(readfile(PROFILES_FILE)) end)
        if ok and res then self.profiles = res end
    end
end
function ProfileSystem:createProfile(name)
    if self.profiles[name] then return false end
    self.profiles[name] = {
        tpwalkSpeed=80, jpower=110, infJumpEnabled=false,
        collectDelay=4.25, buyDelay=0.1, cashDelay=10, autoBuyItems={},
        autoCollectEnabled=false, autoBuyEnabled=false, autoCashEnabled=false,
        autoRebirthEnabled=false,
    }
    self:save(); return true
end
function ProfileSystem:saveCurrentProfile(data)
    self.profiles[self.currentProfile] = data; self:save()
end
function ProfileSystem:loadProfile(name)
    if not self.profiles[name] then return nil end
    self.currentProfile = name; return self.profiles[name]
end
function ProfileSystem:deleteProfile(name)
    if name == "Default" or not self.profiles[name] then return false end
    self.profiles[name] = nil
    if self.currentProfile == name then self.currentProfile = "Default" end
    self:save(); return true
end
function ProfileSystem:getNames()
    local n = {}
    for k in pairs(self.profiles) do table.insert(n, k) end
    table.sort(n); return n
end
ProfileSystem:load()
if not ProfileSystem.profiles["Default"] then ProfileSystem:createProfile("Default") end

-- ════════════════════════════════════════════════════════════════
-- PALETA
-- ════════════════════════════════════════════════════════════════
local C = {
    bg_dark       = Color3.fromRGB(16,16,28),
    bg_card       = Color3.fromRGB(28,28,46),
    bg_input      = Color3.fromRGB(18,18,32),
    bg_deep       = Color3.fromRGB(10,10,18),
    accent_blue   = Color3.fromRGB(80,160,255),
    accent_cyan   = Color3.fromRGB(60,220,210),
    accent_purple = Color3.fromRGB(160,80,255),
    accent_gold   = Color3.fromRGB(255,200,60),
    accent_green  = Color3.fromRGB(60,220,120),
    accent_red    = Color3.fromRGB(255,70,90),
    accent_orange = Color3.fromRGB(255,140,50),
    text_white    = Color3.fromRGB(255,255,255),
    text_dim      = Color3.fromRGB(160,160,190),
    text_muted    = Color3.fromRGB(90,90,120),
    border_glow   = Color3.fromRGB(60,100,200),
    border_dim    = Color3.fromRGB(40,40,65),
    on_color      = Color3.fromRGB(40,200,110),
    off_color     = Color3.fromRGB(200,50,70),
}

-- ════════════════════════════════════════════════════════════════
-- HELPERS TWEEN
-- ════════════════════════════════════════════════════════════════
local function tw(obj, props, t, style, dir)
    TweenService:Create(obj, TweenInfo.new(t or 0.3, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props):Play()
end
local function tweenBack(obj, props, t)
    local tween = TweenService:Create(obj, TweenInfo.new(t or 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), props)
    tween:Play(); return tween
end
local function tweenSine(obj, props, t)   tw(obj, props, t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut) end
local function tweenBounce(obj, props, t) tw(obj, props, t, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out) end

local function addStroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke", parent)
    s.Color = color or C.border_dim; s.Thickness = thickness or 1; s.Transparency = transparency or 0
    return s
end
local function addRipple(button)
    button.MouseButton1Click:Connect(function()
        local r = Instance.new("Frame", button)
        r.AnchorPoint = Vector2.new(0.5,0.5); r.Size = UDim2.new(0,0,0,0)
        r.Position = UDim2.new(0.5,0,0.5,0); r.BackgroundColor3 = Color3.fromRGB(255,255,255)
        r.BackgroundTransparency = 0.7; r.BorderSizePixel = 0; r.ZIndex = button.ZIndex + 5
        Instance.new("UICorner", r).CornerRadius = UDim.new(1,0)
        local sz = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) * 2.5
        tw(r, {Size=UDim2.new(0,sz,0,sz), BackgroundTransparency=1}, 0.5)
        task.delay(0.5, function() if r and r.Parent then r:Destroy() end end)
    end)
end

-- ════════════════════════════════════════════════════════════════
-- TAMANHO
-- ════════════════════════════════════════════════════════════════
local vp    = workspace.CurrentCamera.ViewportSize
local HUB_W = math.min(460, vp.X - 40)
local HUB_H = math.min(560, vp.Y - 80)

-- ════════════════════════════════════════════════════════════════
-- SCREEN GUI
-- ════════════════════════════════════════════════════════════════
local screenGui = Instance.new("ScreenGui", playerGui)
screenGui.Name           = "BFHub"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true

-- ════════════════════════════════════════════════════════════════
-- TELA DE CARREGAMENTO
-- ════════════════════════════════════════════════════════════════
local loadScreen = Instance.new("Frame", screenGui)
loadScreen.Size = UDim2.new(1,0,1,0)
loadScreen.BackgroundColor3 = Color3.fromRGB(6,6,14)
loadScreen.BorderSizePixel = 0; loadScreen.ZIndex = 1000
do local g=Instance.new("UIGradient",loadScreen); g.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(10,10,24)),ColorSequenceKeypoint.new(1,Color3.fromRGB(4,4,10))}; g.Rotation=135 end

local function spawnParticle()
    local p = Instance.new("Frame", loadScreen)
    local sz = math.random(2, 5)
    p.Size = UDim2.new(0, sz, 0, sz)
    p.Position = UDim2.new(math.random() * 0.9 + 0.05, 0, 1.05, 0)
    p.BackgroundColor3 = ({C.accent_green, C.accent_cyan, C.accent_blue})[math.random(1,3)]
    p.BackgroundTransparency = math.random(30,60)/100
    p.BorderSizePixel = 0; p.ZIndex = 1001
    Instance.new("UICorner", p).CornerRadius = UDim.new(1, 0)
    local duration = math.random(25, 50)/10
    tw(p, {Position = UDim2.new(p.Position.X.Scale, 0, -0.05, 0), BackgroundTransparency = 1}, duration, Enum.EasingStyle.Linear)
    task.delay(duration, function() if p and p.Parent then p:Destroy() end end)
end
local particleActive = true
task.spawn(function()
    while particleActive and loadScreen.Parent do
        spawnParticle(); task.wait(math.random(10, 25)/100)
    end
end)

local lsLogoF = Instance.new("Frame", loadScreen)
lsLogoF.Size = UDim2.new(0,100,0,100); lsLogoF.AnchorPoint = Vector2.new(0.5,0.5)
lsLogoF.Position = UDim2.new(0.5,0,0.5,-60)
lsLogoF.BackgroundColor3 = C.accent_green; lsLogoF.BackgroundTransparency = 0.7
lsLogoF.BorderSizePixel = 0; lsLogoF.ZIndex = 1001
Instance.new("UICorner", lsLogoF).CornerRadius = UDim.new(0,24)
addStroke(lsLogoF, C.accent_green, 2, 0.2)
local lsLogoI = Instance.new("TextLabel", lsLogoF)
lsLogoI.Size = UDim2.new(1,0,1,0); lsLogoI.BackgroundTransparency = 1
lsLogoI.Text = "[BF]"; lsLogoI.Font = Enum.Font.GothamBold
lsLogoI.TextSize = 36; lsLogoI.TextColor3 = C.accent_green; lsLogoI.ZIndex = 1002

local lsTitle = Instance.new("TextLabel", loadScreen)
lsTitle.Size = UDim2.new(0,400,0,40); lsTitle.AnchorPoint = Vector2.new(0.5,0.5)
lsTitle.Position = UDim2.new(0.5,0,0.5,18); lsTitle.BackgroundTransparency = 1
lsTitle.Text = "Build a Bamboo Factory Hub"; lsTitle.TextTransparency = 1; lsTitle.Font = Enum.Font.GothamBold
lsTitle.TextSize = 26; lsTitle.TextColor3 = C.text_white; lsTitle.ZIndex = 1001
do local g=Instance.new("UIGradient",lsTitle); g.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(60,220,120)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(255,255,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(60,220,210))} end

local lsVer = Instance.new("TextLabel", loadScreen)
lsVer.Size = UDim2.new(0,300,0,22); lsVer.AnchorPoint = Vector2.new(0.5,0.5)
lsVer.Position = UDim2.new(0.5,0,0.5,46); lsVer.BackgroundTransparency = 1
lsVer.Text = "v2.5  |  AutoCollect | AutoBuy | AutoCash | Rebirth"; lsVer.TextTransparency = 1
lsVer.Font = Enum.Font.Gotham; lsVer.TextSize = 13; lsVer.TextColor3 = C.text_muted; lsVer.ZIndex = 1001

local lsBar
do
    local lsBarBg = Instance.new("Frame", loadScreen)
    lsBarBg.Size = UDim2.new(0,320,0,6); lsBarBg.AnchorPoint = Vector2.new(0.5,0.5)
    lsBarBg.Position = UDim2.new(0.5,0,0.5,90)
    lsBarBg.BackgroundColor3 = Color3.fromRGB(25,25,45); lsBarBg.BorderSizePixel = 0; lsBarBg.ZIndex = 1001
    Instance.new("UICorner", lsBarBg).CornerRadius = UDim.new(1,0)
    lsBar = Instance.new("Frame", lsBarBg)
    lsBar.Size = UDim2.new(0,0,1,0); lsBar.BackgroundColor3 = C.accent_green
    lsBar.BorderSizePixel = 0; lsBar.ZIndex = 1002
    Instance.new("UICorner", lsBar).CornerRadius = UDim.new(1,0)
end

local lsStatus = Instance.new("TextLabel", loadScreen)
lsStatus.Size = UDim2.new(0,320,0,20); lsStatus.AnchorPoint = Vector2.new(0.5,0.5)
lsStatus.Position = UDim2.new(0.5,0,0.5,110); lsStatus.BackgroundTransparency = 1
lsStatus.Text = "Iniciando..."; lsStatus.Font = Enum.Font.Gotham
lsStatus.TextSize = 12; lsStatus.TextColor3 = C.text_dim; lsStatus.ZIndex = 1001

do
    local spinnerFrame = Instance.new("Frame", loadScreen)
    spinnerFrame.Size = UDim2.new(0,30,0,30); spinnerFrame.AnchorPoint = Vector2.new(0.5,0.5)
    spinnerFrame.Position = UDim2.new(0.5,0,0.5,140); spinnerFrame.BackgroundTransparency = 1; spinnerFrame.ZIndex = 1001
    local spinnerRing = Instance.new("Frame", spinnerFrame)
    spinnerRing.Size = UDim2.new(1,0,1,0); spinnerRing.BackgroundTransparency = 1; spinnerRing.BorderSizePixel = 0
    Instance.new("UICorner", spinnerRing).CornerRadius = UDim.new(0.5,0)
    addStroke(spinnerRing, C.accent_green, 3, 0)
    local spinnerGrad = Instance.new("UIGradient", spinnerRing)
    spinnerGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, C.accent_green), ColorSequenceKeypoint.new(0.5, C.accent_green),
        ColorSequenceKeypoint.new(0.51, Color3.new(0,0,0)), ColorSequenceKeypoint.new(1, Color3.new(0,0,0))
    }
    RunService.Heartbeat:Connect(function()
        if spinnerGrad and spinnerGrad.Parent then spinnerGrad.Rotation = (spinnerGrad.Rotation + 10) % 360 end
    end)
end
task.spawn(function()
    local originalSize = lsLogoF.Size
    while lsLogoI.Parent do
        tw(lsLogoF, {Size=UDim2.new(0,110,0,110), BackgroundTransparency=0.4}, 0.8, Enum.EasingStyle.Sine); task.wait(0.8)
        tw(lsLogoF, {Size=originalSize, BackgroundTransparency=0.75}, 0.8, Enum.EasingStyle.Sine); task.wait(0.8)
    end
end)

-- ════════════════════════════════════════════════════════════════
-- NOTIFICACOES
-- ════════════════════════════════════════════════════════════════
local notifStack = {}
local function getNotifIcon(col)
    if col == C.accent_green  then return "[OK]"
    elseif col == C.accent_red    then return "[!]"
    elseif col == C.accent_gold   then return "[$]"
    elseif col == C.accent_cyan   then return "[~]"
    elseif col == C.accent_purple then return "[*]"
    elseif col == C.accent_orange then return "[?]"
    else return "[i]" end
end
local function notify(title, msg, dur, col)
    col = col or C.accent_blue; dur = dur or 3
    for _, n in ipairs(notifStack) do tw(n, {Position=UDim2.new(1,-360,0,n.Position.Y.Offset-90)}, 0.3) end
    local f = Instance.new("Frame", screenGui)
    f.Size = UDim2.new(0,340,0,78); f.BackgroundColor3 = C.bg_card
    f.BorderSizePixel = 0; f.ZIndex = 2000; f.Position = UDim2.new(1,20,0,70); f.ClipsDescendants = true
    Instance.new("UICorner", f).CornerRadius = UDim.new(0,14)
    local bar = Instance.new("Frame", f)
    bar.Size = UDim2.new(0,4,1,0); bar.BackgroundColor3 = col; bar.BorderSizePixel = 0; bar.ZIndex = 2002
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0,4)
    local g2n = Instance.new("UIGradient", f)
    g2n.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(32,32,52)),ColorSequenceKeypoint.new(1,Color3.fromRGB(22,22,38))}; g2n.Rotation = 90
    local sk = addStroke(f, col, 1.5, 0.5)
    local iconCircle = Instance.new("Frame", f)
    iconCircle.Size = UDim2.new(0,32,0,32); iconCircle.Position = UDim2.new(0,10,0,10)
    iconCircle.BackgroundColor3 = col; iconCircle.BackgroundTransparency = 0.75; iconCircle.BorderSizePixel = 0; iconCircle.ZIndex = 2003
    Instance.new("UICorner", iconCircle).CornerRadius = UDim.new(1,0); addStroke(iconCircle, col, 1.5, 0.2)
    local iconLbl2 = Instance.new("TextLabel", iconCircle)
    iconLbl2.Size = UDim2.new(1,0,1,0); iconLbl2.BackgroundTransparency = 1
    iconLbl2.Text = getNotifIcon(col); iconLbl2.TextColor3 = col; iconLbl2.Font = Enum.Font.GothamBold; iconLbl2.TextSize = 11; iconLbl2.ZIndex = 2004
    local tl = Instance.new("TextLabel", f)
    tl.Size = UDim2.new(1,-52,0,24); tl.Position = UDim2.new(0,48,0,8)
    tl.BackgroundTransparency = 1; tl.Text = title; tl.TextColor3 = C.text_white
    tl.Font = Enum.Font.GothamBold; tl.TextSize = 15; tl.TextXAlignment = Enum.TextXAlignment.Left; tl.ZIndex = 2002
    local ml = Instance.new("TextLabel", f)
    ml.Size = UDim2.new(1,-52,0,30); ml.Position = UDim2.new(0,48,0,34)
    ml.BackgroundTransparency = 1; ml.Text = msg; ml.TextColor3 = C.text_dim
    ml.Font = Enum.Font.Gotham; ml.TextSize = 12; ml.TextWrapped = true; ml.TextXAlignment = Enum.TextXAlignment.Left; ml.ZIndex = 2002
    local pb = Instance.new("Frame", f)
    pb.Size = UDim2.new(1,0,0,3); pb.Position = UDim2.new(0,0,1,-3)
    pb.BackgroundColor3 = C.bg_deep; pb.BorderSizePixel = 0; pb.ZIndex = 2002
    local pf = Instance.new("Frame", pb)
    pf.Size = UDim2.new(1,0,1,0); pf.BackgroundColor3 = col; pf.BorderSizePixel = 0; pf.ZIndex = 2003
    Instance.new("UICorner", pf).CornerRadius = UDim.new(0,2)
    table.insert(notifStack, f)
    tweenBack(f, {Position=UDim2.new(1,-360,0,70)}, 0.45)
    tw(sk, {Transparency=0}, 0.3)
    tw(pf, {Size=UDim2.new(0,0,1,0)}, dur, Enum.EasingStyle.Linear)
    task.delay(dur, function()
        local idx = table.find(notifStack, f); if idx then table.remove(notifStack, idx) end
        tw(f, {Position=UDim2.new(1,20,0,f.Position.Y.Offset)}, 0.35)
        tw(f, {BackgroundTransparency=1}, 0.35)
        task.wait(0.35); if f and f.Parent then f:Destroy() end
    end)
end

-- ════════════════════════════════════════════════════════════════
-- GLOWS
-- ════════════════════════════════════════════════════════════════
local function makeGlow(sz, off, col, trans)
    local g = Instance.new("Frame", screenGui)
    g.AnchorPoint = Vector2.new(0.5,0.5)
    g.Size = UDim2.new(0,HUB_W+sz,0,HUB_H+sz); g.Position = UDim2.new(0.5,0,0.5,off+15)
    g.BackgroundColor3 = col; g.BackgroundTransparency = trans
    g.BorderSizePixel = 0; g.ZIndex = 0; g.Visible = false
    Instance.new("UICorner", g).CornerRadius = UDim.new(0,20)
    return g
end
local g1  = makeGlow(8,  2, Color3.fromRGB(30,120,80),  0.72)
local g2_ = makeGlow(22, 4, Color3.fromRGB(20,100,60),  0.84)
local g3  = makeGlow(40, 6, Color3.fromRGB(15,80,50),   0.90)
local allGlows = {g1, g2_, g3}

-- ════════════════════════════════════════════════════════════════
-- MAIN FRAME
-- ════════════════════════════════════════════════════════════════
local mainFrame = Instance.new("Frame", screenGui)
mainFrame.AnchorPoint = Vector2.new(0.5,0.5); mainFrame.Size = UDim2.new(0,0,0,0)
mainFrame.Position = UDim2.new(0.5,0,0.5,0); mainFrame.BackgroundColor3 = C.bg_dark
mainFrame.BorderSizePixel = 0; mainFrame.ClipsDescendants = true; mainFrame.ZIndex = 1; mainFrame.Visible = false
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0,18)
local mainStroke = addStroke(mainFrame, C.border_glow, 2, 0)
do local g=Instance.new("UIGradient",mainFrame); g.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(18,18,32)),ColorSequenceKeypoint.new(1,Color3.fromRGB(10,10,20))}; g.Rotation=135 end

local mainStrokeGlowActive = false
local mainStrokeCurrentColor = C.border_glow
task.spawn(function()
    while mainStroke.Parent do
        if mainStrokeGlowActive then
            tweenSine(mainStroke, {Transparency=0.5, Color=mainStrokeCurrentColor}, 1.2); task.wait(1.2)
            tweenSine(mainStroke, {Transparency=0,   Color=mainStrokeCurrentColor}, 1.2); task.wait(1.2)
        else task.wait(0.5) end
    end
end)

local function syncGlows()
    local p = mainFrame.Position
    g1.Position  = UDim2.new(p.X.Scale,p.X.Offset,p.Y.Scale,p.Y.Offset+8)
    g2_.Position = UDim2.new(p.X.Scale,p.X.Offset,p.Y.Scale,p.Y.Offset+12)
    g3.Position  = UDim2.new(p.X.Scale,p.X.Offset,p.Y.Scale,p.Y.Offset+18)
end

-- ════════════════════════════════════════════════════════════════
-- DRAG
-- ════════════════════════════════════════════════════════════════
local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
local glowDirty = false
RunService.Heartbeat:Connect(function()
    if glowDirty then syncGlows(); glowDirty = false end
end)

-- ════════════════════════════════════════════════════════════════
-- TITULO
-- ════════════════════════════════════════════════════════════════
local titleBar = Instance.new("Frame", mainFrame)
titleBar.Size = UDim2.new(1,0,0,62); titleBar.BackgroundColor3 = Color3.fromRGB(14,14,28)
titleBar.BorderSizePixel = 0; titleBar.ZIndex = 10
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0,18)
do
    local g=Instance.new("UIGradient",titleBar)
    g.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(12,40,22)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(14,26,18)),ColorSequenceKeypoint.new(1,Color3.fromRGB(14,14,28))}; g.Rotation=90
    local s=Instance.new("Frame",titleBar); s.Size=UDim2.new(0.6,0,0,1); s.Position=UDim2.new(0.2,0,1,-2)
    s.BackgroundColor3=C.accent_green; s.BackgroundTransparency=0.4; s.BorderSizePixel=0; s.ZIndex=12
    local sg=Instance.new("UIGradient",s); sg.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(0,0,0)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(255,255,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(0,0,0))}
end

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        dragging=true; dragStart=input.Position; startPos=mainFrame.Position
        input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then dragging=false end end)
    end
end)
titleBar.InputChanged:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then dragInput=input end
end)
UserInputService.InputChanged:Connect(function(input)
    if input==dragInput and dragging then
        local d = input.Position - dragStart
        local ss = workspace.CurrentCamera.ViewportSize
        local abs = mainFrame.AbsoluteSize; local anch = abs * mainFrame.AnchorPoint
        local rx = math.clamp(startPos.X.Offset+d.X, anch.X+5, ss.X-abs.X+anch.X-5)
        local ry = math.clamp(startPos.Y.Offset+d.Y, anch.Y+5, ss.Y-abs.Y+anch.Y-5)
        tw(mainFrame, {Position=UDim2.new(0,rx,0,ry)}, 0.06); glowDirty = true
    end
end)

do
    local lf=Instance.new("Frame",titleBar); lf.Size=UDim2.new(0,44,0,44); lf.Position=UDim2.new(0,10,0,9)
    lf.BackgroundColor3=C.accent_green; lf.BackgroundTransparency=0.75; lf.BorderSizePixel=0; lf.ZIndex=11
    Instance.new("UICorner",lf).CornerRadius=UDim.new(0,12); addStroke(lf,C.accent_green,1.5,0.3)
    local li=Instance.new("TextLabel",lf); li.Size=UDim2.new(1,0,1,0); li.BackgroundTransparency=1
    li.Text="[BF]"; li.TextColor3=C.accent_green; li.Font=Enum.Font.GothamBold; li.TextSize=16; li.ZIndex=12
    local tl=Instance.new("TextLabel",titleBar); tl.Size=UDim2.new(1,-160,0,28); tl.Position=UDim2.new(0,62,0,8)
    tl.BackgroundTransparency=1; tl.Text="Build a Bamboo Factory"; tl.TextColor3=C.text_white
    tl.Font=Enum.Font.GothamBold; tl.TextSize=20; tl.TextXAlignment=Enum.TextXAlignment.Left; tl.ZIndex=11
    local tg=Instance.new("UIGradient",tl); tg.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(60,220,120)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(255,255,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(60,220,210))}
    local vl=Instance.new("TextLabel",titleBar); vl.Size=UDim2.new(0,200,0,18); vl.Position=UDim2.new(0,62,0,38)
    vl.BackgroundTransparency=1; vl.Text="v2.5  |  BambooFactory Edition"
    vl.TextColor3=C.text_muted; vl.Font=Enum.Font.Gotham; vl.TextSize=11; vl.TextXAlignment=Enum.TextXAlignment.Left; vl.ZIndex=11
    local ob=Instance.new("Frame",titleBar); ob.Size=UDim2.new(0,66,0,20); ob.Position=UDim2.new(0,270,0,38)
    ob.BackgroundColor3=C.accent_green; ob.BackgroundTransparency=0.6; ob.BorderSizePixel=0; ob.ZIndex=11
    Instance.new("UICorner",ob).CornerRadius=UDim.new(1,0)
    local ol=Instance.new("TextLabel",ob); ol.Size=UDim2.new(1,0,1,0); ol.BackgroundTransparency=1
    ol.Text="ONLINE"; ol.TextColor3=C.accent_green; ol.Font=Enum.Font.GothamBold; ol.TextSize=10; ol.ZIndex=12
end

local minimizeBtn = Instance.new("TextButton", titleBar)
minimizeBtn.Size = UDim2.new(0,34,0,30); minimizeBtn.Position = UDim2.new(1,-44,0,16)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(60,60,90); minimizeBtn.BackgroundTransparency = 0.3
minimizeBtn.Text = "-"; minimizeBtn.TextColor3 = C.text_white; minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 16; minimizeBtn.BorderSizePixel = 0; minimizeBtn.ZIndex = 13
Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0,9); addRipple(minimizeBtn)
minimizeBtn.MouseEnter:Connect(function() tw(minimizeBtn,{BackgroundTransparency=0},0.2) end)
minimizeBtn.MouseLeave:Connect(function() tw(minimizeBtn,{BackgroundTransparency=0.3},0.2) end)

-- ════════════════════════════════════════════════════════════════
-- BOTAO RESTAURAR
-- ════════════════════════════════════════════════════════════════
local restoreBtn = Instance.new("Frame", screenGui)
restoreBtn.Name = "RestoreBtn"; restoreBtn.Size = UDim2.new(0,55,0,55); restoreBtn.Position = UDim2.new(1,-70,0,80)
restoreBtn.BackgroundColor3 = C.bg_dark; restoreBtn.BorderSizePixel = 0; restoreBtn.Visible = false; restoreBtn.ZIndex = 1000; restoreBtn.Active = true
Instance.new("UICorner", restoreBtn).CornerRadius = UDim.new(1,0)
addStroke(restoreBtn, C.accent_green, 2.5, 0.2)
local restoreGlow = Instance.new("ImageLabel", restoreBtn)
restoreGlow.Size = UDim2.new(1.8,0,1.8,0); restoreGlow.Position = UDim2.new(-0.4,0,-0.4,0)
restoreGlow.BackgroundTransparency = 1; restoreGlow.Image = "rbxassetid://5028857084"
restoreGlow.ImageColor3 = C.accent_green; restoreGlow.ImageTransparency = 0.85; restoreGlow.ZIndex = 999
local restoreIcon = Instance.new("TextLabel", restoreBtn)
restoreIcon.Size = UDim2.new(1,0,1,0); restoreIcon.BackgroundTransparency = 1
restoreIcon.Text = "+"; restoreIcon.TextColor3 = C.accent_green; restoreIcon.TextSize = 36; restoreIcon.Font = Enum.Font.GothamBlack; restoreIcon.ZIndex = 1001
local restoreClick = Instance.new("TextButton", restoreBtn)
restoreClick.Size = UDim2.new(1,0,1,0); restoreClick.BackgroundTransparency = 1; restoreClick.Text = ""; restoreClick.ZIndex = 1002
addRipple(restoreClick)
restoreClick.MouseEnter:Connect(function() tw(restoreBtn,{BackgroundColor3=C.bg_card},0.2); tw(restoreIcon,{TextColor3=C.text_white},0.2) end)
restoreClick.MouseLeave:Connect(function() tw(restoreBtn,{BackgroundColor3=C.bg_dark},0.2); tw(restoreIcon,{TextColor3=C.accent_green},0.2) end)
local glowPulseActive = false
task.spawn(function()
    while restoreBtn.Parent do
        if glowPulseActive then
            tweenSine(restoreGlow,{ImageTransparency=0.65},1.2); task.wait(1.2)
            tweenSine(restoreGlow,{ImageTransparency=0.88},1.2); task.wait(1.2)
        else task.wait(0.4) end
    end
end)

-- ════════════════════════════════════════════════════════════════
-- MINIMIZAR / RESTAURAR
-- ════════════════════════════════════════════════════════════════
local function hideHub()
    tw(mainFrame,{BackgroundTransparency=0.3},0.08); task.wait(0.08)
    tw(mainFrame,{BackgroundTransparency=0},0.08); task.wait(0.1)
    TweenService:Create(mainFrame,TweenInfo.new(0.45,Enum.EasingStyle.Back,Enum.EasingDirection.In),{Size=UDim2.new(0,0,0,0),Position=UDim2.new(1,-70,0,80),Rotation=-15}):Play()
    for _,g in ipairs(allGlows) do TweenService:Create(g,TweenInfo.new(0.35,Enum.EasingStyle.Back,Enum.EasingDirection.In),{Size=UDim2.new(0,0,0,0)}):Play() end
    for _,v in ipairs(mainFrame:GetDescendants()) do pcall(function() if v:IsA("TextLabel") or v:IsA("TextButton") or v:IsA("TextBox") then tw(v,{TextTransparency=1},0.18) end end) end
    task.wait(0.45); mainFrame.Visible=false; mainFrame.Rotation=0
    for _,g in ipairs(allGlows) do g.Visible=false end; mainStrokeGlowActive=false
    restoreBtn.Visible=true; restoreBtn.Size=UDim2.new(0,0,0,0); restoreBtn.Rotation=-180; glowPulseActive=true
    TweenService:Create(restoreBtn,TweenInfo.new(0.5,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=UDim2.new(0,55,0,55),Rotation=0}):Play()
end
local function showHub()
    glowPulseActive=false
    TweenService:Create(restoreBtn,TweenInfo.new(0.3,Enum.EasingStyle.Back,Enum.EasingDirection.In),{Size=UDim2.new(0,0,0,0),Rotation=180}):Play()
    task.wait(0.28); restoreBtn.Visible=false; restoreBtn.Rotation=0
    for _,v in ipairs(mainFrame:GetDescendants()) do pcall(function() if v:IsA("TextLabel") or v:IsA("TextButton") or v:IsA("TextBox") then v.TextTransparency=0 end end) end
    mainFrame.Visible=true; mainFrame.Size=UDim2.new(0,0,0,0); mainFrame.Position=UDim2.new(0.5,0,0.5,0); mainFrame.Rotation=-15; mainStrokeGlowActive=true
    for _,g in ipairs(allGlows) do g.Visible=true; g.Size=UDim2.new(0,0,0,0) end
    TweenService:Create(mainFrame,TweenInfo.new(0.6,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=UDim2.new(0,HUB_W,0,HUB_H),Position=UDim2.new(0.5,0,0.5,0),Rotation=0}):Play()
    for i,g in ipairs(allGlows) do
        local e=(i-1)*14+8; TweenService:Create(g,TweenInfo.new(0.55,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=UDim2.new(0,HUB_W+e,0,HUB_H+e)}):Play(); task.wait(0.04)
    end
    syncGlows()
end
minimizeBtn.MouseButton1Click:Connect(hideHub)
restoreClick.MouseButton1Click:Connect(showHub)

-- ════════════════════════════════════════════════════════════════
-- CONTENT + ABAS
-- ════════════════════════════════════════════════════════════════
local contentFrame = Instance.new("Frame", mainFrame)
contentFrame.Size = UDim2.new(1,-16,1,-72); contentFrame.Position = UDim2.new(0,8,0,64)
contentFrame.BackgroundTransparency = 1; contentFrame.ClipsDescendants = true

local tabBar = Instance.new("Frame", contentFrame)
tabBar.Size = UDim2.new(1,0,0,40); tabBar.BackgroundColor3 = Color3.fromRGB(16,16,30); tabBar.BorderSizePixel = 0
Instance.new("UICorner",tabBar).CornerRadius = UDim.new(0,11); addStroke(tabBar,C.border_dim,1,0)
local tabLayout2 = Instance.new("UIListLayout", tabBar)
tabLayout2.FillDirection = Enum.FillDirection.Horizontal; tabLayout2.Padding = UDim.new(0,2)
tabLayout2.HorizontalAlignment = Enum.HorizontalAlignment.Center; tabLayout2.VerticalAlignment = Enum.VerticalAlignment.Center

local TAB_W = 84

local tabIndicator = Instance.new("Frame", contentFrame)
tabIndicator.Size = UDim2.new(0,TAB_W,0,30); tabIndicator.BackgroundColor3 = C.accent_green
tabIndicator.BackgroundTransparency = 0.8; tabIndicator.BorderSizePixel = 0; tabIndicator.ZIndex = 1
Instance.new("UICorner",tabIndicator).CornerRadius = UDim.new(0,8); addStroke(tabIndicator,C.accent_green,1,0.3)

local function makeScrollFrame(parent)
    local sf = Instance.new("ScrollingFrame", parent)
    sf.Size = UDim2.new(1,0,1,-48); sf.Position = UDim2.new(0,0,0,45)
    sf.BackgroundTransparency = 1; sf.ScrollBarThickness = 5; sf.ScrollBarImageColor3 = C.accent_green
    sf.BorderSizePixel = 0; sf.CanvasSize = UDim2.new(0,0,0,0); sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sf.ScrollingDirection = Enum.ScrollingDirection.Y; sf.ClipsDescendants = true; sf.Visible = false
    local layout = Instance.new("UIListLayout", sf)
    layout.Padding = UDim.new(0,8); layout.SortOrder = Enum.SortOrder.LayoutOrder
    local pad = Instance.new("UIPadding", sf)
    pad.PaddingTop = UDim.new(0,4); pad.PaddingBottom = UDim.new(0,10)
    pad.PaddingLeft = UDim.new(0,2); pad.PaddingRight = UDim.new(0,2)
    return sf
end

local collectFrame  = makeScrollFrame(contentFrame); collectFrame.Visible = true
local buyFrame      = makeScrollFrame(contentFrame)
local cashFrame     = makeScrollFrame(contentFrame)
local configFrame   = makeScrollFrame(contentFrame)
local rebirthFrame  = makeScrollFrame(contentFrame)

local TAB_COLS   = {C.accent_green, C.accent_gold, C.accent_cyan, C.accent_purple, C.accent_orange}
local TAB_FRAMES = {collectFrame, buyFrame, cashFrame, configFrame, rebirthFrame}
local ALL_TABS   = {}; local activeTab = nil

local function animateTabCards(scrollFrame)
    local children = {}
    for _, child in ipairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") or child:IsA("ScrollingFrame") then table.insert(children, child) end
    end
    for i, child in ipairs(children) do
        child.BackgroundTransparency = 1
        task.delay((i-1) * 0.045, function()
            if child and child.Parent then tw(child, {BackgroundTransparency = child:IsA("ScrollingFrame") and 1 or 0}, 0.25, Enum.EasingStyle.Quad) end
        end)
    end
end

local function switchTab(order)
    for _,f in ipairs(TAB_FRAMES) do f.Visible=false end
    for _,b in ipairs(ALL_TABS)   do tw(b,{TextColor3=C.text_dim},0.2) end
    TAB_FRAMES[order].Visible=true; tw(ALL_TABS[order],{TextColor3=C.text_white},0.2)
    activeTab=ALL_TABS[order]
    local tbw=tabBar.AbsoluteSize.X; local tot=5*TAB_W+4*2; local left=(tbw-tot)/2
    tw(tabIndicator,{Size=UDim2.new(0,TAB_W*0.7,0,30)},0.12,Enum.EasingStyle.Quad)
    task.delay(0.12, function()
        tw(tabIndicator,{Position=UDim2.new(0,left+(order-1)*(TAB_W+2),0,5)},0.28,Enum.EasingStyle.Back)
        tweenBack(tabIndicator,{Size=UDim2.new(0,TAB_W,0,30)},0.32)
    end)
    tw(tabIndicator,{BackgroundColor3=TAB_COLS[order]},0.3)
    local s=tabIndicator:FindFirstChildWhichIsA("UIStroke"); if s then tw(s,{Color=TAB_COLS[order]},0.3) end
    mainStrokeCurrentColor = TAB_COLS[order]
    tw(mainStroke,{Color=TAB_COLS[order]},0.4); tw(g1,{BackgroundColor3=TAB_COLS[order]},0.6)
    task.delay(0.05, function() animateTabCards(TAB_FRAMES[order]) end)
end

for _,def in ipairs({
    {"Collect","[C]",1},
    {"AutoBuy","[B]",2},
    {"AutoCash","[$]",3},
    {"Config","[S]",4},
    {"Rebirth","[R]",5},
}) do
    local nm,ic,ord = def[1],def[2],def[3]
    local btn = Instance.new("TextButton", tabBar)
    btn.Size = UDim2.new(0,TAB_W,0,30); btn.BackgroundColor3 = Color3.fromRGB(0,0,0); btn.BackgroundTransparency = 1
    btn.Text = ic.." "..nm; btn.TextColor3 = C.text_dim; btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11; btn.BorderSizePixel = 0; btn.ZIndex = 2
    Instance.new("UICorner",btn).CornerRadius = UDim.new(0,8); addRipple(btn)
    btn.MouseButton1Click:Connect(function() switchTab(ord) end)
    btn.MouseEnter:Connect(function() if btn~=activeTab then tw(btn,{TextColor3=Color3.fromRGB(200,200,230)},0.15) end end)
    btn.MouseLeave:Connect(function() if btn~=activeTab then tw(btn,{TextColor3=C.text_dim},0.15) end end)
    ALL_TABS[ord] = btn
end
ALL_TABS[1].TextColor3 = C.text_white; activeTab = ALL_TABS[1]
task.defer(function()
    local tbw=tabBar.AbsoluteSize.X; local tot=5*TAB_W+4*2; local left=(tbw-tot)/2
    tabIndicator.Position=UDim2.new(0,left,0,5)
end)

-- ════════════════════════════════════════════════════════════════
-- HELPERS DE CARD / TOGGLE
-- ════════════════════════════════════════════════════════════════
local function makeCard(parent, height, order)
    local c = Instance.new("Frame", parent)
    c.Size = UDim2.new(1,-6,0,height); c.BackgroundColor3 = C.bg_card
    c.BorderSizePixel = 0; c.LayoutOrder = order
    Instance.new("UICorner",c).CornerRadius = UDim.new(0,13)
    local s = addStroke(c,C.border_dim,1,0.5)
    c.MouseEnter:Connect(function() tw(s,{Transparency=0},0.15) end)
    c.MouseLeave:Connect(function() tw(s,{Transparency=0.5},0.15) end)
    return c
end

local function makeToggleCard(parent, labelText, icon, color, order)
    local card = makeCard(parent,54,order); local cs = card:FindFirstChildWhichIsA("UIStroke")
    local iconLbl = Instance.new("TextLabel",card)
    iconLbl.Size = UDim2.new(0,30,0,30); iconLbl.Position = UDim2.new(0,10,0,12)
    iconLbl.BackgroundTransparency = 1; iconLbl.Text = icon; iconLbl.Font = Enum.Font.GothamBold; iconLbl.TextSize = 14; iconLbl.TextColor3 = C.text_muted
    local lbl = Instance.new("TextLabel",card)
    lbl.Size = UDim2.new(0.6,0,1,0); lbl.Position = UDim2.new(0,46,0,0)
    lbl.BackgroundTransparency = 1; lbl.Text = labelText; lbl.TextColor3 = C.text_white
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 15; lbl.TextXAlignment = Enum.TextXAlignment.Left
    local track = Instance.new("Frame",card)
    track.Size = UDim2.new(0,64,0,30); track.Position = UDim2.new(1,-80,0,12)
    track.BackgroundColor3 = C.off_color; track.BackgroundTransparency = 0.25; track.BorderSizePixel = 0
    Instance.new("UICorner",track).CornerRadius = UDim.new(1,0)
    local knob = Instance.new("Frame",track)
    knob.Size = UDim2.new(0,24,0,24); knob.Position = UDim2.new(0,3,0,3)
    knob.BackgroundColor3 = C.text_white; knob.BorderSizePixel = 0
    Instance.new("UICorner",knob).CornerRadius = UDim.new(1,0)
    local clickBtn = Instance.new("TextButton",card)
    clickBtn.Size = UDim2.new(1,0,1,0); clickBtn.BackgroundTransparency = 1; clickBtn.Text = ""; clickBtn.ZIndex = 5; addRipple(clickBtn)
    local enabled = false
    local function updateVis()
        local col = enabled and color or C.off_color
        tw(track,{BackgroundColor3=col},0.25)
        tweenBack(knob,{Position=enabled and UDim2.new(1,-27,0,3) or UDim2.new(0,3,0,3)},0.3)
        iconLbl.TextColor3 = enabled and color or C.text_muted
        if cs then tw(cs,{Color=enabled and color or C.border_dim},0.25) end
    end
    return clickBtn, updateVis, function() return enabled end, function(v) enabled=v end
end

local function makeInputField(parent, labelText, defaultValue, accentColor, onChanged)
    local card = Instance.new("Frame", parent)
    card.Size = UDim2.new(1,-6,0,52); card.BackgroundColor3 = C.bg_card; card.BorderSizePixel = 0
    Instance.new("UICorner",card).CornerRadius = UDim.new(0,12)
    local cs = addStroke(card,accentColor,1,0.5)
    card.MouseEnter:Connect(function() tw(cs,{Transparency=0},0.15) end)
    card.MouseLeave:Connect(function() tw(cs,{Transparency=0.5},0.15) end)
    local lbl = Instance.new("TextLabel",card)
    lbl.Size = UDim2.new(1,-16,0,18); lbl.Position = UDim2.new(0,10,0,5)
    lbl.BackgroundTransparency = 1; lbl.Text = labelText; lbl.TextColor3 = accentColor
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 12; lbl.TextXAlignment = Enum.TextXAlignment.Left
    local box = Instance.new("TextBox",card)
    box.Size = UDim2.new(1,-16,0,24); box.Position = UDim2.new(0,8,0,22)
    box.BackgroundColor3 = C.bg_input; box.BorderSizePixel = 0; box.Text = tostring(defaultValue)
    box.TextColor3 = C.text_white; box.PlaceholderColor3 = C.text_muted
    box.Font = Enum.Font.GothamBold; box.TextSize = 13; box.ClearTextOnFocus = false
    Instance.new("UICorner",box).CornerRadius = UDim.new(0,7)
    local bs = addStroke(box,C.border_dim,1,0.3)
    box.Focused:Connect(function()  tw(bs,{Color=accentColor,Transparency=0},0.2); tw(box,{BackgroundColor3=Color3.fromRGB(22,22,42)},0.2) end)
    box.FocusLost:Connect(function() tw(bs,{Color=C.border_dim,Transparency=0.3},0.2); tw(box,{BackgroundColor3=C.bg_input},0.2); if onChanged then onChanged(box.Text) end end)
    return box, card
end

-- ════════════════════════════════════════════════════════════════
-- FORWARD DECLARATIONS
-- ════════════════════════════════════════════════════════════════
local collectDelay = tonumber(savedSettings["collect_delay"]) or 4.25
local buyDelay     = tonumber(savedSettings["buy_delay"])     or 0.1
local cashDelay    = tonumber(savedSettings["cash_delay"])    or 10

local collectDelayBox, buyDelayBox, cashDelayBox
local collectDelayRef, buyDelayRef, cashDelayRef
local tpwalkInputRef, jumpInputRef
local currentProfLbl, autoloadLbl
local updProfList    = function() end
local infJumpSyncFn  = function() end
local acSyncFn       = function() end
local abSyncFn       = function() end
local cashSyncFn     = function() end

-- ════════════════════════════════════════════════════════════════
-- AUTOCOLLECT
-- ════════════════════════════════════════════════════════════════
local autoCollectEnabled = false; local autoCollectThread = nil
local acClick,acUpdateVis,acGetEnabled,acSetEnabled = makeToggleCard(collectFrame,"AutoCollect","[C]",C.accent_green,1)
collectDelayBox,_ = makeInputField(collectFrame,"Delay entre TPs (segundos)",collectDelay,C.accent_green,function(val)
    local n=tonumber(val); if n and n>=0 then collectDelay=n; savedSettings["collect_delay"]=n; saveSettings(savedSettings)
        if collectDelayRef then collectDelayRef.Text=tostring(n) end end
end)
collectDelayBox.Parent.LayoutOrder = 2

local camLockConn = nil
local function lockCameraDown()
    local cam = workspace.CurrentCamera; cam.CameraType = Enum.CameraType.Scriptable
    local function applyAngle()
        local ch = Players.LocalPlayer.Character; if not ch then return end
        local hrpPart = ch:FindFirstChild("HumanoidRootPart"); if not hrpPart then return end
        local origin = hrpPart.Position + Vector3.new(0,2,0)
        cam.CFrame = CFrame.new(origin, origin + Vector3.new(0,-1,0))
    end
    applyAngle(); camLockConn = RunService.RenderStepped:Connect(applyAngle)
end
local function unlockCamera()
    if camLockConn then camLockConn:Disconnect(); camLockConn = nil end
    local cam = workspace.CurrentCamera; cam.CameraType = Enum.CameraType.Custom
    local ch = Players.LocalPlayer.Character
    if ch then local hum = ch:FindFirstChildWhichIsA("Humanoid"); if hum then cam.CameraSubject = hum end end
end

local function setAutoCollect(state)
    autoCollectEnabled = state; acSetEnabled(state); acUpdateVis()
    if state then
        lockCameraDown()
        autoCollectThread = task.spawn(function()
            local lp = Players.LocalPlayer
            local ch = lp.Character or lp.CharacterAdded:Wait()
            local hrp2 = ch:WaitForChild("HumanoidRootPart")
            local function getNearestTycoon()
                local nearest,shortest = nil,math.huge
                for _,t in ipairs(workspace.Tycoons:GetChildren()) do
                    local ref=t:FindFirstChildWhichIsA("BasePart",true)
                    if ref then local d=(hrp2.Position-ref.Position).Magnitude; if d<shortest then shortest=d; nearest=t end end
                end; return nearest
            end
            local myTycoon = getNearestTycoon()
            if not myTycoon then notify("AutoCollect","Tycoon nao encontrado!",3,C.accent_red); unlockCamera(); return end
            local Placements = myTycoon:FindFirstChild("Placements")
            if not Placements then notify("AutoCollect","Placements nao encontrado!",3,C.accent_red); unlockCamera(); return end
            local collectors = {}
            local function refreshCollectors()
                collectors = {}
                for _, child in ipairs(Placements:GetChildren()) do
                    if child.Name:find("Collector") then table.insert(collectors, child) end
                end
            end
            refreshCollectors()
            Placements.ChildAdded:Connect(function(child) if child.Name:find("Collector") then table.insert(collectors, child) end end)
            Placements.ChildRemoved:Connect(function(child) for i,c in ipairs(collectors) do if c==child then table.remove(collectors,i); break end end end)
            local function getChar() ch=lp.Character; if ch then hrp2=ch:FindFirstChild("HumanoidRootPart") end; return ch and hrp2 end
            while autoCollectEnabled do
                for _,child in ipairs(collectors) do
                    if not autoCollectEnabled then break end
                    local rootPart=child:FindFirstChild("RootPart"); if not rootPart then continue end
                    local cp=rootPart:FindFirstChild("CollectPrompt")
                    if not cp or not cp:IsA("ProximityPrompt") or not cp.Enabled then continue end
                    if not getChar() then task.wait(1); continue end
                    hrp2.CFrame = rootPart.CFrame + Vector3.new(0,3,0)
                    local att=0; repeat task.wait(0.1); att+=1 until (hrp2.Position-rootPart.Position).Magnitude<=10 or att>=20
                    cp=rootPart:FindFirstChild("CollectPrompt"); if not cp or not cp.Enabled then continue end
                    fireproximityprompt(cp); task.wait(collectDelay)
                end; task.wait(1)
            end
        end)
        notify("AutoCollect","Coleta iniciada!",2,C.accent_green)
    else
        if autoCollectThread then task.cancel(autoCollectThread); autoCollectThread=nil end
        unlockCamera(); notify("AutoCollect","Coleta parada.",2,C.off_color)
    end
end
acClick.MouseButton1Click:Connect(function() setAutoCollect(not autoCollectEnabled) end)
acSyncFn = function(v) setAutoCollect(v) end

-- ════════════════════════════════════════════════════════════════
-- AUTOBUY
-- ════════════════════════════════════════════════════════════════
local function loadAutoBuyItemsFull()
    local ok, data = pcall(function() return readfile(SAVE_FILE_AUTOBUY) end)
    if not ok or not data or data == "" then return {} end
    local items = {}
    for line in data:gmatch("[^\n]+") do
        local name, flex = line:match("^(.+)|([01])$")
        if name then table.insert(items, {name=name, flex=(flex=="1")})
        else local plain = line:match("^%s*(.-)%s*$"); if plain ~= "" then table.insert(items, {name=plain, flex=true}) end end
    end
    return items
end
local function saveAutoBuyItemsFull(items)
    local lines = {}
    for _,it in ipairs(items) do table.insert(lines, it.name.."|"..(it.flex and "1" or "0")) end
    pcall(function() writefile(SAVE_FILE_AUTOBUY, table.concat(lines,"\n")) end)
end
local function tokenize(str)
    local t = {}; for tok in str:lower():gmatch("%S+") do t[#t+1] = tok end; return t
end
local function fuzzyMatchTokens(tokens, target)
    local tl = target:lower():gsub("[_%-]", " ")
    for _, tok in ipairs(tokens) do if not tl:find(tok, 1, true) then return false end end
    return true
end
local function fuzzyMatch(query, target)
    local tokens = tokenize(query); if #tokens == 0 then return true end
    return fuzzyMatchTokens(tokens, target)
end
local function scanWorkspaceNames()
    local seen = {}; local names = {}
    local function scan(obj, depth)
        if depth > 6 then return end
        for _, child in ipairs(obj:GetChildren()) do
            local n = child.Name
            if not seen[n] and #n > 2 then seen[n]=true; table.insert(names,n) end
            scan(child, depth+1)
        end
    end
    scan(workspace, 0); table.sort(names); return names
end

local autoBuyItems = loadAutoBuyItemsFull()
local autoBuyEnabled = false; local autoBuyThread = nil

local function resolveItemName(entry)
    if entry.flex then
        local found = nil
        local function search(obj, depth)
            if depth > 6 or found then return end
            for _, child in ipairs(obj:GetChildren()) do
                if fuzzyMatch(entry.name, child.Name) then found = child.Name; return end
                search(child, depth+1)
            end
        end
        search(workspace, 0); return found or entry.name
    else return entry.name end
end

local abClick,abUpdateVis,abGetEnabled,abSetEnabled = makeToggleCard(buyFrame,"AutoBuy","[B]",C.accent_gold,1)
buyDelayBox,_ = makeInputField(buyFrame,"Delay entre compras (seg)",buyDelay,C.accent_gold,function(val)
    local n=tonumber(val); if n and n>=0.05 then buyDelay=n; savedSettings["buy_delay"]=n; saveSettings(savedSettings)
        if buyDelayRef then buyDelayRef.Text=tostring(n) end end
end)
buyDelayBox.Parent.LayoutOrder = 2

local merchantStock = {}
pcall(function()
    local UpdateState = game:GetService("ReplicatedStorage").Remotes.UpdateState
    UpdateState.OnClientEvent:Connect(function(changes)
        if type(changes) ~= "table" then return end
        for key, change in pairs(changes) do
            local itemName = key:match("^%[merchantStock%]%[(.+)%]$")
            if itemName then
                local newVal = type(change)=="table" and change.new or change
                merchantStock[itemName] = tonumber(newVal) or 0
            end
        end
    end)
end)
local function getStock(itemName) return merchantStock[itemName] or -1 end

local function setAutoBuy(state)
    autoBuyEnabled = state; abSetEnabled(state); abUpdateVis()
    if state then
        autoBuyThread = task.spawn(function()
            local MerchantBuy = game:GetService("ReplicatedStorage").Remotes.MerchantBuy
            local MIN_DELAY = 1.0
            while autoBuyEnabled do
                if #autoBuyItems == 0 then task.wait(2); continue end
                for _, entry in ipairs(autoBuyItems) do
                    if not autoBuyEnabled then break end
                    local realName = resolveItemName(entry)
                    if getStock(realName) == 0 then continue end
                    MerchantBuy:FireServer(realName); task.wait(math.max(buyDelay, MIN_DELAY))
                end
                task.wait(0.5)
            end
        end)
        notify("AutoBuy","Comprando itens!",2,C.accent_gold)
    else
        if autoBuyThread then task.cancel(autoBuyThread); autoBuyThread=nil end
        notify("AutoBuy","Compra pausada.",2,C.off_color)
    end
end
abClick.MouseButton1Click:Connect(function() setAutoBuy(not autoBuyEnabled) end)
abSyncFn = function(v) setAutoBuy(v) end

-- Card itens salvos
local itemsCard = makeCard(buyFrame, 80, 3)
local ics = itemsCard:FindFirstChildWhichIsA("UIStroke"); if ics then tw(ics,{Color=C.accent_gold},0) end
local itemsLbl = Instance.new("TextLabel",itemsCard)
itemsLbl.Size=UDim2.new(1,-16,0,20); itemsLbl.Position=UDim2.new(0,10,0,6)
itemsLbl.BackgroundTransparency=1; itemsLbl.Text="Itens salvos"; itemsLbl.TextColor3=C.accent_gold
itemsLbl.Font=Enum.Font.GothamBold; itemsLbl.TextSize=13; itemsLbl.TextXAlignment=Enum.TextXAlignment.Left
local itemsScroll = Instance.new("ScrollingFrame",itemsCard)
itemsScroll.Size=UDim2.new(1,-16,0,46); itemsScroll.Position=UDim2.new(0,8,0,28)
itemsScroll.BackgroundColor3=C.bg_input; itemsScroll.BorderSizePixel=0
itemsScroll.ScrollBarThickness=4; itemsScroll.ScrollBarImageColor3=C.accent_gold
itemsScroll.CanvasSize=UDim2.new(0,0,0,0); itemsScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
itemsScroll.ScrollingDirection=Enum.ScrollingDirection.Y
Instance.new("UICorner",itemsScroll).CornerRadius=UDim.new(0,8); addStroke(itemsScroll,C.border_dim,1,0.3)
local itemsLayout2 = Instance.new("UIListLayout",itemsScroll)
itemsLayout2.Padding=UDim.new(0,4); itemsLayout2.SortOrder=Enum.SortOrder.LayoutOrder
local isp = Instance.new("UIPadding",itemsScroll)
isp.PaddingTop=UDim.new(0,5); isp.PaddingBottom=UDim.new(0,5); isp.PaddingLeft=UDim.new(0,6); isp.PaddingRight=UDim.new(0,6)
itemsLayout2:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    local h = itemsLayout2.AbsoluteContentSize.Y + 14
    itemsCard.Size = UDim2.new(1,-6,0,math.max(80,h+46)); itemsScroll.Size = UDim2.new(1,-16,0,math.min(h,140))
end)

local suggestCard, suggestScroll, selectedSuggestions, addBtn = nil, nil, {}, nil
local function closeSuggestions()
    if suggestCard then suggestCard.Visible=false; suggestCard.Size=UDim2.new(1,-6,0,0) end
    if suggestScroll then for _,c in ipairs(suggestScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end end
    selectedSuggestions = {}; if addBtn then addBtn.Text = "Salvar" end
end

local function addItemTag(entry)
    local name = entry.name
    local tag = Instance.new("Frame", itemsScroll)
    tag.Size = UDim2.new(1,0,0,30); tag.BackgroundColor3 = Color3.fromRGB(26,26,44); tag.BorderSizePixel = 0
    Instance.new("UICorner",tag).CornerRadius = UDim.new(0,8); addStroke(tag, C.border_dim, 1, 0.4)
    local tagLbl = Instance.new("TextLabel",tag)
    tagLbl.Size = UDim2.new(1,-110,1,0); tagLbl.Position = UDim2.new(0,8,0,0)
    tagLbl.BackgroundTransparency = 1; tagLbl.Text = name; tagLbl.TextColor3 = C.accent_gold
    tagLbl.TextSize = 12; tagLbl.Font = Enum.Font.GothamBold; tagLbl.TextXAlignment = Enum.TextXAlignment.Left; tagLbl.ClipsDescendants = true
    local modeBtn = Instance.new("TextButton",tag)
    modeBtn.Size = UDim2.new(0,58,0,22); modeBtn.Position = UDim2.new(1,-86,0.5,-11)
    modeBtn.BorderSizePixel = 0; modeBtn.Font = Enum.Font.GothamBold; modeBtn.TextSize = 10
    Instance.new("UICorner",modeBtn).CornerRadius = UDim.new(0,6); addRipple(modeBtn)
    local function updateModeBtn()
        if entry.flex then modeBtn.Text="Flex"; modeBtn.TextColor3=C.text_white; modeBtn.BackgroundColor3=Color3.fromRGB(30,80,180)
            local s=modeBtn:FindFirstChildWhichIsA("UIStroke"); if s then s.Color=C.accent_blue end
        else modeBtn.Text="Exato"; modeBtn.TextColor3=C.text_white; modeBtn.BackgroundColor3=Color3.fromRGB(150,70,10)
            local s=modeBtn:FindFirstChildWhichIsA("UIStroke"); if s then s.Color=C.accent_gold end end
    end
    addStroke(modeBtn, C.accent_blue, 1, 0.3); updateModeBtn()
    modeBtn.MouseButton1Click:Connect(function()
        entry.flex=not entry.flex; updateModeBtn(); saveAutoBuyItemsFull(autoBuyItems)
        tweenBounce(modeBtn,{TextSize=12},0.12); task.wait(0.25); tw(modeBtn,{TextSize=10},0.15)
    end)
    local removeBtn = Instance.new("TextButton",tag)
    removeBtn.Size = UDim2.new(0,22,0,22); removeBtn.Position = UDim2.new(1,-26,0.5,-11)
    removeBtn.BackgroundColor3 = Color3.fromRGB(160,40,50); removeBtn.BorderSizePixel = 0
    removeBtn.Text = "x"; removeBtn.TextColor3 = C.text_white; removeBtn.TextSize = 13; removeBtn.Font = Enum.Font.GothamBold
    Instance.new("UICorner",removeBtn).CornerRadius = UDim.new(0,5); addRipple(removeBtn)
    removeBtn.MouseEnter:Connect(function() tw(removeBtn,{BackgroundColor3=Color3.fromRGB(210,60,70)},0.12) end)
    removeBtn.MouseLeave:Connect(function() tw(removeBtn,{BackgroundColor3=Color3.fromRGB(160,40,50)},0.12) end)
    removeBtn.MouseButton1Click:Connect(function()
        for i,v in ipairs(autoBuyItems) do if v==entry then table.remove(autoBuyItems,i); break end end
        saveAutoBuyItemsFull(autoBuyItems); tag:Destroy()
    end)
end

local inputCard = makeCard(buyFrame, 66, 4)
local inputCardStroke = inputCard:FindFirstChildWhichIsA("UIStroke"); if inputCardStroke then tw(inputCardStroke,{Color=C.accent_gold},0) end
local inputRow = Instance.new("Frame",inputCard)
inputRow.Size=UDim2.new(1,-16,0,30); inputRow.Position=UDim2.new(0,8,0,8); inputRow.BackgroundTransparency=1
local irLayout2=Instance.new("UIListLayout",inputRow)
irLayout2.FillDirection=Enum.FillDirection.Horizontal; irLayout2.Padding=UDim.new(0,6); irLayout2.VerticalAlignment=Enum.VerticalAlignment.Center
local textBox=Instance.new("TextBox",inputRow)
textBox.Size=UDim2.new(1,-72,1,0); textBox.BackgroundColor3=C.bg_input; textBox.BorderSizePixel=0
textBox.PlaceholderText="Buscar item no workspace..."; textBox.PlaceholderColor3=C.text_muted
textBox.Text=""; textBox.TextColor3=C.text_white; textBox.TextSize=12; textBox.Font=Enum.Font.Gotham; textBox.ClearTextOnFocus=false
Instance.new("UICorner",textBox).CornerRadius=UDim.new(0,8)
local tbStroke2=addStroke(textBox,C.border_dim,1,0.3)
textBox.Focused:Connect(function() tw(tbStroke2,{Color=C.accent_gold,Transparency=0},0.2) end)
textBox.FocusLost:Connect(function() tw(tbStroke2,{Color=C.border_dim,Transparency=0.3},0.2) end)
addBtn=Instance.new("TextButton",inputRow)
addBtn.Size=UDim2.new(0,60,1,0); addBtn.BackgroundColor3=Color3.fromRGB(60,120,40); addBtn.BorderSizePixel=0
addBtn.Text="Salvar"; addBtn.TextColor3=C.text_white; addBtn.TextSize=12; addBtn.Font=Enum.Font.GothamBold
Instance.new("UICorner",addBtn).CornerRadius=UDim.new(0,8); addStroke(addBtn,C.accent_green,1,0.4); addRipple(addBtn)
addBtn.MouseEnter:Connect(function() tw(addBtn,{BackgroundColor3=Color3.fromRGB(80,160,55)},0.15) end)
addBtn.MouseLeave:Connect(function() tw(addBtn,{BackgroundColor3=Color3.fromRGB(60,120,40)},0.15) end)
local addFlexMode = true
local modeToggleBtn = Instance.new("TextButton",inputCard)
modeToggleBtn.Size=UDim2.new(0,58,0,18); modeToggleBtn.Position=UDim2.new(0,8,0,42)
modeToggleBtn.BorderSizePixel=0; modeToggleBtn.Font=Enum.Font.GothamBold; modeToggleBtn.TextSize=10
Instance.new("UICorner",modeToggleBtn).CornerRadius=UDim.new(0,5); addRipple(modeToggleBtn)
local modeToggStr = addStroke(modeToggleBtn, C.accent_blue, 1, 0.3)
local function updateModeToggle()
    if addFlexMode then modeToggleBtn.Text="[Flex]"; modeToggleBtn.TextColor3=C.text_white; modeToggleBtn.BackgroundColor3=Color3.fromRGB(30,80,180); tw(modeToggStr,{Color=C.accent_blue},0.15)
    else modeToggleBtn.Text="[Exato]"; modeToggleBtn.TextColor3=C.text_white; modeToggleBtn.BackgroundColor3=Color3.fromRGB(150,70,10); tw(modeToggStr,{Color=C.accent_gold},0.15) end
end
updateModeToggle()
modeToggleBtn.MouseButton1Click:Connect(function()
    addFlexMode=not addFlexMode; updateModeToggle(); tweenBounce(modeToggleBtn,{TextSize=12},0.12); task.wait(0.25); tw(modeToggleBtn,{TextSize=10},0.15)
end)
local flexHint=Instance.new("TextLabel",inputCard)
flexHint.Size=UDim2.new(1,-80,0,16); flexHint.Position=UDim2.new(0,72,0,43)
flexHint.BackgroundTransparency=1; flexHint.Text="modo de adicao (altera por item na lista)"
flexHint.TextColor3=C.text_muted; flexHint.Font=Enum.Font.Gotham; flexHint.TextSize=9; flexHint.TextXAlignment=Enum.TextXAlignment.Left

suggestCard = makeCard(buyFrame, 0, 5)
suggestCard.BackgroundColor3 = Color3.fromRGB(16,16,30)
local suggestStroke = suggestCard:FindFirstChildWhichIsA("UIStroke"); if suggestStroke then tw(suggestStroke,{Color=C.accent_gold},0) end
suggestCard.Visible = false
suggestScroll = Instance.new("ScrollingFrame",suggestCard)
suggestScroll.Size=UDim2.new(1,-10,1,-8); suggestScroll.Position=UDim2.new(0,5,0,4)
suggestScroll.BackgroundTransparency=1; suggestScroll.BorderSizePixel=0
suggestScroll.ScrollBarThickness=4; suggestScroll.ScrollBarImageColor3=C.accent_gold
suggestScroll.CanvasSize=UDim2.new(0,0,0,0); suggestScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y; suggestScroll.ScrollingDirection=Enum.ScrollingDirection.Y
local suggestLayout=Instance.new("UIListLayout",suggestScroll)
suggestLayout.Padding=UDim.new(0,3); suggestLayout.SortOrder=Enum.SortOrder.LayoutOrder
local suggestPad=Instance.new("UIPadding",suggestScroll)
suggestPad.PaddingTop=UDim.new(0,2); suggestPad.PaddingBottom=UDim.new(0,2); suggestPad.PaddingLeft=UDim.new(0,2); suggestPad.PaddingRight=UDim.new(0,2)
inputCard.LayoutOrder=4; suggestCard.LayoutOrder=5; itemsCard.LayoutOrder=6

local wsNames = {}; local wsCacheTime = 0
local function updateSuggestions(query)
    for _,c in ipairs(suggestScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    local q = query:match("^%s*(.-)%s*$")
    if q == "" then suggestCard.Visible=false; suggestCard.Size=UDim2.new(1,-6,0,0); return end
    local tokens = tokenize(q); local matches = {}
    for _,n in ipairs(wsNames) do
        if fuzzyMatchTokens(tokens, n) then table.insert(matches, n) end
        if #matches >= 10 then break end
    end
    if #matches == 0 then suggestCard.Visible=false; suggestCard.Size=UDim2.new(1,-6,0,0); return end
    for idx, nm in ipairs(matches) do
        local row = Instance.new("Frame", suggestScroll)
        row.Size = UDim2.new(1,0,0,30); row.LayoutOrder = idx
        row.BackgroundColor3 = Color3.fromRGB(22,22,40); row.BorderSizePixel = 0
        Instance.new("UICorner",row).CornerRadius = UDim.new(0,7)
        local chk = Instance.new("Frame", row)
        chk.Size=UDim2.new(0,18,0,18); chk.Position=UDim2.new(0,6,0.5,-9); chk.BorderSizePixel=0; chk.BackgroundColor3=Color3.fromRGB(30,30,50)
        Instance.new("UICorner",chk).CornerRadius=UDim.new(0,4); addStroke(chk, C.border_dim, 1, 0.2)
        local chkMark = Instance.new("TextLabel", chk)
        chkMark.Size=UDim2.new(1,0,1,0); chkMark.BackgroundTransparency=1; chkMark.Text=""
        chkMark.TextColor3=C.accent_gold; chkMark.Font=Enum.Font.GothamBold; chkMark.TextSize=13
        local lbl = Instance.new("TextLabel", row)
        lbl.Size=UDim2.new(1,-32,1,0); lbl.Position=UDim2.new(0,30,0,0); lbl.BackgroundTransparency=1; lbl.Text=nm
        lbl.TextColor3 = selectedSuggestions[nm] and C.accent_gold or C.text_dim
        lbl.Font=Enum.Font.Gotham; lbl.TextSize=12; lbl.TextXAlignment=Enum.TextXAlignment.Left
        local lp = Instance.new("UIPadding", lbl); lp.PaddingLeft=UDim.new(0,4)
        if selectedSuggestions[nm] then chkMark.Text="v"; chk.BackgroundColor3=Color3.fromRGB(30,80,180); local s=chk:FindFirstChildWhichIsA("UIStroke"); if s then s.Color=C.accent_gold end end
        local rowBtn = Instance.new("TextButton", row)
        rowBtn.Size=UDim2.new(1,0,1,0); rowBtn.BackgroundTransparency=1; rowBtn.Text=""; rowBtn.ZIndex=5
        rowBtn.MouseEnter:Connect(function() if not selectedSuggestions[nm] then tw(row,{BackgroundColor3=Color3.fromRGB(30,30,54)},0.1); tw(lbl,{TextColor3=Color3.fromRGB(200,200,230)},0.1) end end)
        rowBtn.MouseLeave:Connect(function() if not selectedSuggestions[nm] then tw(row,{BackgroundColor3=Color3.fromRGB(22,22,40)},0.1); tw(lbl,{TextColor3=C.text_dim},0.1) end end)
        rowBtn.MouseButton1Click:Connect(function()
            selectedSuggestions[nm] = not selectedSuggestions[nm]
            if selectedSuggestions[nm] then
                chkMark.Text="v"; tw(chk,{BackgroundColor3=Color3.fromRGB(30,80,180)},0.15)
                local s=chk:FindFirstChildWhichIsA("UIStroke"); if s then tw(s,{Color=C.accent_gold},0.15) end
                tw(lbl,{TextColor3=C.accent_gold},0.15); tw(row,{BackgroundColor3=Color3.fromRGB(28,28,52)},0.15)
            else
                chkMark.Text=""; tw(chk,{BackgroundColor3=Color3.fromRGB(30,30,50)},0.15)
                local s=chk:FindFirstChildWhichIsA("UIStroke"); if s then tw(s,{Color=C.border_dim},0.15) end
                tw(lbl,{TextColor3=C.text_dim},0.15); tw(row,{BackgroundColor3=Color3.fromRGB(22,22,40)},0.15)
            end
            local count = 0; for _ in pairs(selectedSuggestions) do count = count + 1 end
            addBtn.Text = count > 0 and ("Salvar ("..count..")") or "Salvar"
        end)
    end
    local rowH = math.min(#matches * 33 + 8, 165)
    suggestCard.Size = UDim2.new(1,-6,0,rowH); suggestCard.Visible = true
end
textBox:GetPropertyChangedSignal("Text"):Connect(function() updateSuggestions(textBox.Text) end)
textBox.Focused:Connect(function()
    local now = os.clock()
    if now - wsCacheTime > 30 then task.spawn(function() wsNames=scanWorkspaceNames(); wsCacheTime=os.clock() end) end
    if textBox.Text ~= "" then updateSuggestions(textBox.Text) end
end)
mainFrame.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        local pos = input.Position
        local function isInsideFrame(frame)
            if not frame or not frame.Visible then return false end
            local abs=frame.AbsolutePosition; local sz=frame.AbsoluteSize
            return pos.X>=abs.X and pos.X<=abs.X+sz.X and pos.Y>=abs.Y and pos.Y<=abs.Y+sz.Y
        end
        if not isInsideFrame(inputCard) and not isInsideFrame(suggestCard) then closeSuggestions() end
    end
end)
addBtn.MouseButton1Click:Connect(function()
    local added=0; local duplicates=0; local hasSelected=false
    for _ in pairs(selectedSuggestions) do hasSelected=true; break end
    if hasSelected then
        for nm in pairs(selectedSuggestions) do
            local isDupe=false
            for _,v in ipairs(autoBuyItems) do if v.name==nm then isDupe=true; break end end
            if isDupe then duplicates+=1
            else local entry={name=nm,flex=addFlexMode}; table.insert(autoBuyItems,entry); addItemTag(entry); added+=1 end
        end
        saveAutoBuyItemsFull(autoBuyItems); textBox.Text=""; closeSuggestions()
        if added > 0 then
            notify("AutoBuy","+"..added.." itens ["..(addFlexMode and "Flex" or "Exato").."]"..(duplicates>0 and " ("..duplicates.." ja existiam)" or ""),3,C.accent_gold)
            tweenBounce(addBtn,{TextSize=14},0.15); task.wait(0.3); tw(addBtn,{TextSize=12},0.2)
        else tweenBounce(textBox,{BackgroundColor3=Color3.fromRGB(60,20,20)},0.1); task.wait(0.4); tw(textBox,{BackgroundColor3=C.bg_input},0.3) end
    else
        local name=textBox.Text:match("^%s*(.-)%s*$"); if name=="" then return end
        for _,v in ipairs(autoBuyItems) do
            if v.name==name then tweenBounce(textBox,{BackgroundColor3=Color3.fromRGB(60,20,20)},0.1); task.wait(0.4); tw(textBox,{BackgroundColor3=C.bg_input},0.3); return end
        end
        local entry={name=name,flex=addFlexMode}; table.insert(autoBuyItems,entry); saveAutoBuyItemsFull(autoBuyItems); addItemTag(entry)
        textBox.Text=""; closeSuggestions()
        tweenBounce(addBtn,{TextSize=14},0.15); task.wait(0.3); tw(addBtn,{TextSize=12},0.2)
        notify("AutoBuy","["..(addFlexMode and "Flex" or "Exato").."] "..name,2,C.accent_gold)
    end
end)
for _,entry in ipairs(autoBuyItems) do addItemTag(entry) end

-- DEBUG CARD
local debugCard = makeCard(buyFrame, 90, 7)
local dcs = debugCard:FindFirstChildWhichIsA("UIStroke"); if dcs then tw(dcs,{Color=C.accent_purple},0) end
local debugHeader = Instance.new("TextLabel",debugCard)
debugHeader.Size=UDim2.new(1,-16,0,20); debugHeader.Position=UDim2.new(0,10,0,5)
debugHeader.BackgroundTransparency=1; debugHeader.Text="[DEBUG] Ultimo MerchantBuy recebido"
debugHeader.TextColor3=C.accent_purple; debugHeader.Font=Enum.Font.GothamBold; debugHeader.TextSize=11; debugHeader.TextXAlignment=Enum.TextXAlignment.Left
local debugLbl = Instance.new("TextLabel",debugCard)
debugLbl.Size=UDim2.new(1,-16,0,32); debugLbl.Position=UDim2.new(0,10,0,26)
debugLbl.BackgroundTransparency=1; debugLbl.Text="Compre um item manualmente para ver os args"
debugLbl.TextColor3=C.text_muted; debugLbl.Font=Enum.Font.Gotham; debugLbl.TextSize=11; debugLbl.TextWrapped=true; debugLbl.TextXAlignment=Enum.TextXAlignment.Left
local copyDebugBtn = Instance.new("TextButton",debugCard)
copyDebugBtn.Size=UDim2.new(1,-20,0,24); copyDebugBtn.Position=UDim2.new(0,10,0,62)
copyDebugBtn.BackgroundColor3=Color3.fromRGB(30,15,50); copyDebugBtn.BorderSizePixel=0
copyDebugBtn.Text="Copiar nome capturado pro campo de busca"; copyDebugBtn.TextColor3=C.accent_purple; copyDebugBtn.Font=Enum.Font.GothamBold; copyDebugBtn.TextSize=10
Instance.new("UICorner",copyDebugBtn).CornerRadius=UDim.new(0,7); addStroke(copyDebugBtn,C.accent_purple,1,0.4); addRipple(copyDebugBtn)
local lastCapturedName = nil
pcall(function()
    local remote = game:GetService("ReplicatedStorage").Remotes.MerchantBuy
    local mt = getrawmetatable(game); local oldNamecall = mt.__namecall; setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method=="FireServer" and self==remote and not autoBuyEnabled then
            local args={...}; local argsStr=""
            for i,v in ipairs(args) do argsStr=argsStr..(i>1 and ", " or "")..tostring(v) end
            lastCapturedName=tostring(args[1] or ""); debugLbl.Text="Args: "..argsStr
            debugLbl.TextColor3=C.accent_gold; task.delay(2, function() tw(debugLbl,{TextColor3=C.text_dim},0.5) end)
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
end)
copyDebugBtn.MouseButton1Click:Connect(function()
    if lastCapturedName and lastCapturedName~="" then textBox.Text=lastCapturedName; switchTab(2); notify("Debug","Nome copiado: "..lastCapturedName,2,C.accent_purple)
    else notify("Debug","Compre um item manualmente primeiro!",2,C.off_color) end
end)

-- ════════════════════════════════════════════════════════════════
-- AUTOCASH
-- ════════════════════════════════════════════════════════════════
local autoCashEnabled = false; local autoCashThread = nil
local cashClick,cashUpdateVis,cashGetEnabled,cashSetEnabled = makeToggleCard(cashFrame,"AutoCash","[$]",C.accent_cyan,1)
cashDelayBox,_ = makeInputField(cashFrame,"Intervalo de envio (segundos)",cashDelay,C.accent_cyan,function(val)
    local n=tonumber(val); if n and n>0 then cashDelay=n; savedSettings["cash_delay"]=n; saveSettings(savedSettings)
        if cashDelayRef then cashDelayRef.Text=tostring(n) end end
end)
cashDelayBox.Parent.LayoutOrder = 2

local function setAutoCash(state)
    autoCashEnabled=state; cashSetEnabled(state); cashUpdateVis()
    if state then
        autoCashThread=task.spawn(function()
            while autoCashEnabled do
                task.wait(cashDelay)
                if autoCashEnabled then game:GetService("ReplicatedStorage").Remotes.MoveCash:FireServer() end
            end
        end)
        notify("AutoCash","Enviando cash!",2,C.accent_cyan)
    else
        if autoCashThread then task.cancel(autoCashThread); autoCashThread=nil end
        notify("AutoCash","Cash pausado.",2,C.off_color)
    end
end
cashClick.MouseButton1Click:Connect(function() setAutoCash(not autoCashEnabled) end)
cashSyncFn = function(v) setAutoCash(v) end

-- ════════════════════════════════════════════════════════════════
-- getCurrentData / applyProfileData (incluindo autoRebirthEnabled)
-- ════════════════════════════════════════════════════════════════
local function getCurrentData()
    return {
        tpwalkSpeed        = tpwalkSpeed,
        jpower             = jpower,
        infJumpEnabled     = infJumpEnabled,
        collectDelay       = collectDelay,
        buyDelay           = buyDelay,
        cashDelay          = cashDelay,
        autoBuyItems       = autoBuyItems,
        autoCollectEnabled = autoCollectEnabled,
        autoBuyEnabled     = autoBuyEnabled,
        autoCashEnabled    = autoCashEnabled,
        -- v2.5 fix: salva estado do Auto Rebirth via bridge global
        autoRebirthEnabled = (_G._BFHub_RebirthState and _G._BFHub_RebirthState.enabled) or false,
    }
end

local function applyProfileData(data)
    if data.tpwalkSpeed then tpwalkSpeed=data.tpwalkSpeed; if tpwalkInputRef then tpwalkInputRef.Text=tostring(tpwalkSpeed) end end
    if data.jpower then jpower=data.jpower; if humanoid.UseJumpPower then humanoid.JumpPower=jpower else humanoid.JumpHeight=jpower end; if jumpInputRef then jumpInputRef.Text=tostring(jpower) end end
    if data.infJumpEnabled~=nil then infJumpEnabled=data.infJumpEnabled; infJumpSyncFn(infJumpEnabled) end
    if data.collectDelay then collectDelay=data.collectDelay; if collectDelayBox then collectDelayBox.Text=tostring(collectDelay) end; if collectDelayRef then collectDelayRef.Text=tostring(collectDelay) end end
    if data.buyDelay then buyDelay=data.buyDelay; if buyDelayBox then buyDelayBox.Text=tostring(buyDelay) end; if buyDelayRef then buyDelayRef.Text=tostring(buyDelay) end end
    if data.cashDelay then cashDelay=data.cashDelay; if cashDelayBox then cashDelayBox.Text=tostring(cashDelay) end; if cashDelayRef then cashDelayRef.Text=tostring(cashDelay) end end
    if data.autoBuyItems then
        local converted = {}
        for _,v in ipairs(data.autoBuyItems) do
            if type(v)=="string" then table.insert(converted,{name=v,flex=true})
            else table.insert(converted,{name=v.name or v,flex=v.flex~=false}) end
        end
        autoBuyItems=converted; saveAutoBuyItemsFull(autoBuyItems)
        for _,c in ipairs(itemsScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
        for _,entry in ipairs(autoBuyItems) do addItemTag(entry) end
    end
    if data.autoCollectEnabled~=nil then acSyncFn(data.autoCollectEnabled==true) end
    if data.autoBuyEnabled~=nil     then abSyncFn(data.autoBuyEnabled==true) end
    if data.autoCashEnabled~=nil    then cashSyncFn(data.autoCashEnabled==true) end

    -- v2.5 fix: aplica estado do Auto Rebirth via bridge global
    if data.autoRebirthEnabled ~= nil then
        local rb = _G._BFHub_RebirthState
        if rb then
            if data.autoRebirthEnabled == true then
                if rb.start and not rb.enabled then rb.start() end
            else
                if rb.stop and rb.enabled then rb.stop() end
            end
        end
    end

    if currentProfLbl then currentProfLbl.Text="Ativo: "..ProfileSystem.currentProfile end
    notify("Preset","Perfil '"..ProfileSystem.currentProfile.."' carregado!",2,C.accent_gold)
end

-- ════════════════════════════════════════════════════════════════
-- CONFIG TAB
-- ════════════════════════════════════════════════════════════════
local function makeConfigToggle(parent, label, icon, initial, order, color, onChange)
    local card = makeCard(parent,54,order); local cs2 = card:FindFirstChildWhichIsA("UIStroke")
    local state = {value=initial}
    local ic2 = Instance.new("TextLabel",card)
    ic2.Size=UDim2.new(0,30,0,30); ic2.Position=UDim2.new(0,10,0,12); ic2.BackgroundTransparency=1
    ic2.Text=icon; ic2.Font=Enum.Font.GothamBold; ic2.TextSize=20; ic2.TextColor3=initial and color or C.text_muted
    local lb2 = Instance.new("TextLabel",card)
    lb2.Size=UDim2.new(0.6,0,1,0); lb2.Position=UDim2.new(0,46,0,0); lb2.BackgroundTransparency=1
    lb2.Text=label; lb2.TextColor3=C.text_white; lb2.Font=Enum.Font.GothamBold; lb2.TextSize=14; lb2.TextXAlignment=Enum.TextXAlignment.Left
    local tr2=Instance.new("Frame",card)
    tr2.Size=UDim2.new(0,64,0,30); tr2.Position=UDim2.new(1,-80,0,12)
    tr2.BackgroundColor3=initial and color or C.off_color; tr2.BackgroundTransparency=0.25; tr2.BorderSizePixel=0
    Instance.new("UICorner",tr2).CornerRadius=UDim.new(1,0)
    local kn2=Instance.new("Frame",tr2)
    kn2.Size=UDim2.new(0,24,0,24); kn2.Position=initial and UDim2.new(1,-27,0,3) or UDim2.new(0,3,0,3)
    kn2.BackgroundColor3=C.text_white; kn2.BorderSizePixel=0; Instance.new("UICorner",kn2).CornerRadius=UDim.new(1,0)
    local cb2=Instance.new("TextButton",card)
    cb2.Size=UDim2.new(1,0,1,0); cb2.BackgroundTransparency=1; cb2.Text=""; cb2.ZIndex=5; addRipple(cb2)
    local function upd2(v)
        state.value=v; local c3=v and color or C.off_color
        tw(tr2,{BackgroundColor3=c3},0.25); tweenBack(kn2,{Position=v and UDim2.new(1,-27,0,3) or UDim2.new(0,3,0,3)},0.28)
        ic2.TextColor3=v and color or C.text_muted; if cs2 then tw(cs2,{Color=v and color or C.border_dim},0.25) end
    end
    cb2.MouseButton1Click:Connect(function() state.value=not state.value; upd2(state.value); if onChange then onChange(state.value) end end)
    return upd2
end

-- ════════════════════════════════════════════════════════════════
-- ANTIAFK
-- ════════════════════════════════════════════════════════════════
local _afkBtnRef = nil
local function activateAntiAFK(btnRef)
    if antiAfkEnabled then return end
    antiAfkEnabled = true
    if btnRef then _afkBtnRef = btnRef end
    notify("AntiAFK","Ativando automaticamente...",2,C.accent_purple)
    task.spawn(function()
        local ok = pcall(function()
            loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-Universal-AntiAFK-89852"))()
        end)
        if ok then
            notify("AntiAFK","Script ativo!",3,C.accent_purple)
            if _afkBtnRef then
                tw(_afkBtnRef,{BackgroundColor3=Color3.fromRGB(80,20,120),BackgroundTransparency=0},0.3)
                _afkBtnRef.Text="[A]  AntiAFK ATIVO"
            end
        else
            antiAfkEnabled=false
            notify("AntiAFK","Falha ao carregar!",3,C.accent_red)
        end
    end)
end

local function buildConfigTab()
    local profCard = makeCard(configFrame, 420, 1)
    local profStroke = profCard:FindFirstChildWhichIsA("UIStroke"); if profStroke then tw(profStroke,{Color=C.accent_gold},0) end
    local profHeader = Instance.new("TextLabel",profCard)
    profHeader.Size=UDim2.new(1,-16,0,22); profHeader.Position=UDim2.new(0,12,0,8)
    profHeader.BackgroundTransparency=1; profHeader.Text="Presets de Configuracao"
    profHeader.TextColor3=C.accent_gold; profHeader.Font=Enum.Font.GothamBold; profHeader.TextSize=14; profHeader.TextXAlignment=Enum.TextXAlignment.Left
    currentProfLbl = Instance.new("TextLabel",profCard)
    currentProfLbl.Size=UDim2.new(1,-130,0,16); currentProfLbl.Position=UDim2.new(0,12,0,32)
    currentProfLbl.BackgroundTransparency=1; currentProfLbl.Text="Ativo: "..ProfileSystem.currentProfile
    currentProfLbl.TextColor3=C.text_dim; currentProfLbl.Font=Enum.Font.Gotham; currentProfLbl.TextSize=11; currentProfLbl.TextXAlignment=Enum.TextXAlignment.Left
    local saveActiveBtn = Instance.new("TextButton",profCard)
    saveActiveBtn.Size=UDim2.new(0,110,0,22); saveActiveBtn.Position=UDim2.new(1,-120,0,28)
    saveActiveBtn.BackgroundColor3=Color3.fromRGB(40,110,60); saveActiveBtn.BorderSizePixel=0
    saveActiveBtn.Text="[S] Salvar no Ativo"; saveActiveBtn.TextColor3=C.accent_green; saveActiveBtn.Font=Enum.Font.GothamBold; saveActiveBtn.TextSize=10
    Instance.new("UICorner",saveActiveBtn).CornerRadius=UDim.new(0,7); addStroke(saveActiveBtn,C.accent_green,1,0.4); addRipple(saveActiveBtn)
    saveActiveBtn.MouseEnter:Connect(function() tw(saveActiveBtn,{BackgroundColor3=Color3.fromRGB(55,145,75)},0.15) end)
    saveActiveBtn.MouseLeave:Connect(function() tw(saveActiveBtn,{BackgroundColor3=Color3.fromRGB(40,110,60)},0.15) end)
    saveActiveBtn.MouseButton1Click:Connect(function()
        ProfileSystem:saveCurrentProfile(getCurrentData())
        local origText=saveActiveBtn.Text; saveActiveBtn.Text="Salvo!"; tw(saveActiveBtn,{BackgroundColor3=Color3.fromRGB(20,160,80)},0.15)
        tweenBounce(saveActiveBtn,{TextSize=12},0.15); task.wait(0.8)
        saveActiveBtn.Text=origText; tw(saveActiveBtn,{BackgroundColor3=Color3.fromRGB(40,110,60),TextSize=10},0.25)
        notify("Preset","Salvo no perfil '"..ProfileSystem.currentProfile.."'!",2,C.accent_green)
    end)
    local profScroll = Instance.new("ScrollingFrame",profCard)
    profScroll.Size=UDim2.new(1,-20,0,92); profScroll.Position=UDim2.new(0,10,0,58)
    profScroll.BackgroundColor3=C.bg_deep; profScroll.BorderSizePixel=0
    profScroll.ScrollBarThickness=4; profScroll.ScrollBarImageColor3=C.accent_gold
    profScroll.CanvasSize=UDim2.new(0,0,0,0); profScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y; profScroll.ScrollingDirection=Enum.ScrollingDirection.Y
    Instance.new("UICorner",profScroll).CornerRadius=UDim.new(0,9); addStroke(profScroll,C.border_dim,1,0)
    local profListLayout = Instance.new("UIListLayout",profScroll)
    profListLayout.Padding=UDim.new(0,3); profListLayout.SortOrder=Enum.SortOrder.LayoutOrder
    local profPad = Instance.new("UIPadding",profScroll)
    profPad.PaddingTop=UDim.new(0,4); profPad.PaddingBottom=UDim.new(0,4); profPad.PaddingLeft=UDim.new(0,4); profPad.PaddingRight=UDim.new(0,4)
    local nameInput = Instance.new("TextBox",profCard)
    nameInput.Size=UDim2.new(1,-20,0,30); nameInput.Position=UDim2.new(0,10,0,158)
    nameInput.BackgroundColor3=C.bg_input; nameInput.TextColor3=C.text_white; nameInput.Font=Enum.Font.Gotham; nameInput.TextSize=13
    nameInput.PlaceholderText="Nome do preset..."; nameInput.PlaceholderColor3=C.text_muted; nameInput.Text=""; nameInput.ClearTextOnFocus=false; nameInput.BorderSizePixel=0
    Instance.new("UICorner",nameInput).CornerRadius=UDim.new(0,9)
    local nis=addStroke(nameInput,C.border_dim,1,0.2)
    nameInput.Focused:Connect(function() tw(nis,{Color=C.accent_gold,Transparency=0},0.2) end)
    nameInput.FocusLost:Connect(function() tw(nis,{Color=C.border_dim,Transparency=0.2},0.2) end)
    local function makeSmallBtn(parent, label, color, xScale, xOffset, yOff, onClick)
        local btn=Instance.new("TextButton",parent)
        btn.Size=UDim2.new(0.33,-7,0,28); btn.Position=UDim2.new(xScale,xOffset,0,yOff)
        btn.BackgroundColor3=Color3.fromRGB(15,15,30); btn.BorderSizePixel=0
        btn.Text=label; btn.TextColor3=color; btn.Font=Enum.Font.GothamBold; btn.TextSize=11
        Instance.new("UICorner",btn).CornerRadius=UDim.new(0,7); addStroke(btn,color,1,0.4); addRipple(btn)
        btn.MouseEnter:Connect(function() tw(btn,{BackgroundColor3=Color3.fromRGB(28,28,50)},0.15) end)
        btn.MouseLeave:Connect(function() tw(btn,{BackgroundColor3=Color3.fromRGB(15,15,30)},0.15) end)
        btn.MouseButton1Click:Connect(onClick); return btn
    end
    makeSmallBtn(profCard,"Carregar",C.accent_blue, 0, 10, 196, function()
        local n=nameInput.Text:match("^%s*(.-)%s*$"); if n=="" then return end
        local data=ProfileSystem:loadProfile(n)
        if data then applyProfileData(data); updProfList() else notify("Preset","Perfil nao encontrado!",2,C.accent_red) end
    end)
    makeSmallBtn(profCard,"Criar", C.accent_green, 0.33, 5, 196, function()
        local n=nameInput.Text:match("^%s*(.-)%s*$"); if n=="" then return end
        if ProfileSystem:createProfile(n) then
            ProfileSystem.currentProfile=n; ProfileSystem:saveCurrentProfile(getCurrentData())
            if currentProfLbl then currentProfLbl.Text="Ativo: "..n end
            updProfList(); notify("Preset","Perfil '"..n.."' criado!",2,C.accent_green)
        else notify("Preset","Ja existe!",2,C.accent_orange) end
    end)
    makeSmallBtn(profCard,"Deletar", C.accent_red, 0.66, 5, 196, function()
        local n=nameInput.Text:match("^%s*(.-)%s*$")
        if n=="" or n=="Default" then notify("Preset","Nao pode deletar Default!",2,C.accent_red); return end
        if ProfileSystem:deleteProfile(n) then
            if currentProfLbl then currentProfLbl.Text="Ativo: "..ProfileSystem.currentProfile end
            local al = loadAutoload(); if al == n then saveAutoload(nil); if autoloadLbl then autoloadLbl.Text="Sem autoload definido" end end
            updProfList(); notify("Preset","Perfil '"..n.."' deletado!",2,C.accent_orange)
        else notify("Preset","Nao encontrado!",2,C.accent_red) end
    end)
    local tipLbl=Instance.new("TextLabel",profCard)
    tipLbl.Size=UDim2.new(1,-20,0,26); tipLbl.Position=UDim2.new(0,10,0,232); tipLbl.BackgroundTransparency=1
    tipLbl.Text="Click = preenche nome  |  Click direito = carrega direto"
    tipLbl.TextColor3=C.text_muted; tipLbl.Font=Enum.Font.Gotham; tipLbl.TextSize=10; tipLbl.TextWrapped=true; tipLbl.TextXAlignment=Enum.TextXAlignment.Left
    local savePresetBtn = Instance.new("TextButton",profCard)
    savePresetBtn.Size=UDim2.new(1,-20,0,28); savePresetBtn.Position=UDim2.new(0,10,0,256)
    savePresetBtn.BackgroundColor3=Color3.fromRGB(30,100,50); savePresetBtn.BorderSizePixel=0
    savePresetBtn.Text="Salvar preset atual com estado dos toggles"; savePresetBtn.TextColor3=C.accent_green; savePresetBtn.Font=Enum.Font.GothamBold; savePresetBtn.TextSize=11
    Instance.new("UICorner",savePresetBtn).CornerRadius=UDim.new(0,8); addStroke(savePresetBtn,C.accent_green,1,0.4); addRipple(savePresetBtn)
    savePresetBtn.MouseEnter:Connect(function() tw(savePresetBtn,{BackgroundColor3=Color3.fromRGB(40,130,60)},0.15) end)
    savePresetBtn.MouseLeave:Connect(function() tw(savePresetBtn,{BackgroundColor3=Color3.fromRGB(30,100,50)},0.15) end)
    savePresetBtn.MouseButton1Click:Connect(function()
        local n=nameInput.Text:match("^%s*(.-)%s*$")
        if n~="" then if not ProfileSystem.profiles[n] then ProfileSystem:createProfile(n) end; ProfileSystem.currentProfile=n end
        ProfileSystem:saveCurrentProfile(getCurrentData())
        if currentProfLbl then currentProfLbl.Text="Ativo: "..ProfileSystem.currentProfile end
        updProfList(); notify("Preset","Salvo como '"..ProfileSystem.currentProfile.."'!",2,C.accent_green)
    end)
    local alSep = Instance.new("Frame",profCard)
    alSep.Size=UDim2.new(1,-24,0,1); alSep.Position=UDim2.new(0,12,0,292); alSep.BackgroundColor3=C.border_dim; alSep.BorderSizePixel=0
    local alSepG=Instance.new("UIGradient",alSep)
    alSepG.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(0,0,0)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(255,200,60)),ColorSequenceKeypoint.new(1,Color3.fromRGB(0,0,0))}
    local alTitle=Instance.new("TextLabel",profCard)
    alTitle.Size=UDim2.new(1,-16,0,20); alTitle.Position=UDim2.new(0,12,0,300); alTitle.BackgroundTransparency=1
    alTitle.Text="[>>] Autoload ao Executar"; alTitle.TextColor3=C.accent_gold; alTitle.Font=Enum.Font.GothamBold; alTitle.TextSize=12; alTitle.TextXAlignment=Enum.TextXAlignment.Left
    local currentAutoload = loadAutoload()
    autoloadLbl = Instance.new("TextLabel",profCard)
    autoloadLbl.Size=UDim2.new(1,-20,0,16); autoloadLbl.Position=UDim2.new(0,12,0,322); autoloadLbl.BackgroundTransparency=1
    autoloadLbl.Text = currentAutoload and ("Autoload: "..currentAutoload) or "Sem autoload definido"
    autoloadLbl.TextColor3 = currentAutoload and C.accent_green or C.text_muted; autoloadLbl.Font=Enum.Font.Gotham; autoloadLbl.TextSize=11; autoloadLbl.TextXAlignment=Enum.TextXAlignment.Left
    local setAutoloadBtn=Instance.new("TextButton",profCard)
    setAutoloadBtn.Size=UDim2.new(0.62,-6,0,26); setAutoloadBtn.Position=UDim2.new(0,10,0,342)
    setAutoloadBtn.BackgroundColor3=Color3.fromRGB(30,60,120); setAutoloadBtn.BorderSizePixel=0
    setAutoloadBtn.Text="[>>] Definir como Autoload"; setAutoloadBtn.TextColor3=C.accent_blue; setAutoloadBtn.Font=Enum.Font.GothamBold; setAutoloadBtn.TextSize=10
    Instance.new("UICorner",setAutoloadBtn).CornerRadius=UDim.new(0,8); addStroke(setAutoloadBtn,C.accent_blue,1,0.4); addRipple(setAutoloadBtn)
    setAutoloadBtn.MouseEnter:Connect(function() tw(setAutoloadBtn,{BackgroundColor3=Color3.fromRGB(40,80,160)},0.15) end)
    setAutoloadBtn.MouseLeave:Connect(function() tw(setAutoloadBtn,{BackgroundColor3=Color3.fromRGB(30,60,120)},0.15) end)
    setAutoloadBtn.MouseButton1Click:Connect(function()
        local n=nameInput.Text:match("^%s*(.-)%s*$"); if n=="" then n=ProfileSystem.currentProfile end
        if not ProfileSystem.profiles[n] then notify("Autoload","Preset nao existe!",2,C.accent_red); return end
        saveAutoload(n); autoloadLbl.Text="Autoload: "..n; tw(autoloadLbl,{TextColor3=C.accent_green},0.3)
        tweenBounce(setAutoloadBtn,{TextSize=12},0.15); task.wait(0.3); tw(setAutoloadBtn,{TextSize=10},0.2)
        notify("Autoload","'"..n.."' vai carregar automaticamente!",3,C.accent_blue)
    end)
    local clearAutoloadBtn=Instance.new("TextButton",profCard)
    clearAutoloadBtn.Size=UDim2.new(0.38,-6,0,26); clearAutoloadBtn.Position=UDim2.new(0.62,0,0,342)
    clearAutoloadBtn.BackgroundColor3=Color3.fromRGB(60,20,20); clearAutoloadBtn.BorderSizePixel=0
    clearAutoloadBtn.Text="[x] Remover"; clearAutoloadBtn.TextColor3=C.accent_red; clearAutoloadBtn.Font=Enum.Font.GothamBold; clearAutoloadBtn.TextSize=10
    Instance.new("UICorner",clearAutoloadBtn).CornerRadius=UDim.new(0,8); addStroke(clearAutoloadBtn,C.accent_red,1,0.4); addRipple(clearAutoloadBtn)
    clearAutoloadBtn.MouseEnter:Connect(function() tw(clearAutoloadBtn,{BackgroundColor3=Color3.fromRGB(90,30,30)},0.15) end)
    clearAutoloadBtn.MouseLeave:Connect(function() tw(clearAutoloadBtn,{BackgroundColor3=Color3.fromRGB(60,20,20)},0.15) end)
    clearAutoloadBtn.MouseButton1Click:Connect(function()
        saveAutoload(nil); autoloadLbl.Text="Sem autoload definido"; tw(autoloadLbl,{TextColor3=C.text_muted},0.3)
        notify("Autoload","Autoload removido.",2,C.off_color)
    end)
    local alHint=Instance.new("TextLabel",profCard)
    alHint.Size=UDim2.new(1,-20,0,30); alHint.Position=UDim2.new(0,12,0,374); alHint.BackgroundTransparency=1
    alHint.Text="O preset definido como autoload carrega automaticamente os toggles e configs ao executar o script."
    alHint.TextColor3=C.text_muted; alHint.Font=Enum.Font.Gotham; alHint.TextSize=9; alHint.TextWrapped=true; alHint.TextXAlignment=Enum.TextXAlignment.Left
    function updProfList()
        for _,c in ipairs(profScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
        local alName = loadAutoload()
        for idx,name in ipairs(ProfileSystem:getNames()) do
            local isA=(name==ProfileSystem.currentProfile); local isAL=(name==alName)
            local row=Instance.new("Frame",profScroll)
            row.Size=UDim2.new(1,0,0,28); row.LayoutOrder=idx
            row.BackgroundColor3=isA and Color3.fromRGB(30,55,110) or Color3.fromRGB(22,22,38); row.BorderSizePixel=0
            Instance.new("UICorner",row).CornerRadius=UDim.new(0,7); if isA then addStroke(row,C.accent_gold,1.5,0.3) end
            local btn2=Instance.new("TextButton",row)
            btn2.Size=UDim2.new(1,isAL and -58 or -8,1,0); btn2.Position=UDim2.new(0,0,0,0); btn2.BackgroundTransparency=1; btn2.ZIndex=2
            btn2.Text=(isA and ">> " or "   ")..name; btn2.TextColor3=isA and C.accent_gold or C.text_dim
            btn2.Font=Enum.Font.GothamBold; btn2.TextSize=12; btn2.TextXAlignment=Enum.TextXAlignment.Left
            local pp=Instance.new("UIPadding",btn2); pp.PaddingLeft=UDim.new(0,8); addRipple(btn2)
            btn2.MouseEnter:Connect(function() if not isA then tw(btn2,{TextColor3=Color3.fromRGB(200,200,230)},0.12) end end)
            btn2.MouseLeave:Connect(function() if not isA then tw(btn2,{TextColor3=C.text_dim},0.12) end end)
            btn2.MouseButton1Click:Connect(function()
                nameInput.Text=name; tweenBounce(btn2,{TextColor3=C.text_white},0.15)
                task.wait(0.35); tw(btn2,{TextColor3=isA and C.accent_gold or C.text_dim},0.3)
            end)
            btn2.MouseButton2Click:Connect(function()
                local data=ProfileSystem:loadProfile(name); if data then applyProfileData(data); updProfList() end
            end)
            if isAL then
                local alBadge=Instance.new("Frame",row)
                alBadge.Size=UDim2.new(0,50,0,20); alBadge.Position=UDim2.new(1,-54,0.5,-10)
                alBadge.BackgroundColor3=Color3.fromRGB(30,60,120); alBadge.BorderSizePixel=0
                Instance.new("UICorner",alBadge).CornerRadius=UDim.new(0,5); addStroke(alBadge,C.accent_blue,1,0.3)
                local alLbl=Instance.new("TextLabel",alBadge)
                alLbl.Size=UDim2.new(1,0,1,0); alLbl.BackgroundTransparency=1; alLbl.Text="AUTO"
                alLbl.TextColor3=C.accent_blue; alLbl.Font=Enum.Font.GothamBold; alLbl.TextSize=9
            end
        end
    end
    updProfList()

    -- TPWALK
    local twCard = makeCard(configFrame,62,2); local twStroke = twCard:FindFirstChildWhichIsA("UIStroke"); if twStroke then tw(twStroke,{Color=C.accent_blue},0) end
    local twLabel=Instance.new("TextLabel",twCard)
    twLabel.Size=UDim2.new(1,-16,0,20); twLabel.Position=UDim2.new(0,12,0,6); twLabel.BackgroundTransparency=1
    twLabel.Text="[>]  TPWalk  -  Velocidade de movimento"; twLabel.TextColor3=C.accent_blue; twLabel.Font=Enum.Font.GothamBold; twLabel.TextSize=12; twLabel.TextXAlignment=Enum.TextXAlignment.Left
    tpwalkInputRef=Instance.new("TextBox",twCard)
    tpwalkInputRef.Size=UDim2.new(1,-20,0,28); tpwalkInputRef.Position=UDim2.new(0,10,0,28)
    tpwalkInputRef.PlaceholderText="Velocidade (padrao: 80)"; tpwalkInputRef.BackgroundColor3=C.bg_input
    tpwalkInputRef.TextColor3=C.text_white; tpwalkInputRef.PlaceholderColor3=C.text_muted
    tpwalkInputRef.Font=Enum.Font.GothamBold; tpwalkInputRef.TextSize=13; tpwalkInputRef.BorderSizePixel=0; tpwalkInputRef.ClearTextOnFocus=false; tpwalkInputRef.Text=tostring(tpwalkSpeed)
    Instance.new("UICorner",tpwalkInputRef).CornerRadius=UDim.new(0,9)
    local twis=addStroke(tpwalkInputRef,C.border_dim,1,0.2)
    tpwalkInputRef.Focused:Connect(function() tw(twis,{Color=C.accent_blue,Transparency=0},0.2) end)
    tpwalkInputRef.FocusLost:Connect(function()
        tw(twis,{Color=C.border_dim,Transparency=0.2},0.2)
        local v=tonumber(tpwalkInputRef.Text)
        if v and v>0 then tpwalkSpeed=v; savedSettings["tpwalk_speed"]=v; saveSettings(savedSettings); notify("TPWalk","Velocidade: "..v,2,C.accent_blue)
        else tpwalkInputRef.Text=tostring(tpwalkSpeed) end
    end)

    -- JUMP POWER
    local jpCard=makeCard(configFrame,62,3); local jpStroke=jpCard:FindFirstChildWhichIsA("UIStroke"); if jpStroke then tw(jpStroke,{Color=C.accent_cyan},0) end
    local jpLabel=Instance.new("TextLabel",jpCard)
    jpLabel.Size=UDim2.new(1,-16,0,20); jpLabel.Position=UDim2.new(0,12,0,6); jpLabel.BackgroundTransparency=1
    jpLabel.Text="[^]  JumpPower  -  Forca do pulo"; jpLabel.TextColor3=C.accent_cyan; jpLabel.Font=Enum.Font.GothamBold; jpLabel.TextSize=12; jpLabel.TextXAlignment=Enum.TextXAlignment.Left
    jumpInputRef=Instance.new("TextBox",jpCard)
    jumpInputRef.Size=UDim2.new(1,-20,0,28); jumpInputRef.Position=UDim2.new(0,10,0,28)
    jumpInputRef.PlaceholderText="Forca (padrao: 110)"; jumpInputRef.BackgroundColor3=C.bg_input
    jumpInputRef.TextColor3=C.text_white; jumpInputRef.PlaceholderColor3=C.text_muted
    jumpInputRef.Font=Enum.Font.GothamBold; jumpInputRef.TextSize=13; jumpInputRef.BorderSizePixel=0; jumpInputRef.ClearTextOnFocus=false; jumpInputRef.Text=tostring(jpower)
    Instance.new("UICorner",jumpInputRef).CornerRadius=UDim.new(0,9)
    local jpis=addStroke(jumpInputRef,C.border_dim,1,0.2)
    jumpInputRef.Focused:Connect(function() tw(jpis,{Color=C.accent_cyan,Transparency=0},0.2) end)
    jumpInputRef.FocusLost:Connect(function()
        tw(jpis,{Color=C.border_dim,Transparency=0.2},0.2)
        local v=tonumber(jumpInputRef.Text)
        if v and v>0 then jpower=v; if humanoid.UseJumpPower then humanoid.JumpPower=jpower else humanoid.JumpHeight=jpower end; savedSettings["jpower"]=v; saveSettings(savedSettings); notify("JumpPower","Forca: "..v,2,C.accent_cyan)
        else jumpInputRef.Text=tostring(jpower) end
    end)

    -- INFJUMP
    local ijUpd = makeConfigToggle(configFrame,"InfJump","[^]",infJumpEnabled,4,C.accent_cyan,function(v)
        infJumpEnabled=v; notify(v and "InfJump ON" or "InfJump OFF","",2,v and C.accent_cyan or C.off_color)
    end)
    infJumpSyncFn=function(v) infJumpEnabled=v; ijUpd(v) end

    -- ANTIAFK
    local afkCard=makeCard(configFrame,52,5); local afkS=afkCard:FindFirstChildWhichIsA("UIStroke"); if afkS then tw(afkS,{Color=C.accent_purple},0) end
    local afkBtn=Instance.new("TextButton",afkCard)
    afkBtn.Size=UDim2.new(1,-16,0,38); afkBtn.Position=UDim2.new(0,8,0,7)
    afkBtn.BackgroundColor3=C.accent_purple; afkBtn.BackgroundTransparency=0.15; afkBtn.Text="[A]  Ativar AntiAFK"; afkBtn.TextColor3=C.text_white
    afkBtn.Font=Enum.Font.GothamBold; afkBtn.TextSize=15; afkBtn.BorderSizePixel=0
    Instance.new("UICorner",afkBtn).CornerRadius=UDim.new(0,10); addStroke(afkBtn,C.accent_purple,1.5,0.4); addRipple(afkBtn)
    afkBtn.MouseEnter:Connect(function() tw(afkBtn,{BackgroundTransparency=0,Size=UDim2.new(1,-12,0,40)},0.2) end)
    afkBtn.MouseLeave:Connect(function() tw(afkBtn,{BackgroundTransparency=0.15,Size=UDim2.new(1,-16,0,38)},0.2) end)
    afkBtn.MouseButton1Click:Connect(function()
        if not antiAfkEnabled then activateAntiAFK(afkBtn)
        else notify("AntiAFK","Ja esta ativo!",2,C.accent_orange) end
    end)

    -- DELAYS
    local delayCard=makeCard(configFrame,130,6); local ds=delayCard:FindFirstChildWhichIsA("UIStroke"); if ds then tw(ds,{Color=C.accent_purple},0) end
    local delayHeader=Instance.new("TextLabel",delayCard)
    delayHeader.Size=UDim2.new(1,-16,0,20); delayHeader.Position=UDim2.new(0,12,0,6); delayHeader.BackgroundTransparency=1
    delayHeader.Text="Delays das automacoes (segundos)"; delayHeader.TextColor3=C.accent_purple; delayHeader.Font=Enum.Font.GothamBold; delayHeader.TextSize=12; delayHeader.TextXAlignment=Enum.TextXAlignment.Left
    local function makeDelayInput(parent, label, color, yOff, defaultVal, onFocusLost)
        local lbl2=Instance.new("TextLabel",parent)
        lbl2.Size=UDim2.new(0.42,0,0,24); lbl2.Position=UDim2.new(0,12,0,yOff); lbl2.BackgroundTransparency=1
        lbl2.Text=label; lbl2.TextColor3=color; lbl2.Font=Enum.Font.GothamBold; lbl2.TextSize=12; lbl2.TextXAlignment=Enum.TextXAlignment.Left
        local box2=Instance.new("TextBox",parent)
        box2.Size=UDim2.new(0.5,-6,0,24); box2.Position=UDim2.new(0.5,-2,0,yOff)
        box2.BackgroundColor3=C.bg_input; box2.TextColor3=C.text_white; box2.PlaceholderColor3=C.text_muted
        box2.Font=Enum.Font.GothamBold; box2.TextSize=13; box2.BorderSizePixel=0; box2.ClearTextOnFocus=false; box2.Text=tostring(defaultVal)
        Instance.new("UICorner",box2).CornerRadius=UDim.new(0,7)
        local bs2=addStroke(box2,C.border_dim,1,0.3)
        box2.Focused:Connect(function() tw(bs2,{Color=color,Transparency=0},0.2) end)
        box2.FocusLost:Connect(function() tw(bs2,{Color=C.border_dim,Transparency=0.3},0.2); onFocusLost(box2) end)
        return box2
    end
    collectDelayRef=makeDelayInput(delayCard,"Collect",C.accent_green,30,collectDelay,function(b)
        local n=tonumber(b.Text); if n and n>=0 then collectDelay=n; collectDelayBox.Text=tostring(n); savedSettings["collect_delay"]=n; saveSettings(savedSettings) else b.Text=tostring(collectDelay) end
    end)
    buyDelayRef=makeDelayInput(delayCard,"Buy",C.accent_gold,62,buyDelay,function(b)
        local n=tonumber(b.Text); if n and n>=0.05 then buyDelay=n; buyDelayBox.Text=tostring(n); savedSettings["buy_delay"]=n; saveSettings(savedSettings) else b.Text=tostring(buyDelay) end
    end)
    cashDelayRef=makeDelayInput(delayCard,"Cash",C.accent_cyan,94,cashDelay,function(b)
        local n=tonumber(b.Text); if n and n>0 then cashDelay=n; cashDelayBox.Text=tostring(n); savedSettings["cash_delay"]=n; saveSettings(savedSettings) else b.Text=tostring(cashDelay) end
    end)

    -- PARAR TUDO
    local stopCard=makeCard(configFrame,50,7)
    local stopBtn=Instance.new("TextButton",stopCard)
    stopBtn.Size=UDim2.new(1,-20,0,36); stopBtn.Position=UDim2.new(0,10,0,7)
    stopBtn.BackgroundColor3=C.accent_red; stopBtn.BackgroundTransparency=0.2; stopBtn.BorderSizePixel=0
    stopBtn.Text="Parar Tudo"; stopBtn.TextColor3=C.text_white; stopBtn.Font=Enum.Font.GothamBold; stopBtn.TextSize=15
    Instance.new("UICorner",stopBtn).CornerRadius=UDim.new(0,10); addStroke(stopBtn,C.accent_red,1.5,0.4); addRipple(stopBtn)
    stopBtn.MouseEnter:Connect(function() tw(stopBtn,{BackgroundTransparency=0,Size=UDim2.new(1,-16,0,38)},0.2) end)
    stopBtn.MouseLeave:Connect(function() tw(stopBtn,{BackgroundTransparency=0.2,Size=UDim2.new(1,-20,0,36)},0.2) end)
    stopBtn.MouseButton1Click:Connect(function()
        setAutoCollect(false); setAutoBuy(false); setAutoCash(false); infJumpEnabled=false; ijUpd(false)
        -- Para o Auto Rebirth tambem
        local rb = _G._BFHub_RebirthState
        if rb and rb.enabled and rb.stop then rb.stop() end
        tweenBounce(stopBtn,{BackgroundColor3=Color3.fromRGB(255,100,100)},0.1); task.wait(0.5); tw(stopBtn,{BackgroundColor3=C.accent_red},0.3)
        notify("Parar Tudo","Todos os sistemas desativados!",3,C.accent_red)
    end)
end
buildConfigTab()

-- ════════════════════════════════════════════════════════════════
-- ABA REBIRTH (v2.5) — com bridge global para presets
-- ════════════════════════════════════════════════════════════════
local function buildRebirthTab()
    local rebirthRemote = game:GetService("ReplicatedStorage").Remotes.Rebirth

    -- ── Card 1: Botao Manual ──────────────────────────────────
    local manualCard = makeCard(rebirthFrame, 72, 1)
    local mcs = manualCard:FindFirstChildWhichIsA("UIStroke"); if mcs then tw(mcs,{Color=C.accent_orange},0) end
    local manualHeader = Instance.new("TextLabel", manualCard)
    manualHeader.Size=UDim2.new(1,-16,0,20); manualHeader.Position=UDim2.new(0,12,0,6)
    manualHeader.BackgroundTransparency=1; manualHeader.Text="[R]  Rebirth Manual"
    manualHeader.TextColor3=C.accent_orange; manualHeader.Font=Enum.Font.GothamBold; manualHeader.TextSize=13; manualHeader.TextXAlignment=Enum.TextXAlignment.Left
    local manualBtn = Instance.new("TextButton", manualCard)
    manualBtn.Size=UDim2.new(1,-20,0,34); manualBtn.Position=UDim2.new(0,10,0,30)
    manualBtn.BackgroundColor3=Color3.fromRGB(100,50,15); manualBtn.BackgroundTransparency=0.1; manualBtn.BorderSizePixel=0
    manualBtn.Text="Fazer Rebirth Agora"; manualBtn.TextColor3=C.text_white; manualBtn.Font=Enum.Font.GothamBold; manualBtn.TextSize=14
    Instance.new("UICorner",manualBtn).CornerRadius=UDim.new(0,10); addStroke(manualBtn,C.accent_orange,1.5,0.3); addRipple(manualBtn)
    manualBtn.MouseEnter:Connect(function() tw(manualBtn,{BackgroundColor3=Color3.fromRGB(140,70,20),BackgroundTransparency=0},0.18) end)
    manualBtn.MouseLeave:Connect(function() tw(manualBtn,{BackgroundColor3=Color3.fromRGB(100,50,15),BackgroundTransparency=0.1},0.18) end)

    -- ── Card 2: Auto Rebirth toggle + delay inline ────────────
    local autoCard = makeCard(rebirthFrame, 96, 2)
    local acs2 = autoCard:FindFirstChildWhichIsA("UIStroke"); if acs2 then tw(acs2,{Color=C.accent_orange},0) end
    local autoIcon = Instance.new("TextLabel", autoCard)
    autoIcon.Size=UDim2.new(0,30,0,30); autoIcon.Position=UDim2.new(0,10,0,12); autoIcon.BackgroundTransparency=1
    autoIcon.Text="[R]"; autoIcon.Font=Enum.Font.GothamBold; autoIcon.TextSize=14; autoIcon.TextColor3=C.text_muted
    local autoLbl = Instance.new("TextLabel", autoCard)
    autoLbl.Size=UDim2.new(0.6,0,0,30); autoLbl.Position=UDim2.new(0,46,0,12); autoLbl.BackgroundTransparency=1
    autoLbl.Text="Auto Rebirth"; autoLbl.TextColor3=C.text_white; autoLbl.Font=Enum.Font.GothamBold; autoLbl.TextSize=15; autoLbl.TextXAlignment=Enum.TextXAlignment.Left
    local rbTrack = Instance.new("Frame", autoCard)
    rbTrack.Size=UDim2.new(0,64,0,30); rbTrack.Position=UDim2.new(1,-80,0,12)
    rbTrack.BackgroundColor3=C.off_color; rbTrack.BackgroundTransparency=0.25; rbTrack.BorderSizePixel=0
    Instance.new("UICorner",rbTrack).CornerRadius=UDim.new(1,0)
    local rbKnob = Instance.new("Frame", rbTrack)
    rbKnob.Size=UDim2.new(0,24,0,24); rbKnob.Position=UDim2.new(0,3,0,3)
    rbKnob.BackgroundColor3=C.text_white; rbKnob.BorderSizePixel=0; Instance.new("UICorner",rbKnob).CornerRadius=UDim.new(1,0)

    local rbSep = Instance.new("Frame", autoCard)
    rbSep.Size=UDim2.new(1,-20,0,1); rbSep.Position=UDim2.new(0,10,0,50)
    rbSep.BackgroundColor3=C.border_dim; rbSep.BorderSizePixel=0

    local delayRowLbl = Instance.new("TextLabel", autoCard)
    delayRowLbl.Size=UDim2.new(0.5,0,0,22); delayRowLbl.Position=UDim2.new(0,12,0,58)
    delayRowLbl.BackgroundTransparency=1; delayRowLbl.Text="Delay (seg)"
    delayRowLbl.TextColor3=C.accent_orange; delayRowLbl.Font=Enum.Font.GothamBold; delayRowLbl.TextSize=12; delayRowLbl.TextXAlignment=Enum.TextXAlignment.Left

    local delayBox = Instance.new("TextBox", autoCard)
    delayBox.Size=UDim2.new(0.38,-6,0,22); delayBox.Position=UDim2.new(0.58,0,0,58)
    delayBox.BackgroundColor3=C.bg_input; delayBox.BorderSizePixel=0
    delayBox.Text=tostring(rebirthData.delay); delayBox.TextColor3=C.text_white
    delayBox.PlaceholderColor3=C.text_muted; delayBox.Font=Enum.Font.GothamBold; delayBox.TextSize=13; delayBox.ClearTextOnFocus=false
    Instance.new("UICorner",delayBox).CornerRadius=UDim.new(0,7)
    local dbs = addStroke(delayBox,C.border_dim,1,0.3)
    delayBox.Focused:Connect(function() tw(dbs,{Color=C.accent_orange,Transparency=0},0.2) end)
    delayBox.FocusLost:Connect(function()
        tw(dbs,{Color=C.border_dim,Transparency=0.3},0.2)
        local v=tonumber(delayBox.Text)
        if v and v>=1 then rebirthData.delay=v; saveRebirthData(); notify("Auto Rebirth","Delay: "..v.."s",2,C.accent_orange)
        else delayBox.Text=tostring(rebirthData.delay) end
    end)

    local rbToggleBtn = Instance.new("TextButton", autoCard)
    rbToggleBtn.Size=UDim2.new(1,0,0,50); rbToggleBtn.Position=UDim2.new(0,0,0,0)
    rbToggleBtn.BackgroundTransparency=1; rbToggleBtn.Text=""; rbToggleBtn.ZIndex=5; addRipple(rbToggleBtn)

    -- ── Card 3: Alvo ──────────────────────────────────────────
    local cfgCard = makeCard(rebirthFrame, 54, 3)
    local cfgS = cfgCard:FindFirstChildWhichIsA("UIStroke"); if cfgS then tw(cfgS,{Color=C.accent_gold},0) end
    local targetLbl = Instance.new("TextLabel", cfgCard)
    targetLbl.Size=UDim2.new(0.55,0,0,22); targetLbl.Position=UDim2.new(0,12,0,16)
    targetLbl.BackgroundTransparency=1; targetLbl.Text="Alvo (0 = infinito)"
    targetLbl.TextColor3=C.accent_gold; targetLbl.Font=Enum.Font.GothamBold; targetLbl.TextSize=12; targetLbl.TextXAlignment=Enum.TextXAlignment.Left
    local targetBox = Instance.new("TextBox", cfgCard)
    targetBox.Size=UDim2.new(0.38,-6,0,22); targetBox.Position=UDim2.new(0.58,0,0,16)
    targetBox.BackgroundColor3=C.bg_input; targetBox.BorderSizePixel=0
    targetBox.Text=tostring(rebirthData.targetCount); targetBox.TextColor3=C.text_white
    targetBox.PlaceholderColor3=C.text_muted; targetBox.Font=Enum.Font.GothamBold; targetBox.TextSize=13; targetBox.ClearTextOnFocus=false
    Instance.new("UICorner",targetBox).CornerRadius=UDim.new(0,7)
    local tbs = addStroke(targetBox,C.border_dim,1,0.3)
    targetBox.Focused:Connect(function() tw(tbs,{Color=C.accent_gold,Transparency=0},0.2) end)
    targetBox.FocusLost:Connect(function()
        tw(tbs,{Color=C.border_dim,Transparency=0.3},0.2)
        local v=tonumber(targetBox.Text)
        if v and v>=0 then rebirthData.targetCount=math.floor(v); saveRebirthData(); notify("Auto Rebirth",v==0 and "Alvo: infinito" or "Alvo: "..v,2,C.accent_gold)
        else targetBox.Text=tostring(rebirthData.targetCount) end
    end)

    -- ── Card 4: Contador ──────────────────────────────────────
    local statCard = makeCard(rebirthFrame, 72, 4)
    local statS = statCard:FindFirstChildWhichIsA("UIStroke"); if statS then tw(statS,{Color=C.accent_gold},0) end
    local statHeader = Instance.new("TextLabel", statCard)
    statHeader.Size=UDim2.new(1,-16,0,20); statHeader.Position=UDim2.new(0,12,0,4); statHeader.BackgroundTransparency=1
    statHeader.Text="Contador de Rebirths"; statHeader.TextColor3=C.accent_gold; statHeader.Font=Enum.Font.GothamBold; statHeader.TextSize=12; statHeader.TextXAlignment=Enum.TextXAlignment.Left
    local statLbl = Instance.new("TextLabel", statCard)
    statLbl.Size=UDim2.new(0.6,0,0,28); statLbl.Position=UDim2.new(0,12,0,26); statLbl.BackgroundTransparency=1
    statLbl.Text="Total: "..rebirthData.totalDone; statLbl.TextColor3=C.text_white; statLbl.Font=Enum.Font.GothamBold; statLbl.TextSize=18; statLbl.TextXAlignment=Enum.TextXAlignment.Left
    local resetBtn = Instance.new("TextButton", statCard)
    resetBtn.Size=UDim2.new(0,80,0,24); resetBtn.Position=UDim2.new(1,-90,0.5,-12)
    resetBtn.BackgroundColor3=Color3.fromRGB(60,20,20); resetBtn.BorderSizePixel=0
    resetBtn.Text="Zerar"; resetBtn.TextColor3=C.accent_red; resetBtn.Font=Enum.Font.GothamBold; resetBtn.TextSize=12
    Instance.new("UICorner",resetBtn).CornerRadius=UDim.new(0,7); addStroke(resetBtn,C.accent_red,1,0.4); addRipple(resetBtn)
    resetBtn.MouseEnter:Connect(function() tw(resetBtn,{BackgroundColor3=Color3.fromRGB(90,30,30)},0.15) end)
    resetBtn.MouseLeave:Connect(function() tw(resetBtn,{BackgroundColor3=Color3.fromRGB(60,20,20)},0.15) end)
    resetBtn.MouseButton1Click:Connect(function()
        rebirthData.totalDone=0; saveRebirthData(); statLbl.Text="Total: 0"
        notify("Rebirth","Contador zerado.",2,C.accent_red)
    end)

    -- ── Logica Auto Rebirth ───────────────────────────────────
    local rbEnabled = false; local rbThread = nil; local sessionCount = 0

    local function updateRbToggle(state)
        tw(rbTrack,{BackgroundColor3=state and C.accent_orange or C.off_color},0.25)
        TweenService:Create(rbKnob,TweenInfo.new(0.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
            {Position=state and UDim2.new(1,-27,0,3) or UDim2.new(0,3,0,3)}):Play()
        autoIcon.TextColor3=state and C.accent_orange or C.text_muted
        if acs2 then tw(acs2,{Color=state and C.accent_orange or C.border_dim},0.25) end
        -- sincroniza bridge global
        _G._BFHub_RebirthState.enabled = state
    end

    local function stopRb()
        rbEnabled=false
        if rbThread then task.cancel(rbThread); rbThread=nil end
        updateRbToggle(false)
        notify("Auto Rebirth","Parado. Sessao: "..sessionCount.." rebirths.",3,C.accent_orange)
    end

    local function startRb()
        if rbEnabled then return end  -- evita double-start vindo do preset
        rbEnabled=true; sessionCount=0; updateRbToggle(true)
        notify("Auto Rebirth","Iniciado! Delay: "..rebirthData.delay.."s",2,C.accent_orange)
        rbThread=task.spawn(function()
            while rbEnabled do
                task.wait(rebirthData.delay)
                if not rbEnabled then break end
                local ok = pcall(function() rebirthRemote:FireServer() end)
                if ok then
                    rebirthData.totalDone+=1; sessionCount+=1
                    saveRebirthData(); statLbl.Text="Total: "..rebirthData.totalDone
                    if rebirthData.targetCount>0 and sessionCount>=rebirthData.targetCount then
                        notify("Auto Rebirth","Meta de "..rebirthData.targetCount.." atingida!",4,C.accent_green)
                        stopRb(); break
                    end
                else
                    notify("Auto Rebirth","Erro ao fazer rebirth.",3,C.accent_red); stopRb(); break
                end
            end
        end)
    end

    -- Registra as funcoes na bridge global para acesso pelos presets
    _G._BFHub_RebirthState.start = startRb
    _G._BFHub_RebirthState.stop  = stopRb

    rbToggleBtn.MouseButton1Click:Connect(function()
        if rbEnabled then stopRb() else startRb() end
    end)

    manualBtn.MouseButton1Click:Connect(function()
        local ok = pcall(function() rebirthRemote:FireServer() end)
        if ok then
            rebirthData.totalDone+=1; saveRebirthData(); statLbl.Text="Total: "..rebirthData.totalDone
            notify("Rebirth","Rebirth #"..rebirthData.totalDone.." executado!",2,C.accent_orange)
            tweenBack(manualBtn,{BackgroundColor3=Color3.fromRGB(200,120,30)},0.15)
            task.wait(0.4); tw(manualBtn,{BackgroundColor3=Color3.fromRGB(100,50,15)},0.3)
        else
            notify("Rebirth","Erro ao disparar o remote.",3,C.accent_red)
        end
    end)
end
buildRebirthTab()

-- ════════════════════════════════════════════════════════════════
-- LOGICA: TPWALK
-- ════════════════════════════════════════════════════════════════
local tpwalkConn = nil
local function setupTpwalk(char)
    if tpwalkConn then tpwalkConn:Disconnect(); tpwalkConn=nil end
    local h = char:WaitForChild("Humanoid")
    tpwalkConn = RunService.Heartbeat:Connect(function(dt)
        if h.MoveDirection.Magnitude > 0 then char:TranslateBy(h.MoveDirection*tpwalkSpeed*dt) end
    end)
end
setupTpwalk(character)

-- ════════════════════════════════════════════════════════════════
-- LOGICA: JUMP POWER + INFJUMP
-- ════════════════════════════════════════════════════════════════
local function applyJump()
    if humanoid.UseJumpPower then humanoid.JumpPower=jpower else humanoid.JumpHeight=jpower end
end
applyJump()
humanoid:GetPropertyChangedSignal("JumpPower"):Connect(applyJump)
local ijDebounce = false
UserInputService.JumpRequest:Connect(function()
    if infJumpEnabled and not ijDebounce and character then
        local h = character:FindFirstChildWhichIsA("Humanoid")
        if h then ijDebounce=true; h:ChangeState(Enum.HumanoidStateType.Jumping); task.wait(0.05); ijDebounce=false end
    end
end)

-- ════════════════════════════════════════════════════════════════
-- RESPAWN
-- ════════════════════════════════════════════════════════════════
player.CharacterAdded:Connect(function(newChar)
    character=newChar; hrp=newChar:WaitForChild("HumanoidRootPart"); humanoid=newChar:WaitForChild("Humanoid")
    applyJump(); humanoid:GetPropertyChangedSignal("JumpPower"):Connect(applyJump); setupTpwalk(newChar)
    workspace.CurrentCamera.CameraSubject=humanoid; workspace.CurrentCamera.CameraType=Enum.CameraType.Custom
    notify("Respawn","Personagem recarregado!",2,C.accent_blue)
end)

-- ════════════════════════════════════════════════════════════════
-- LOADING SEQUENCE
-- ════════════════════════════════════════════════════════════════
local function runLoadingSequence(onComplete)
    task.spawn(function()
        task.wait(0.2); tw(lsTitle,{TextTransparency=0},0.8); task.wait(0.3); tw(lsVer,{TextTransparency=0},0.8)
    end)
    local steps = {
        {text="Conectando ao servidor...",      prog=0.15, wait=0.5},
        {text="Carregando dados salvos...",     prog=0.35, wait=0.5},
        {text="Inicializando interface...",     prog=0.55, wait=0.4},
        {text="Configurando automacoes...",     prog=0.75, wait=0.4},
        {text="Aplicando presets...",           prog=0.90, wait=0.35},
        {text="Pronto! [BF] v2.5",             prog=1.00, wait=0.4},
    }
    task.spawn(function()
        for _,step in ipairs(steps) do
            lsStatus.Text=step.text; tw(lsBar,{Size=UDim2.new(step.prog,0,1,0)},0.4,Enum.EasingStyle.Quad); task.wait(step.wait)
        end
        task.wait(0.3); particleActive=false
        tw(loadScreen,{BackgroundTransparency=1},0.6)
        for _,child in ipairs(loadScreen:GetDescendants()) do
            pcall(function()
                if child:IsA("TextLabel") then tw(child,{TextTransparency=1},0.4) end
                if child:IsA("Frame") then tw(child,{BackgroundTransparency=1},0.4) end
            end)
        end
        task.wait(0.65); loadScreen.Visible=false; onComplete()
    end)
end

runLoadingSequence(function()
    task.spawn(function()
        mainFrame.Visible=true; mainStrokeGlowActive=true
        for _,g in ipairs(allGlows) do g.Visible=true; g.Size=UDim2.new(0,0,0,0) end
        mainFrame.Size=UDim2.new(0,0,0,0)
        tweenBack(mainFrame,{Size=UDim2.new(0,HUB_W,0,HUB_H)},0.55)
        task.wait(0.08)
        for i,g in ipairs(allGlows) do
            local e=(i-1)*14+8; tweenBack(g,{Size=UDim2.new(0,HUB_W+e,0,HUB_H+e)},0.5); task.wait(0.04)
        end
        syncGlows(); task.wait(0.5)
        tw(mainStroke,{Transparency=0.7},0.2); task.wait(0.2); tw(mainStroke,{Transparency=0},0.3)
        notify("Build a Bamboo Factory Hub","v2.5 carregado!",3,C.accent_green)

        -- AntiAFK automatico ao carregar
        task.delay(1.5, function()
            activateAntiAFK(nil)
        end)

        -- Autoload
        task.delay(0.6, function()
            local alName = loadAutoload()
            if alName and ProfileSystem.profiles[alName] then
                local data = ProfileSystem:loadProfile(alName)
                if data then applyProfileData(data); updProfList(); notify("Autoload","Preset '"..alName.."' carregado!",3,C.accent_blue) end
            end
        end)
    end)
end)

print("Build a Bamboo Factory Hub v2.5 -- Carregado!")
