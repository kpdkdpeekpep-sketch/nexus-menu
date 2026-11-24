--[=[
    MM2 HUB v2 — combined build
    Tabs: Combat, Visuals, Movement, Fling, Misc
    PC menu key: L
    Touch devices: floating MM2 OPEN button

    Note: client-side actions (auto-shoot, gun pickup and fling) depend on
    the current MM2 implementation and Roblox server ownership/validation.
    The optional remote loader is disabled by default.
]=]

-- ══════════════════════════════════════════════
-- SERVICES / SETTINGS
-- ══════════════════════════════════════════════
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local lp = Players.LocalPlayer

local LOADER_URL = "" -- оставь пустым, если внешний лоадер не нужен

local cfg = {
    killRange = 12,
    flySpeed = 60,
    walkSpeed = 16,
    jumpPower = 50,
    flingTime = 1.2,
    aimSmooth = 0.35,
    aimDistance = 250,
    shotCooldown = 0.7,
    coinFarmSpeed = 95,
    coinHeight = 4, -- вертикальный отступ над монетой по оси Y
}

local state = {
    killAura = false,
    autoGun = false,
    noclip = false,
    fly = false,
    infJump = false,
    esp = false,
    espNames = true,
    espHighlight = true,
    espGun = false,
    speed = false,
    jump = false,
    aimMurderer = false,
    autoShoot = false,
    coinFarm = false,
}

local conns = {}
local externalConns = {}
local flyObjs = {}
local noclipOriginal = {}
local espObjs = {}
local flinging = false
local lastAutoShot = 0
local shuttingDown = false
local killAllBusy = false
local farmConnection = nil
local farmVelocity = nil
local farmCurrentCoin = nil
local farmNextScan = 0
local farmLastTouched = setmetatable({}, {__mode = "k"})
local farmRestoreNoclip = false

local function trackExternal(connection)
    table.insert(externalConns, connection)
    return connection
end

-- ══════════════════════════════════════════════
-- HELPERS
-- ══════════════════════════════════════════════
local function getHRP(player)
    local character = (player or lp).Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getHum(player)
    local character = (player or lp).Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function findTool(player, name)
    player = player or lp
    local character = player.Character
    local backpack = player:FindFirstChildOfClass("Backpack")
    return (character and character:FindFirstChild(name))
        or (backpack and backpack:FindFirstChild(name))
end

local function roleOf(player)
    if findTool(player, "Knife") then
        return "Murderer"
    elseif findTool(player, "Gun") then
        return "Sheriff"
    end
    return "Innocent"
end

local function findByRole(role)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= lp and roleOf(player) == role and getHRP(player) then
            return player
        end
    end
    return nil
end

local function findMurderer()
    local myHRP = getHRP()
    local bestTarget, bestDistance = nil, math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= lp and roleOf(player) == "Murderer" then
            local hrp = getHRP(player)
            local humanoid = getHum(player)
            if hrp and humanoid and humanoid.Health > 0 then
                local distance = myHRP
                    and (hrp.Position - myHRP.Position).Magnitude
                    or 0
                if distance < bestDistance then
                    bestTarget = player
                    bestDistance = distance
                end
            end
        end
    end

    return bestTarget
end

-- ══════════════════════════════════════════════
-- GUI BASE
-- ══════════════════════════════════════════════
local ACCENT = Color3.fromRGB(122, 100, 255)
local BG = Color3.fromRGB(22, 22, 30)
local PANEL = Color3.fromRGB(30, 30, 41)
local ITEM = Color3.fromRGB(40, 40, 54)
local TEXT = Color3.fromRGB(235, 235, 245)
local DIM = Color3.fromRGB(150, 150, 170)

local guiParent
if typeof(gethui) == "function" then
    local ok, result = pcall(gethui)
    if ok and result then
        guiParent = result
    end
end
if not guiParent then
    guiParent = lp:WaitForChild("PlayerGui")
end

local gui = Instance.new("ScreenGui")
gui.Name = "MM2HubV2_" .. HttpService:GenerateGUID(false)
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.Parent = guiParent

local espFolder = Instance.new("Folder")
espFolder.Name = "ESP"
espFolder.Parent = gui

local function corner(object, radius)
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, radius or 8)
    uiCorner.Parent = object
    return uiCorner
end

local function stroke(object, color, thickness)
    local uiStroke = Instance.new("UIStroke")
    uiStroke.Color = color or Color3.fromRGB(60, 60, 80)
    uiStroke.Thickness = thickness or 1
    uiStroke.Parent = object
    return uiStroke
end

local function tween(object, duration, properties)
    TweenService:Create(
        object,
        TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        properties
    ):Play()
end

-- ══════════════════════════════════════════════
-- ANIMATED STARTUP SCREEN
-- ══════════════════════════════════════════════
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local loadingOverlay = Instance.new("Frame")
loadingOverlay.Name = "LoadingOverlay"
loadingOverlay.Size = UDim2.fromScale(1, 1)
loadingOverlay.BackgroundColor3 = Color3.fromRGB(10, 10, 17)
loadingOverlay.BackgroundTransparency = 0.04
loadingOverlay.BorderSizePixel = 0
loadingOverlay.ZIndex = 100
loadingOverlay.Parent = gui

local loadingCard = Instance.new("Frame")
loadingCard.Size = UDim2.fromOffset(350, 190)
loadingCard.Position = UDim2.new(0.5, -175, 0.5, -95)
loadingCard.BackgroundColor3 = Color3.fromRGB(25, 24, 38)
loadingCard.BorderSizePixel = 0
loadingCard.ZIndex = 101
loadingCard.Parent = loadingOverlay
corner(loadingCard, 18)
stroke(loadingCard, Color3.fromRGB(108, 91, 210), 1.4)

local loadingTopLine = Instance.new("Frame")
loadingTopLine.Size = UDim2.new(1, -36, 0, 3)
loadingTopLine.Position = UDim2.fromOffset(18, 17)
loadingTopLine.BackgroundColor3 = ACCENT
loadingTopLine.BorderSizePixel = 0
loadingTopLine.ZIndex = 102
loadingTopLine.Parent = loadingCard
corner(loadingTopLine, 3)
local loadingGradient = Instance.new("UIGradient")
loadingGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(85, 205, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(122, 100, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(205, 100, 255)),
})
loadingGradient.Parent = loadingTopLine

local loadingLogo = Instance.new("TextLabel")
loadingLogo.Size = UDim2.new(1, -36, 0, 42)
loadingLogo.Position = UDim2.fromOffset(18, 31)
loadingLogo.BackgroundTransparency = 1
loadingLogo.Font = Enum.Font.GothamBlack
loadingLogo.TextSize = 28
loadingLogo.TextColor3 = TEXT
loadingLogo.Text = "MM2 HUB"
loadingLogo.ZIndex = 102
loadingLogo.Parent = loadingCard

local loadingSubtitle = Instance.new("TextLabel")
loadingSubtitle.Size = UDim2.new(1, -36, 0, 20)
loadingSubtitle.Position = UDim2.fromOffset(18, 76)
loadingSubtitle.BackgroundTransparency = 1
loadingSubtitle.Font = Enum.Font.Gotham
loadingSubtitle.TextSize = 11
loadingSubtitle.TextColor3 = DIM
loadingSubtitle.Text = "Preparing your session..."
loadingSubtitle.ZIndex = 102
loadingSubtitle.Parent = loadingCard

local loadingTrack = Instance.new("Frame")
loadingTrack.Size = UDim2.new(1, -36, 0, 7)
loadingTrack.Position = UDim2.fromOffset(18, 119)
loadingTrack.BackgroundColor3 = Color3.fromRGB(48, 47, 66)
loadingTrack.BorderSizePixel = 0
loadingTrack.ZIndex = 102
loadingTrack.Parent = loadingCard
corner(loadingTrack, 5)

local loadingFill = Instance.new("Frame")
loadingFill.Size = UDim2.new(0, 0, 1, 0)
loadingFill.BackgroundColor3 = ACCENT
loadingFill.BorderSizePixel = 0
loadingFill.ZIndex = 103
loadingFill.Parent = loadingTrack
corner(loadingFill, 5)
local fillGradient = Instance.new("UIGradient")
fillGradient.Color = loadingGradient.Color
fillGradient.Parent = loadingFill

local loadingPercent = Instance.new("TextLabel")
loadingPercent.Size = UDim2.fromOffset(50, 18)
loadingPercent.Position = UDim2.new(1, -68, 0, 137)
loadingPercent.BackgroundTransparency = 1
loadingPercent.Font = Enum.Font.GothamBold
loadingPercent.TextSize = 11
loadingPercent.TextColor3 = TEXT
loadingPercent.TextXAlignment = Enum.TextXAlignment.Right
loadingPercent.Text = "0%"
loadingPercent.ZIndex = 102
loadingPercent.Parent = loadingCard

local loadingHint = Instance.new("TextLabel")
loadingHint.Size = UDim2.new(1, -36, 0, 18)
loadingHint.Position = UDim2.fromOffset(18, 158)
loadingHint.BackgroundTransparency = 1
loadingHint.Font = Enum.Font.Gotham
loadingHint.TextSize = 10
loadingHint.TextColor3 = DIM
loadingHint.TextXAlignment = Enum.TextXAlignment.Left
loadingHint.Text = "Initializing interface"
loadingHint.ZIndex = 102
loadingHint.Parent = loadingCard

local function playLoadingAnimation()
    task.spawn(function()
        local messages = {
            {0.28, "Loading interface modules"},
            {0.62, "Preparing tabs and controls"},
            {0.88, "Finishing setup"},
        }
        for _, item in ipairs(messages) do
            task.delay(item[1] * 1.35, function()
                if loadingHint and loadingHint.Parent then
                    loadingHint.Text = item[2]
                end
            end)
        end

        local progressTween = TweenService:Create(
            loadingFill,
            TweenInfo.new(1.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {Size = UDim2.new(1, 0, 1, 0)}
        )
        progressTween:Play()
        for percent = 1, 100 do
            if not loadingPercent.Parent then break end
            loadingPercent.Text = tostring(percent) .. "%"
            task.wait(0.0135)
        end
        task.wait(0.12)

        if loadingOverlay and loadingOverlay.Parent then
            tween(loadingOverlay, 0.28, {BackgroundTransparency = 1})
            tween(loadingCard, 0.28, {BackgroundTransparency = 1})
            for _, object in ipairs(loadingOverlay:GetDescendants()) do
                if object:IsA("TextLabel") then
                    tween(object, 0.2, {TextTransparency = 1, BackgroundTransparency = 1})
                elseif object:IsA("Frame") then
                    tween(object, 0.2, {BackgroundTransparency = 1})
                elseif object:IsA("UIStroke") then
                    tween(object, 0.2, {Transparency = 1})
                end
            end
            task.wait(0.32)
            if loadingOverlay and loadingOverlay.Parent then
                loadingOverlay:Destroy()
            end
        end
    end)
end

local win = Instance.new("Frame")
win.Name = "MainWindow"
win.Size = UDim2.fromOffset(520, 360)
win.Position = UDim2.new(0.5, -260, 0.5, -180)
win.BackgroundColor3 = BG
win.BorderSizePixel = 0
win.Parent = gui
corner(win, 12)
stroke(win)

-- Header / dragging
local top = Instance.new("Frame")
top.Name = "Header"
top.Size = UDim2.new(1, 0, 0, 38)
top.BackgroundColor3 = PANEL
top.BorderSizePixel = 0
top.Parent = win
corner(top, 12)

local topFix = Instance.new("Frame")
topFix.Size = UDim2.new(1, 0, 0, 12)
topFix.Position = UDim2.new(0, 0, 1, -12)
topFix.BackgroundColor3 = PANEL
topFix.BorderSizePixel = 0
topFix.Parent = top

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -90, 1, 0)
title.Position = UDim2.fromOffset(14, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = TEXT
title.Text = "MM2 Hub <font color='#7a64ff'>v2</font>"
title.RichText = true
title.Parent = top

local function headButton(text, xOffset, color)
    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(26, 26)
    button.Position = UDim2.new(1, xOffset, 0, 6)
    button.BackgroundColor3 = color
    button.Text = text
    button.Font = Enum.Font.GothamBold
    button.TextSize = 14
    button.TextColor3 = Color3.new(1, 1, 1)
    button.AutoButtonColor = true
    button.Parent = top
    corner(button, 7)
    return button
end

local closeBtn = headButton("✕", -34, Color3.fromRGB(200, 70, 80))
local hideBtn = headButton("–", -66, ITEM)

local dragging = false
local dragStart
local startPosition

top.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = win.Position
    end
end)

trackExternal(UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        win.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end))

trackExternal(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end))

-- Sidebar
local side = Instance.new("Frame")
side.Size = UDim2.new(0, 120, 1, -50)
side.Position = UDim2.fromOffset(8, 44)
side.BackgroundColor3 = PANEL
side.BorderSizePixel = 0
side.Parent = win
corner(side, 10)

local sideLayout = Instance.new("UIListLayout")
sideLayout.Padding = UDim.new(0, 4)
sideLayout.Parent = side

local sidePadding = Instance.new("UIPadding")
sidePadding.PaddingTop = UDim.new(0, 6)
sidePadding.PaddingLeft = UDim.new(0, 6)
sidePadding.PaddingRight = UDim.new(0, 6)
sidePadding.Parent = side

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -144, 1, -66)
content.Position = UDim2.fromOffset(136, 44)
content.BackgroundTransparency = 1
content.Parent = win

-- ══════════════════════════════════════════════
-- TABS / GUI ELEMENTS
-- ══════════════════════════════════════════════
local tabs = {}

local function createTab(name, icon)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 32)
    button.BackgroundColor3 = ITEM
    button.BackgroundTransparency = 1
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 13
    button.TextColor3 = DIM
    button.Text = icon .. "  " .. name
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.AutoButtonColor = false
    button.Parent = side
    corner(button, 8)

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 10)
    padding.Parent = button

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = ACCENT
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new()
    page.Visible = false
    page.Parent = content

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.Parent = page

    local pagePadding = Instance.new("UIPadding")
    pagePadding.PaddingRight = UDim.new(0, 6)
    pagePadding.Parent = page

    tabs[name] = {btn = button, page = page}

    button.MouseButton1Click:Connect(function()
        for _, tab in pairs(tabs) do
            tab.page.Visible = false
            tween(tab.btn, 0.15, {
                BackgroundTransparency = 1,
                TextColor3 = DIM,
            })
        end
        page.Visible = true
        tween(button, 0.15, {
            BackgroundTransparency = 0,
            TextColor3 = TEXT,
        })
    end)

    return page
end

local function addSection(page, sectionText)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 11
    label.TextColor3 = ACCENT
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = string.upper(sectionText)
    label.Parent = page
    return label
end

local function addToggle(page, labelText, defaultValue, callback)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = ITEM
    row.Text = ""
    row.AutoButtonColor = false
    row.Parent = page
    corner(row, 8)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Position = UDim2.fromOffset(12, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextColor3 = TEXT
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = labelText
    label.Parent = row

    local pill = Instance.new("Frame")
    pill.Size = UDim2.fromOffset(38, 20)
    pill.Position = UDim2.new(1, -50, 0.5, -10)
    pill.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
    pill.Parent = row
    corner(pill, 10)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(16, 16)
    knob.Position = UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.Parent = pill
    corner(knob, 8)

    local enabled = false
    local function set(value, silent)
        enabled = value == true
        tween(pill, 0.15, {
            BackgroundColor3 = enabled and ACCENT or Color3.fromRGB(70, 70, 90),
        })
        tween(knob, 0.15, {
            Position = enabled
                and UDim2.new(1, -18, 0.5, -8)
                or UDim2.new(0, 2, 0.5, -8),
        })
        if not silent and callback then
            callback(enabled)
        end
    end

    row.MouseButton1Click:Connect(function()
        set(not enabled, false)
    end)

    if defaultValue then
        set(true, true)
    end

    return set
end

local function addSlider(page, labelText, minimum, maximum, defaultValue, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 50)
    row.BackgroundColor3 = ITEM
    row.Parent = page
    corner(row, 8)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -70, 0, 24)
    label.Position = UDim2.fromOffset(12, 2)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextColor3 = TEXT
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = labelText
    label.Parent = row

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.fromOffset(50, 24)
    valueLabel.Position = UDim2.new(1, -62, 0, 2)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 13
    valueLabel.TextColor3 = ACCENT
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = row

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -24, 0, 6)
    bar.Position = UDim2.fromOffset(12, 34)
    bar.BackgroundColor3 = Color3.fromRGB(65, 65, 85)
    bar.Parent = row
    corner(bar, 3)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = ACCENT
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.Parent = bar
    corner(fill, 3)

    local function setValue(value)
        value = math.clamp(math.floor(value + 0.5), minimum, maximum)
        valueLabel.Text = tostring(value)
        local alpha = (value - minimum) / math.max(1, maximum - minimum)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        if callback then
            callback(value)
        end
    end

    setValue(defaultValue)

    local sliderDragging = false
    local function fromInput(x)
        local width = math.max(1, bar.AbsoluteSize.X)
        local alpha = math.clamp((x - bar.AbsolutePosition.X) / width, 0, 1)
        setValue(minimum + (maximum - minimum) * alpha)
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            sliderDragging = true
            fromInput(input.Position.X)
        end
    end)

    trackExternal(UserInputService.InputChanged:Connect(function(input)
        if sliderDragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            fromInput(input.Position.X)
        end
    end))

    trackExternal(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            sliderDragging = false
        end
    end))
end

local function addButton(page, buttonText, callback, color)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 34)
    button.BackgroundColor3 = color or ITEM
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 13
    button.TextColor3 = TEXT
    button.Text = buttonText
    button.AutoButtonColor = true
    button.Parent = page
    corner(button, 8)
    button.MouseButton1Click:Connect(function()
        if callback then
            callback(button)
        end
    end)
    return button
end

-- Status label
local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -150, 0, 14)
statusLbl.Position = UDim2.new(0, 136, 1, -16)
statusLbl.BackgroundTransparency = 1
statusLbl.Font = Enum.Font.Gotham
statusLbl.TextSize = 11
statusLbl.TextColor3 = DIM
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.Text = "Готово"
statusLbl.Parent = win

local function setStatus(message, color)
    if statusLbl and statusLbl.Parent then
        statusLbl.Text = tostring(message)
        statusLbl.TextColor3 = color or DIM
    end
end

-- ══════════════════════════════════════════════
-- MOVEMENT / COMBAT FUNCTIONS
-- ══════════════════════════════════════════════
local function killAuraTick()
    local myHRP = getHRP()
    local humanoid = getHum()
    if not myHRP or not humanoid then
        return
    end

    local knife = findTool(lp, "Knife")
    if not knife then
        return
    end

    if knife.Parent ~= lp.Character then
        pcall(function()
            humanoid:EquipTool(knife)
        end)
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        local targetHumanoid = getHum(player)
        local targetHRP = getHRP(player)
        if player ~= lp and targetHumanoid and targetHRP
            and targetHumanoid.Health > 0
            and (targetHRP.Position - myHRP.Position).Magnitude <= cfg.killRange then
            pcall(function()
                myHRP.CFrame = targetHRP.CFrame * CFrame.new(0, 0, 2)
                knife:Activate()
            end)
        end
    end
end

local function autoGunTick()
    local myHRP = getHRP()
    if not myHRP then
        return
    end

    local drop = workspace:FindFirstChild("GunDrop", true)
    if drop and drop:IsA("BasePart") and typeof(firetouchinterest) == "function" then
        pcall(function()
            firetouchinterest(myHRP, drop, 0)
            firetouchinterest(myHRP, drop, 1)
        end)
    end
end

-- One-pass kill attempt for each living player; requires the Knife tool.
-- The game server still decides whether each hit is valid.
local function killAllWithKnife()
    if killAllBusy then
        return
    end

    local knife = findTool(lp, "Knife")
    local humanoid = getHum()
    local myHRP = getHRP()
    if not knife or not humanoid or not myHRP then
        setStatus("Нужен нож и живой персонаж", Color3.fromRGB(228, 96, 106))
        return
    end

    killAllBusy = true
    task.spawn(function()
        local origin = myHRP.CFrame
        if knife.Parent ~= lp.Character then
            pcall(function() humanoid:EquipTool(knife) end)
            task.wait(0.2)
        end

        local attempted = 0
        for _, target in ipairs(Players:GetPlayers()) do
            if target ~= lp and target.Parent == Players then
                local targetRoot = getHRP(target)
                local targetHumanoid = getHum(target)
                local currentRoot = getHRP()
                if targetRoot and targetHumanoid and targetHumanoid.Health > 0 and currentRoot then
                    attempted += 1
                    setStatus("Атака: " .. target.Name, Color3.fromRGB(232, 176, 78))
                    pcall(function()
                        currentRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 2)
                        knife:Activate()
                    end)
                    task.wait(0.18)
                end
            end
        end

        local currentRoot = getHRP()
        if currentRoot and currentRoot.Parent then
            pcall(function() currentRoot.CFrame = origin end)
        end
        setStatus("Попытки атаки: " .. tostring(attempted) .. " · результат зависит от сервера", Color3.fromRGB(232, 176, 78))
        killAllBusy = false
    end)
end

local function setNoclip(enabled)
    state.noclip = enabled == true

    if conns.noclip then
        conns.noclip:Disconnect()
        conns.noclip = nil
    end

    if state.noclip then
        conns.noclip = RunService.Stepped:Connect(function()
            local character = lp.Character
            if not character then
                return
            end
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    if noclipOriginal[part] == nil then
                        noclipOriginal[part] = part.CanCollide
                    end
                    part.CanCollide = false
                end
            end
        end)
    else
        for part, originalValue in pairs(noclipOriginal) do
            if part and part.Parent then
                pcall(function()
                    part.CanCollide = originalValue
                end)
            end
            noclipOriginal[part] = nil
        end
    end
end

local setFly -- forward declaration; coin farm can stop manual flight

-- ══════════════════════════════════════════════
-- COIN FARM: Coin_Server
-- Roblox vertical axis is Y; coinHeight=4 means 4 studs above the coin.
-- ══════════════════════════════════════════════
local function findNearestCoin()
    local root = getHRP()
    if not root then
        return nil
    end

    local nearest, nearestDistance = nil, math.huge
    local now = os.clock()
    local coinContainer = workspace:FindFirstChild("CoinContainer", true)
    local searchRoot = coinContainer or workspace
    for _, object in ipairs(searchRoot:GetDescendants()) do
        if object.Name == "Coin_Server" and object:IsA("BasePart") and object.Parent then
            local lastTouched = farmLastTouched[object]
            if not lastTouched or now - lastTouched > 1.8 then
                local distance = (object.Position - root.Position).Magnitude
                if distance < nearestDistance then
                    nearest = object
                    nearestDistance = distance
                end
            end
        end
    end
    return nearest
end

local function stopCoinFarm()
    state.coinFarm = false
    if farmConnection then
        farmConnection:Disconnect()
        farmConnection = nil
    end
    if farmVelocity then
        farmVelocity:Destroy()
        farmVelocity = nil
    end

    local root = getHRP()
    if root then
        pcall(function() root.AssemblyLinearVelocity = Vector3.zero end)
    end

    farmCurrentCoin = nil
    if not farmRestoreNoclip and state.noclip then
        setNoclip(false)
    end
    farmRestoreNoclip = false
end

local function setCoinFarm(enabled)
    enabled = enabled == true
    if enabled == state.coinFarm then
        return
    end

    if not enabled then
        stopCoinFarm()
        setStatus("Фарм монет выключен")
        return
    end

    local root = getHRP()
    if not root then
        setStatus("Персонаж ещё не загружен", Color3.fromRGB(228, 96, 106))
        return
    end

    -- Avoid two movement controllers fighting over the character.
    if state.fly then
        setFly(false)
    end

    farmRestoreNoclip = state.noclip
    if not state.noclip then
        setNoclip(true)
    end

    state.coinFarm = true
    farmCurrentCoin = nil
    farmNextScan = 0

    farmConnection = RunService.Heartbeat:Connect(function()
        if not state.coinFarm or shuttingDown then
            return
        end

        local characterRoot = getHRP()
        if not characterRoot then
            return
        end

        if not farmVelocity or farmVelocity.Parent ~= characterRoot then
            if farmVelocity then
                farmVelocity:Destroy()
            end
            farmVelocity = Instance.new("BodyVelocity")
            farmVelocity.Name = "MM2CoinFarmVelocity"
            farmVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            farmVelocity.P = 12000
            farmVelocity.Velocity = Vector3.zero
            farmVelocity.Parent = characterRoot
        end

        local now = os.clock()
        if not farmCurrentCoin or not farmCurrentCoin.Parent or now >= farmNextScan then
            farmCurrentCoin = findNearestCoin()
            farmNextScan = now + 0.55
        end

        if not farmCurrentCoin then
            farmVelocity.Velocity = Vector3.zero
            setStatus("Ищу Coin_Server...", Color3.fromRGB(232, 176, 78))
            return
        end

        local touchAvailable = typeof(firetouchinterest) == "function"
        local verticalOffset = touchAvailable and cfg.coinHeight or 0
        local targetPosition = farmCurrentCoin.Position + Vector3.new(0, verticalOffset, 0)
        local delta = targetPosition - characterRoot.Position
        local distance = delta.Magnitude

        local touchDistance = touchAvailable and 2.2 or 0.9
        if distance <= touchDistance then
            farmVelocity.Velocity = Vector3.zero
            if touchAvailable then
                pcall(function()
                    firetouchinterest(characterRoot, farmCurrentCoin, 0)
                    firetouchinterest(characterRoot, farmCurrentCoin, 1)
                end)
            end
            farmLastTouched[farmCurrentCoin] = now
            farmCurrentCoin = nil
            farmNextScan = 0
            setStatus("Монета обработана · ищу следующую", Color3.fromRGB(74, 200, 140))
        else
            farmVelocity.Velocity = delta.Unit * cfg.coinFarmSpeed
            setStatus("Лечу к Coin_Server · " .. tostring(math.floor(distance)) .. " studs")
        end
    end)

    setStatus("Фарм Coin_Server включён", Color3.fromRGB(74, 200, 140))
end

local function cleanFly()
    for _, object in ipairs(flyObjs) do
        if object and object.Parent then
            object:Destroy()
        end
    end
    flyObjs = {}

    if conns.fly then
        conns.fly:Disconnect()
        conns.fly = nil
    end

    local humanoid = getHum()
    if humanoid then
        humanoid.PlatformStand = false
    end
end

setFly = function(enabled)
    state.fly = enabled == true
    cleanFly()

    local myHRP = getHRP()
    if not state.fly or not myHRP then
        return
    end

    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bodyVelocity.Velocity = Vector3.zero
    bodyVelocity.Parent = myHRP

    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    bodyGyro.D = 100
    bodyGyro.P = 9000
    bodyGyro.Parent = myHRP

    flyObjs = {bodyVelocity, bodyGyro}

    conns.fly = RunService.RenderStepped:Connect(function()
        local camera = workspace.CurrentCamera
        local humanoid = getHum()
        if not camera or not bodyVelocity.Parent then
            return
        end

        if humanoid then
            humanoid.PlatformStand = true
        end

        local key = Enum.KeyCode
        local direction = Vector3.zero
        if UserInputService:IsKeyDown(key.W) then
            direction += camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(key.S) then
            direction -= camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(key.A) then
            direction -= camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(key.D) then
            direction += camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(key.Space) then
            direction += Vector3.yAxis
        end
        if UserInputService:IsKeyDown(key.LeftControl) then
            direction -= Vector3.yAxis
        end

        bodyVelocity.Velocity = direction.Magnitude > 0
            and direction.Unit * cfg.flySpeed
            or Vector3.zero
        bodyGyro.CFrame = camera.CFrame
    end)
end

trackExternal(UserInputService.JumpRequest:Connect(function()
    if state.infJump then
        local humanoid = getHum()
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end))

-- ══════════════════════════════════════════════
-- AIM / AUTO SHOOT
-- ══════════════════════════════════════════════
local function getAimPart(target)
    local character = target and target.Character
    if not character then
        return nil
    end

    return character:FindFirstChild("Head")
        or character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("HumanoidRootPart")
end

-- True only when the ray from the camera reaches the target without
-- hitting a wall or another character first.
local function canSeeTarget(target)
    local camera = workspace.CurrentCamera
    local targetPart = getAimPart(target)
    local character = target and target.Character

    if not camera or not targetPart or not character then
        return false
    end

    local origin = camera.CFrame.Position
    local direction = targetPart.Position - origin
    if direction.Magnitude <= 0.01 then
        return false
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {lp.Character}
    params.IgnoreWater = true

    local result = workspace:Raycast(origin, direction, params)
    -- A hit on the target's character means the line of sight is clear.
    -- No hit is also treated as clear (for parts with CanQuery disabled).
    return result == nil or result.Instance:IsDescendantOf(character)
end

local function aimAtMurderer()
    -- Aim assistance is active only while the local player is the Sheriff
    -- and still has the Sheriff gun in Character or Backpack.
    if roleOf(lp) ~= "Sheriff" or not findTool(lp, "Gun") then
        return nil, false
    end

    local target = findMurderer()
    local camera = workspace.CurrentCamera
    local targetPart = target and getAimPart(target)
    local targetHumanoid = target and getHum(target)

    if not target or not targetPart or not targetHumanoid
        or targetHumanoid.Health <= 0 or not camera then
        return nil, false
    end

    -- Do not track or shoot a murderer through walls.
    if not canSeeTarget(target) then
        return nil, false
    end

    local aimPosition = targetPart.Position
    local distance = (aimPosition - camera.CFrame.Position).Magnitude
    local inRange = distance <= cfg.aimDistance

    if inRange then
        local desired = CFrame.lookAt(camera.CFrame.Position, aimPosition)
        camera.CFrame = camera.CFrame:Lerp(
            desired,
            math.clamp(cfg.aimSmooth, 0.05, 0.85)
        )
    end

    return target, inRange
end

local function autoShootTick(target)
    if roleOf(lp) ~= "Sheriff" or not target then
        return
    end

    local targetHRP = getHRP(target)
    local myHRP = getHRP()
    local camera = workspace.CurrentCamera
    if not targetHRP or not myHRP or not camera then
        return
    end

    if (targetHRP.Position - myHRP.Position).Magnitude > cfg.aimDistance then
        return
    end
    if not canSeeTarget(target) then
        return
    end

    local direction = targetHRP.Position - camera.CFrame.Position
    if direction.Magnitude < 0.01 then
        return
    end
    direction = direction.Unit

    if camera.CFrame.LookVector:Dot(direction) < 0.975 then
        return
    end

    local gun = findTool(lp, "Gun")
    if not gun then
        return
    end

    if gun.Parent ~= lp.Character then
        local humanoid = getHum()
        if humanoid then
            pcall(function()
                humanoid:EquipTool(gun)
            end)
        end
        return
    end

    if os.clock() - lastAutoShot < cfg.shotCooldown then
        return
    end

    lastAutoShot = os.clock()
    pcall(function()
        gun:Activate()
    end)
end

-- ══════════════════════════════════════════════
-- ESP
-- ══════════════════════════════════════════════
local ROLE_COLORS = {
    Sheriff = Color3.fromRGB(70, 170, 255),
    Murderer = Color3.fromRGB(255, 60, 60),
    Innocent = Color3.fromRGB(80, 230, 110),
}

local function clearESP(player)
    local object = espObjs[player]
    if object then
        if object.hl then
            object.hl:Destroy()
        end
        if object.bb then
            object.bb:Destroy()
        end
        espObjs[player] = nil
    end
end

local function clearAllESP()
    for player in pairs(espObjs) do
        clearESP(player)
    end
    local gunESP = espFolder:FindFirstChild("GunESP")
    if gunESP then
        gunESP:Destroy()
    end
end

local function updateESP()
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= lp then
            local character = player.Character
            local head = character and character:FindFirstChild("Head")
            local humanoid = getHum(player)

            if state.esp and character and head and humanoid and humanoid.Health > 0 then
                local object = espObjs[player]
                if not object or object.char ~= character then
                    clearESP(player)
                    object = {char = character}

                    local highlight = Instance.new("Highlight")
                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    highlight.FillTransparency = 0.6
                    highlight.OutlineTransparency = 0
                    highlight.Adornee = character
                    highlight.Parent = espFolder

                    local billboard = Instance.new("BillboardGui")
                    billboard.Size = UDim2.fromOffset(160, 44)
                    billboard.StudsOffset = Vector3.new(0, 3, 0)
                    billboard.AlwaysOnTop = true
                    billboard.Adornee = head
                    billboard.Parent = espFolder

                    local label = Instance.new("TextLabel")
                    label.Size = UDim2.new(1, 0, 1, 0)
                    label.BackgroundTransparency = 1
                    label.Font = Enum.Font.GothamBold
                    label.TextSize = 13
                    label.TextStrokeTransparency = 0.3
                    label.RichText = false
                    label.Parent = billboard

                    object.hl = highlight
                    object.bb = billboard
                    object.label = label
                    espObjs[player] = object
                end

                local role = roleOf(player)
                local color = ROLE_COLORS[role] or TEXT
                object.hl.Enabled = state.espHighlight
                object.hl.FillColor = color
                object.hl.OutlineColor = color
                object.bb.Enabled = state.espNames

                local distance = math.floor((head.Position - camera.CFrame.Position).Magnitude)
                object.label.TextColor3 = color
                object.label.Text = string.format(
                    "%s\n[%s] %dHP · %dm",
                    player.DisplayName,
                    role,
                    math.floor(humanoid.Health),
                    distance
                )
            else
                clearESP(player)
            end
        end
    end

    local drop = workspace:FindFirstChild("GunDrop", true)
    local gunESP = espFolder:FindFirstChild("GunESP")
    if state.espGun and drop and drop:IsA("BasePart") then
        if not gunESP then
            gunESP = Instance.new("Highlight")
            gunESP.Name = "GunESP"
            gunESP.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            gunESP.FillColor = Color3.fromRGB(255, 215, 60)
            gunESP.OutlineColor = Color3.fromRGB(255, 215, 60)
            gunESP.Parent = espFolder
        end
        gunESP.Adornee = drop
    elseif gunESP then
        gunESP:Destroy()
    end
end

trackExternal(Players.PlayerRemoving:Connect(function(player)
    clearESP(player)
end))

-- ══════════════════════════════════════════════
-- FLING
-- ══════════════════════════════════════════════
local function flingPlayer(target, duration)
    if not target or target == lp then
        return false
    end

    local myHRP = getHRP()
    local targetHRP = getHRP(target)
    if not myHRP or not targetHRP then
        return false
    end

    local origin = myHRP.CFrame
    local wasNoclip = state.noclip
    local started = os.clock()
    local finished = false
    local connection

    local ok, err = pcall(function()
        if not wasNoclip then
            setNoclip(true)
        end

        connection = RunService.Heartbeat:Connect(function()
            local hrp = getHRP()
            local targetRoot = getHRP(target)
            local targetHumanoid = getHum(target)

            if not hrp or not targetRoot
                or (targetHumanoid and targetHumanoid.Health <= 0)
                or os.clock() - started >= duration then
                finished = true
                return
            end

            local elapsed = os.clock() - started
            local angle = elapsed * 20
            local offset = Vector3.new(
                math.cos(angle) * 1.2,
                0.35,
                math.sin(angle) * 1.2
            )

            hrp.CFrame = targetRoot.CFrame * CFrame.new(offset)
            local delta = targetRoot.Position - hrp.Position
            local direction = delta.Magnitude > 0.01 and delta.Unit
                or targetRoot.CFrame.LookVector

            hrp.AssemblyAngularVelocity = Vector3.new(0, 90000, 0)
            hrp.AssemblyLinearVelocity = direction * 850 + Vector3.new(0, 220, 0)
        end)

        while not finished and os.clock() - started < duration + 0.4 do
            task.wait(0.02)
        end
    end)

    finished = true
    if connection then
        connection:Disconnect()
    end

    local currentHRP = getHRP()
    if currentHRP and currentHRP.Parent then
        pcall(function()
            currentHRP.AssemblyAngularVelocity = Vector3.zero
            currentHRP.AssemblyLinearVelocity = Vector3.zero
            currentHRP.CFrame = origin
        end)
    end

    if not wasNoclip then
        setNoclip(false)
    end

    if not ok then
        warn("[MM2 HUB] Fling error: " .. tostring(err))
    end
    return ok
end

local function safeFling(getTarget, label)
    if flinging then
        return
    end

    flinging = true
    task.spawn(function()
        local ok, result = pcall(getTarget)
        local target = ok and result or nil

        if not target then
            setStatus("✖ " .. label .. ": цель не найдена", Color3.fromRGB(228, 96, 106))
        else
            setStatus("Флинг → " .. target.Name, Color3.fromRGB(232, 176, 78))
            local flingOK = flingPlayer(target, cfg.flingTime)
            if flingOK then
                setStatus("Попытка завершена · отлёт цели не подтверждён", Color3.fromRGB(232, 176, 78))
            else
                setStatus("Флинг не выполнен", Color3.fromRGB(228, 96, 106))
            end
        end

        flinging = false
    end)
end

-- ══════════════════════════════════════════════
-- CREATE PAGES
-- ══════════════════════════════════════════════
local pCombat = createTab("Combat", "⚔")
local pVisual = createTab("Visuals", "👁")
local pMove = createTab("Movement", "🏃")
local pFling = createTab("Fling", "🌀")
local pMisc = createTab("Misc", "⚙")
local pFarm = createTab("Farm", "🪙")

-- Combat
addSection(pCombat, "Убийца")
addToggle(pCombat, "Kill Aura (нужен нож)", false, function(value)
    state.killAura = value
end)
addSlider(pCombat, "Радиус Kill Aura", 5, 30, cfg.killRange, function(value)
    cfg.killRange = value
end)
addButton(pCombat, "☠  Убить всех (нужен нож)", killAllWithKnife, Color3.fromRGB(155, 55, 75))

addSection(pCombat, "Шериф")
addToggle(pCombat, "Авто подбор пистолета", false, function(value)
    state.autoGun = value
end)

addSection(pCombat, "Аим и стрельба")
addToggle(pCombat, "Aim на убийцу", false, function(value)
    state.aimMurderer = value
end)
addToggle(pCombat, "Auto Shoot (шериф)", false, function(value)
    state.autoShoot = value
end)
addSlider(pCombat, "Дистанция аима", 50, 500, cfg.aimDistance, function(value)
    cfg.aimDistance = value
end)
addSlider(pCombat, "Плавность аима", 5, 85, math.floor(cfg.aimSmooth * 100), function(value)
    cfg.aimSmooth = value / 100
end)
addSlider(pCombat, "Задержка выстрела (×0.1с)", 2, 20, math.floor(cfg.shotCooldown * 10), function(value)
    cfg.shotCooldown = value / 10
end)

-- Coin Farm
addSection(pFarm, "Автоматический сбор монет")
local farmInfo = Instance.new("TextLabel")
farmInfo.Size = UDim2.new(1, 0, 0, 44)
farmInfo.BackgroundTransparency = 1
farmInfo.Font = Enum.Font.Gotham
farmInfo.TextSize = 11
farmInfo.TextWrapped = true
farmInfo.TextYAlignment = Enum.TextYAlignment.Top
farmInfo.TextXAlignment = Enum.TextXAlignment.Left
farmInfo.TextColor3 = DIM
farmInfo.Text = "Ищет BasePart с именем Coin_Server и перемещает персонажа к ближайшей монете. Для принудительного touch executor должен поддерживать firetouchinterest."
farmInfo.Parent = pFarm
addToggle(pFarm, "Coin Farm (Coin_Server)", false, setCoinFarm)
addSlider(pFarm, "Скорость полёта", 20, 180, cfg.coinFarmSpeed, function(value)
    cfg.coinFarmSpeed = value
end)
addSlider(pFarm, "Высота над монетой (Y)", 0, 12, cfg.coinHeight, function(value)
    cfg.coinHeight = value
end)
addButton(pFarm, "■  Остановить фарм", function()
    setCoinFarm(false)
end, Color3.fromRGB(150, 60, 80))

-- Visuals
addSection(pVisual, "ESP игроков")
addToggle(pVisual, "ESP ролей", false, function(value)
    state.esp = value
    if not value then
        clearAllESP()
    end
end)
addToggle(pVisual, "Подсветка (Highlight)", true, function(value)
    state.espHighlight = value
end)
addToggle(pVisual, "Ник · роль · HP · дистанция", true, function(value)
    state.espNames = value
end)
addSection(pVisual, "Предметы")
addToggle(pVisual, "ESP пистолета", false, function(value)
    state.espGun = value
    if not value then
        local object = espFolder:FindFirstChild("GunESP")
        if object then
            object:Destroy()
        end
    end
end)

-- Movement
addSection(pMove, "Перемещение")
addToggle(pMove, "Ноклип", false, setNoclip)
addToggle(pMove, "Флай (WASD · Space/Ctrl)", false, setFly)
addSlider(pMove, "Скорость флая", 20, 200, cfg.flySpeed, function(value)
    cfg.flySpeed = value
end)
addToggle(pMove, "Бесконечный прыжок", false, function(value)
    state.infJump = value
end)
addSection(pMove, "Параметры персонажа")
addToggle(pMove, "Своя скорость бега", false, function(value)
    state.speed = value
    if not value then
        local humanoid = getHum()
        if humanoid then
            humanoid.WalkSpeed = 16
        end
    end
end)
addSlider(pMove, "WalkSpeed", 16, 120, cfg.walkSpeed, function(value)
    cfg.walkSpeed = value
end)
addToggle(pMove, "Своя высота прыжка", false, function(value)
    state.jump = value
    if not value then
        local humanoid = getHum()
        if humanoid then
            humanoid.UseJumpPower = true
            humanoid.JumpPower = 50
        end
    end
end)
addSlider(pMove, "JumpPower", 50, 200, cfg.jumpPower, function(value)
    cfg.jumpPower = value
end)

-- Fling
addSection(pFling, "Быстрый флинг")
local flingInfo = Instance.new("TextLabel")
flingInfo.Size = UDim2.new(1, 0, 0, 48)
flingInfo.BackgroundTransparency = 1
flingInfo.Font = Enum.Font.Gotham
flingInfo.TextSize = 11
flingInfo.TextWrapped = true
flingInfo.TextYAlignment = Enum.TextYAlignment.Top
flingInfo.TextXAlignment = Enum.TextXAlignment.Left
flingInfo.TextColor3 = DIM
flingInfo.Text = "Важно: клиент Solara не управляет физикой чужого персонажа на сервере. Этот режим может двигать только твой персонаж; гарантированный отлёт других игроков требует серверного кода в собственной игре."
flingInfo.Parent = pFling
addSlider(pFling, "Длительность (×0.1с)", 5, 40, math.floor(cfg.flingTime * 10), function(value)
    cfg.flingTime = value / 10
end)
addButton(pFling, "🌀  Флинг шерифа", function()
    safeFling(function()
        return findByRole("Sheriff")
    end, "Шериф")
end)
addButton(pFling, "🌀  Флинг убийцы", function()
    safeFling(function()
        return findByRole("Murderer")
    end, "Убийца")
end)
addButton(pFling, "💥  Флинг всех", function()
    if flinging then
        return
    end

    flinging = true
    task.spawn(function()
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= lp and getHRP(player) then
                setStatus("Флинг → " .. player.Name)
                flingPlayer(player, cfg.flingTime)
                task.wait(0.15)
            end
        end
        setStatus("Обход игроков завершён")
        flinging = false
    end)
end, Color3.fromRGB(150, 60, 80))

addSection(pFling, "Выбрать игрока")
local playerListFrame = Instance.new("Frame")
playerListFrame.Size = UDim2.new(1, 0, 0, 0)
playerListFrame.AutomaticSize = Enum.AutomaticSize.Y
playerListFrame.BackgroundTransparency = 1
playerListFrame.Parent = pFling

local playerListLayout = Instance.new("UIListLayout")
playerListLayout.Padding = UDim.new(0, 4)
playerListLayout.Parent = playerListFrame

local function refreshPlayers()
    for _, child in ipairs(playerListFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= lp then
            local button = Instance.new("TextButton")
            button.Size = UDim2.new(1, 0, 0, 30)
            button.BackgroundColor3 = ITEM
            button.Font = Enum.Font.Gotham
            button.TextSize = 12
            button.TextColor3 = TEXT
            button.Text = player.DisplayName .. "  (@" .. player.Name .. ")"
            button.Parent = playerListFrame
            corner(button, 7)
            button.MouseButton1Click:Connect(function()
                safeFling(function()
                    if player.Parent == Players then
                        return player
                    end
                    return nil
                end, player.Name)
            end)
        end
    end
end

addButton(pFling, "↻  Обновить список игроков", refreshPlayers)
trackExternal(Players.PlayerAdded:Connect(function()
    task.wait(0.5)
    if not shuttingDown then
        refreshPlayers()
    end
end))
trackExternal(Players.PlayerRemoving:Connect(function()
    task.wait(0.1)
    if not shuttingDown then
        refreshPlayers()
    end
end))
refreshPlayers()

-- Misc / optional remote loader
local function fetchWithTimeout(url, timeout)
    local done, succeeded, result = false, false, nil
    task.spawn(function()
        succeeded, result = pcall(function()
            return game:HttpGet(url)
        end)
        done = true
    end)

    local waited = 0
    while not done and waited < timeout do
        task.wait(0.1)
        waited += 0.1
    end

    if not done then
        return false, "таймаут " .. tostring(timeout) .. " c"
    end
    return succeeded, result
end

addSection(pMisc, "Внешний лоадер")
local loaderBusy = false
local loaderButton
loaderButton = addButton(pMisc, "▶  Запустить внешний лоадер", function()
    if loaderBusy then
        return
    end
    if LOADER_URL == "" then
        setStatus("✖ LOADER_URL не указан", Color3.fromRGB(228, 96, 106))
        return
    end

    loaderBusy = true
    loaderButton.Text = "Загрузка..."
    task.spawn(function()
        setStatus("1/3 Скачиваю лоадер...", Color3.fromRGB(232, 176, 78))
        local okGet, body = fetchWithTimeout(LOADER_URL, 15)
        if not okGet or type(body) ~= "string" then
            setStatus("✖ Скачивание: " .. tostring(body), Color3.fromRGB(228, 96, 106))
            loaderButton.Text = "▶  Повторить"
            loaderBusy = false
            return
        end

        setStatus("2/3 Компилирую (" .. #body .. " байт)...", Color3.fromRGB(232, 176, 78))
        if type(loadstring) ~= "function" then
            setStatus("✖ loadstring недоступен", Color3.fromRGB(228, 96, 106))
            loaderButton.Text = "▶  Повторить"
            loaderBusy = false
            return
        end

        local chunk, compileError = loadstring(body)
        if not chunk then
            setStatus("✖ Компиляция: " .. tostring(compileError), Color3.fromRGB(228, 96, 106))
            loaderButton.Text = "▶  Повторить"
            loaderBusy = false
            return
        end

        setStatus("3/3 Запускаю лоадер...", Color3.fromRGB(232, 176, 78))
        local runOK, runError = pcall(chunk)
        if runOK then
            setStatus("Лоадер выполнен", Color3.fromRGB(74, 200, 140))
            loaderButton.Text = "✔  Выполнено"
        else
            setStatus("✖ Лоадер: " .. tostring(runError), Color3.fromRGB(228, 96, 106))
            loaderButton.Text = "▶  Повторить"
        end
        loaderBusy = false
    end)
end, ACCENT)

addSection(pMisc, "Меню")

-- ══════════════════════════════════════════════
-- MAIN LOOPS
-- ══════════════════════════════════════════════
conns.main = RunService.Heartbeat:Connect(function(dt)
    if shuttingDown then
        return
    end

    if state.killAura and not flinging then
        killAuraTick()
    end
    if state.autoGun then
        autoGunTick()
    end

    local humanoid = getHum()
    if humanoid then
        if state.speed then
            humanoid.WalkSpeed = cfg.walkSpeed
        end
        if state.jump then
            humanoid.UseJumpPower = true
            humanoid.JumpPower = cfg.jumpPower
        end
    end

    conns.espTimer = (conns.espTimer or 0) + dt
    if conns.espTimer >= 0.15 then
        conns.espTimer = 0
        if state.esp or state.espGun then
            updateESP()
        end
    end
end)

conns.aim = RunService.RenderStepped:Connect(function()
    if shuttingDown or (not state.aimMurderer and not state.autoShoot) then
        return
    end

    -- Never run aim/auto-shoot while the local player is not Sheriff.
    if roleOf(lp) ~= "Sheriff" or not findTool(lp, "Gun") then
        return
    end

    local target, inRange = aimAtMurderer()
    if state.autoShoot and target and inRange and canSeeTarget(target) then
        autoShootTick(target)
    end
end)

trackExternal(lp.CharacterAdded:Connect(function()
    task.wait(1)
    if shuttingDown then
        return
    end
    if state.fly then
        setFly(true)
    end
    if state.noclip then
        setNoclip(true)
    end
end))

-- ══════════════════════════════════════════════
-- PC / MOBILE MENU CONTROLS
-- ══════════════════════════════════════════════
local hidden = false

local mobileButton = Instance.new("TextButton")
mobileButton.Name = "MobileOpenButton"
mobileButton.Size = UDim2.fromOffset(64, 54)
mobileButton.Position = UDim2.new(0, 14, 0.72, 0)
mobileButton.BackgroundColor3 = ACCENT
mobileButton.TextColor3 = Color3.new(1, 1, 1)
mobileButton.Font = Enum.Font.GothamBold
mobileButton.TextSize = 12
mobileButton.Text = "MM2\nOPEN"
mobileButton.TextWrapped = true
mobileButton.Visible = false
mobileButton.AutoButtonColor = true
mobileButton.Parent = gui
corner(mobileButton, 13)
stroke(mobileButton, Color3.fromRGB(170, 150, 255), 1)

local function setMenuVisible(visible)
    hidden = not visible
    win.Visible = visible
    mobileButton.Visible = UserInputService.TouchEnabled and hidden
end

local function toggleMenu()
    setMenuVisible(not win.Visible)
end

hideBtn.MouseButton1Click:Connect(toggleMenu)
closeBtn.MouseButton1Click:Connect(toggleMenu)
mobileButton.MouseButton1Click:Connect(function()
    setMenuVisible(true)
end)

trackExternal(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or shuttingDown then
        return
    end
    if input.KeyCode == Enum.KeyCode.L then
        toggleMenu()
    end
end))

-- ══════════════════════════════════════════════
-- SHUTDOWN
-- ══════════════════════════════════════════════
local function shutdown()
    if shuttingDown then
        return
    end
    shuttingDown = true

    for key in pairs(state) do
        state[key] = false
    end

    stopCoinFarm()
    setNoclip(false)
    cleanFly()
    clearAllESP()

    for _, connection in pairs(conns) do
        if typeof(connection) == "RBXScriptConnection" then
            connection:Disconnect()
        end
    end
    for _, connection in ipairs(externalConns) do
        if typeof(connection) == "RBXScriptConnection" then
            connection:Disconnect()
        end
    end

    gui:Destroy()
end

addButton(pMisc, "⛔  Выключить всё и закрыть", shutdown, Color3.fromRGB(180, 55, 65))

-- First tab
if tabs.Combat then
    tabs.Combat.page.Visible = true
    tabs.Combat.btn.BackgroundTransparency = 0
    tabs.Combat.btn.TextColor3 = TEXT
end

setMenuVisible(true)
setStatus("MM2 Hub v2 готов · L — меню")
playLoadingAnimation()
