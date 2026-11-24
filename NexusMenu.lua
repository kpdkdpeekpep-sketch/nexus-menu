--[=[
    NEXUS MM2 HUB v3 — ultimate build
    Tabs: Combat, Visuals, Movement, Trolling, Fling, Farm, Skins, Stats, Misc
    PC menu key: L
    Touch devices: floating MM2 OPEN button

    Note: client-side actions (auto-shoot, gun pickup and fling) depend on
    the current MM2 implementation and Roblox server ownership/validation.
    True invisibility, forced death, and restricted-room teleports require server authority
    and are intentionally not faked by this client script.
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
local Lighting = game:GetService("Lighting")

local lp = Players.LocalPlayer

-- Solara compatibility: use executor APIs only when they exist; all core UI
-- features rely on standard client Luau APIs. Optional touch support is detected.
local EXECUTOR_CAPS = {
    gethui = type(gethui) == "function",
    firetouchinterest = type(firetouchinterest) == "function",
    loadstring = type(loadstring) == "function",
}

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
    fieldOfView = 70,
    trollSpeed = 42,
    trollShakeIntensity = 5,
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
    crosshair = false,
    fpsBoost = false,
    trollSpeed = false,
    trollFakeLag = false,
    trollShake = false,
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
local farmPendingCoin = nil
local farmPendingAt = 0
local farmCoinsCollected = 0
local fpsOriginal = {}
local fpsBoostActive = false
local originalFov = nil
local crosshairObject = nil
local voteRunning = false
local voteCancelled = false
local votePanel = nil
local voteMapBox = nil
local voteStatusLabel = nil
local farmRestoreNoclip = false
local originalAvatarDescription = nil
local avatarBusy = false
local trollLagOverlay = nil
local trollShakeClock = 0
local trollShakeBound = false
local lastAppliedAvatarName = nil

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
if EXECUTOR_CAPS.gethui then
    local ok, result = pcall(gethui)
    if ok and result then
        guiParent = result
    end
end
if not guiParent then
    local ok, result = pcall(function()
        return lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui", 10)
    end)
    if ok then
        guiParent = result
    end
end
if not guiParent then
    error("NEXUS MM2 HUB: не найден PlayerGui для создания меню")
end

-- Prevent duplicate windows when the script is executed again in Solara.
local previousGui = guiParent:FindFirstChild("NEXUS_MM2_HUB_V3")
if previousGui then
    pcall(function() previousGui:Destroy() end)
end

local gui = Instance.new("ScreenGui")
gui.Name = "NEXUS_MM2_HUB_V3"
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
loadingLogo.Text = "NEXUS MM2 HUB"
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
title.Text = "NEXUS MM2 <font color='#7a64ff'>v3</font>"
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
local side = Instance.new("ScrollingFrame")
side.Size = UDim2.new(0, 120, 1, -50)
side.CanvasSize = UDim2.new()
side.AutomaticCanvasSize = Enum.AutomaticSize.Y
side.ScrollingDirection = Enum.ScrollingDirection.Y
side.ScrollBarThickness = 2
side.ScrollBarImageColor3 = ACCENT
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
-- TROLLING EFFECTS (LOCAL COSMETIC / SELF ONLY)
-- These effects do not alter network traffic or other players' characters.
-- ══════════════════════════════════════════════
local function ensureTrollLagOverlay()
    if trollLagOverlay and trollLagOverlay.Parent then
        return trollLagOverlay
    end

    local card = Instance.new("Frame")
    card.Name = "NexusFakeLagOverlay"
    card.Size = UDim2.fromOffset(238, 48)
    card.Position = UDim2.new(0.5, -119, 0, 58)
    card.BackgroundColor3 = Color3.fromRGB(48, 20, 28)
    card.BackgroundTransparency = 0.08
    card.BorderSizePixel = 0
    card.Visible = false
    card.ZIndex = 100
    card.Parent = gui
    corner(card, 10)
    stroke(card, Color3.fromRGB(235, 85, 105), 1)

    local label = Instance.new("TextLabel")
    label.Name = "LagText"
    label.Size = UDim2.new(1, -16, 1, 0)
    label.Position = UDim2.fromOffset(8, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextColor3 = Color3.fromRGB(255, 220, 225)
    label.Text = "⚠  CONNECTION UNSTABLE"
    label.ZIndex = 101
    label.Parent = card

    trollLagOverlay = card
    return card
end

local function setTrollFakeLag(enabled)
    state.trollFakeLag = enabled == true
    if conns.trollLag then
        conns.trollLag:Disconnect()
        conns.trollLag = nil
    end

    if not state.trollFakeLag then
        if trollLagOverlay then
            trollLagOverlay.Visible = false
        end
        setStatus("Fake Lag выключен · сетевое соединение не изменялось")
        return
    end

    local overlay = ensureTrollLagOverlay()
    local elapsed = 0
    overlay.Visible = false

    conns.trollLag = RunService.Heartbeat:Connect(function(dt)
        if shuttingDown or not state.trollFakeLag then
            return
        end
        elapsed += dt
        local phase = elapsed % 2.1
        local spike = phase < 0.32
        overlay.Visible = spike
        local label = overlay:FindFirstChild("LagText")
        if label then
            label.Text = phase < 0.16 and "⚠  LAG SPIKE · 999 MS" or "↻  RECONNECTING..."
        end
    end)

    setStatus("Fake Lag: локальная визуальная имитация · ping не меняется", Color3.fromRGB(232, 176, 78))
end

local function setTrollShake(enabled)
    state.trollShake = enabled == true
    if not state.trollShake then
        if trollShakeBound then
            pcall(function()
                RunService:UnbindFromRenderStep("NexusTrollCameraShake")
            end)
            trollShakeBound = false
        end
        setStatus("Тряска камеры выключена")
        return
    end

    if trollShakeBound then
        pcall(function()
            RunService:UnbindFromRenderStep("NexusTrollCameraShake")
        end)
        trollShakeBound = false
    end

    trollShakeClock = 0
    local bindOK, bindError = pcall(function()
        RunService:BindToRenderStep(
            "NexusTrollCameraShake",
            Enum.RenderPriority.Camera.Value + 1,
            function(dt)
                if not state.trollShake or shuttingDown then
                    return
                end
                local camera = workspace.CurrentCamera
                if not camera then
                    return
                end

                trollShakeClock += dt
                local strength = math.clamp(cfg.trollShakeIntensity / 10, 0.05, 1)
                local x = math.sin(trollShakeClock * 19) * 0.055 * strength
                local y = math.cos(trollShakeClock * 23) * 0.045 * strength
                local roll = math.sin(trollShakeClock * 17) * math.rad(1.8) * strength
                camera.CFrame = camera.CFrame * CFrame.new(x, y, 0) * CFrame.Angles(0, 0, roll)
            end
        )
    end)

    if bindOK then
        trollShakeBound = true
        setStatus("Тряска камеры включена · эффект только на твоём экране", Color3.fromRGB(74, 200, 140))
    else
        state.trollShake = false
        setStatus("Не удалось включить тряску: " .. tostring(bindError), Color3.fromRGB(228, 96, 106))
    end
end

local function stopTrollingEffects()
    setTrollFakeLag(false)
    setTrollShake(false)
    state.trollSpeed = false
    local humanoid = getHum()
    if humanoid then
        humanoid.WalkSpeed = state.speed and cfg.walkSpeed or 16
    end
    setStatus("Эффекты троллинга сброшены")
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
    farmPendingCoin = nil
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

        -- Count a coin only after the server removes it from the replicated world.
        if farmPendingCoin then
            if not farmPendingCoin.Parent then
                farmCoinsCollected += 1
                farmPendingCoin = nil
                setStatus("Монета подтверждена · всего " .. tostring(farmCoinsCollected), Color3.fromRGB(74, 200, 140))
            elseif now - farmPendingAt > 1.25 then
                farmLastTouched[farmPendingCoin] = now
                farmPendingCoin = nil
                setStatus("Касание отправлено · ожидаю следующую монету", Color3.fromRGB(232, 176, 78))
            else
                farmVelocity.Velocity = Vector3.zero
                return
            end
        end

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
            local touchedCoin = farmCurrentCoin
            if touchAvailable then
                pcall(function()
                    firetouchinterest(characterRoot, touchedCoin, 0)
                    firetouchinterest(characterRoot, touchedCoin, 1)
                end)
            end
            farmPendingCoin = touchedCoin
            farmPendingAt = now
            farmCurrentCoin = nil
            farmNextScan = now + 0.2
            setStatus("Касание отправлено · проверяю сбор", Color3.fromRGB(232, 176, 78))
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
-- LOCAL AVATAR LOOKUP BY ROBLOX USERNAME
-- This changes only the local character appearance where the client allows it.
-- It does not unlock MM2 knife/gun cosmetics or change server inventory.
-- ══════════════════════════════════════════════
local function fetchAvatarDescription(userId)
    local ok, description = pcall(function()
        if Players.GetHumanoidDescriptionFromUserIdAsync then
            return Players:GetHumanoidDescriptionFromUserIdAsync(userId)
        end
        -- Compatibility fallback for older Roblox clients.
        return Players:GetHumanoidDescriptionFromUserId(userId)
    end)
    if not ok then
        error(description)
    end
    return description
end

local function applyDescriptionToLocalCharacter(description)
    local humanoid = getHum()
    if not humanoid then
        error("Персонаж не загружен")
    end

    if not originalAvatarDescription then
        local ok, original = pcall(function()
            return humanoid:GetAppliedDescription()
        end)
        if ok and original then
            originalAvatarDescription = original
        end
    end

    if humanoid.ApplyDescriptionResetAsync then
        humanoid:ApplyDescriptionResetAsync(description)
    elseif humanoid.ApplyDescriptionAsync then
        humanoid:ApplyDescriptionAsync(description)
    else
        humanoid:ApplyDescription(description)
    end
end

local function applyAvatarByUsername(rawUsername)
    local username = tostring(rawUsername or ""):match("^%s*(.-)%s*$")
    if username == "" then
        setStatus("Введи Roblox username", Color3.fromRGB(228, 96, 106))
        return
    end
    if avatarBusy then
        setStatus("Уже загружаю аватар...", Color3.fromRGB(232, 176, 78))
        return
    end

    avatarBusy = true
    task.spawn(function()
        local ok, err = pcall(function()
            setStatus("Ищу пользователя: " .. username, Color3.fromRGB(232, 176, 78))
            local userId = Players:GetUserIdFromNameAsync(username)
            local description = fetchAvatarDescription(userId)
            if not description then
                error("Не удалось получить описание аватара")
            end

            setStatus("Применяю внешний вид @" .. username, Color3.fromRGB(232, 176, 78))
            applyDescriptionToLocalCharacter(description)
            lastAppliedAvatarName = username
            setStatus("Аватар @" .. username .. " применён локально", Color3.fromRGB(74, 200, 140))
        end)

        if not ok then
            setStatus("Ошибка смены аватара: " .. tostring(err), Color3.fromRGB(228, 96, 106))
        end
        avatarBusy = false
    end)
end

local function restoreOriginalAvatar()
    if avatarBusy then
        setStatus("Дождись завершения загрузки аватара", Color3.fromRGB(232, 176, 78))
        return
    end
    if not originalAvatarDescription then
        setStatus("Исходный вид ещё не сохранён", Color3.fromRGB(228, 96, 106))
        return
    end

    avatarBusy = true
    task.spawn(function()
        local ok, err = pcall(function()
            applyDescriptionToLocalCharacter(originalAvatarDescription)
            lastAppliedAvatarName = nil
            setStatus("Исходный аватар восстановлен локально", Color3.fromRGB(74, 200, 140))
        end)
        if not ok then
            setStatus("Ошибка восстановления: " .. tostring(err), Color3.fromRGB(228, 96, 106))
        end
        avatarBusy = false
    end)
end

-- ══════════════════════════════════════════════
-- CREATE PAGES
-- ══════════════════════════════════════════════
local pCombat = createTab("Combat", "⚔")
local pVisual = createTab("Visuals", "👁")
local pMove = createTab("Movement", "🏃")
local pTroll = createTab("Trolling", "😈")
local pFling = createTab("Fling", "🌀")
local pMisc = createTab("Misc", "⚙")
local pFarm = createTab("Farm", "🪙")
local pSkins = createTab("Skins", "🎭")
local pStats = createTab("Stats", "📊")

-- ══════════════════════════════════════════════
-- STATS / CLIENT TOOLS / MAP VOTE ASSISTANT
-- Public MM2 client scripts cannot grant server-side invisibility or teleport
-- a player into restricted rooms. Vote helper only activates a visible,
-- official map-vote GUI button when the game itself presents it.
-- ══════════════════════════════════════════════
local function setFOV(value)
    cfg.fieldOfView = math.clamp(math.floor(value + 0.5), 60, 120)
    local camera = workspace.CurrentCamera
    if camera then
        if originalFov == nil then
            originalFov = camera.FieldOfView
        end
        camera.FieldOfView = cfg.fieldOfView
    end
end

local function setCrosshair(enabled)
    state.crosshair = enabled == true
    if crosshairObject then
        crosshairObject:Destroy()
        crosshairObject = nil
    end
    if not state.crosshair then
        return
    end

    local holder = Instance.new("Frame")
    holder.Name = "NexusCrosshair"
    holder.Size = UDim2.fromOffset(24, 24)
    holder.AnchorPoint = Vector2.new(0.5, 0.5)
    holder.Position = UDim2.fromScale(0.5, 0.5)
    holder.BackgroundTransparency = 1
    holder.ZIndex = 90
    holder.Parent = gui

    local function line(size, position)
        local frame = Instance.new("Frame")
        frame.Size = size
        frame.Position = position
        frame.BackgroundColor3 = Color3.fromRGB(245, 245, 255)
        frame.BorderSizePixel = 0
        frame.ZIndex = 91
        frame.Parent = holder
        stroke(frame, Color3.fromRGB(15, 15, 20), 1)
    end

    line(UDim2.fromOffset(2, 8), UDim2.new(0.5, -1, 0, 0))
    line(UDim2.fromOffset(2, 8), UDim2.new(0.5, -1, 1, -8))
    line(UDim2.fromOffset(8, 2), UDim2.new(0, 0, 0.5, -1))
    line(UDim2.fromOffset(8, 2), UDim2.new(1, -8, 0.5, -1))
    crosshairObject = holder
end

local function setFPSBoost(enabled)
    enabled = enabled == true
    if enabled == fpsBoostActive then
        return
    end
    fpsBoostActive = enabled
    state.fpsBoost = enabled

    if enabled then
        fpsOriginal = {}
        local function disableProperty(object, property)
            local ok, current = pcall(function() return object[property] end)
            if ok and current == true then
                fpsOriginal[#fpsOriginal + 1] = {object = object, property = property, value = current}
                pcall(function() object[property] = false end)
            end
        end

        pcall(function()
            if Lighting.GlobalShadows then
                fpsOriginal[#fpsOriginal + 1] = {object = Lighting, property = "GlobalShadows", value = Lighting.GlobalShadows}
                Lighting.GlobalShadows = false
            end
        end)

        for _, object in ipairs(Lighting:GetDescendants()) do
            if object:IsA("PostEffect") then
                disableProperty(object, "Enabled")
            end
        end
        for _, object in ipairs(workspace:GetDescendants()) do
            if object:IsA("ParticleEmitter") or object:IsA("Trail")
                or object:IsA("Beam") or object:IsA("Smoke")
                or object:IsA("Fire") or object:IsA("Sparkles") then
                disableProperty(object, "Enabled")
            end
        end
        setStatus("FPS Boost включён · локальные эффекты отключены", Color3.fromRGB(74, 200, 140))
    else
        for _, entry in ipairs(fpsOriginal) do
            if entry.object and entry.object.Parent then
                pcall(function() entry.object[entry.property] = entry.value end)
            elseif entry.object == Lighting then
                pcall(function() Lighting[entry.property] = entry.value end)
            end
        end
        fpsOriginal = {}
        setStatus("Исходные графические эффекты восстановлены", Color3.fromRGB(74, 200, 140))
    end
end

local function normalizeMapText(value)
    return string.lower(tostring(value or "")):gsub("[^%w]", "")
end

local function isGuiVisible(object)
    local current = object
    while current do
        if current:IsA("GuiObject") and not current.Visible then
            return false
        end
        if current:IsA("ScreenGui") and not current.Enabled then
            return false
        end
        current = current.Parent
    end
    return true
end

local function findOfficialMapVoteButton(mapName)
    local playerGui = lp:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        return nil
    end

    local wanted = normalizeMapText(mapName)
    if wanted == "" then
        return nil
    end

    for _, object in ipairs(playerGui:GetDescendants()) do
        if object:IsA("GuiButton") and isGuiVisible(object) then
            local ancestry = string.lower(object:GetFullName())
            local inVoteUi = ancestry:find("vote", 1, true) or ancestry:find("map", 1, true)
            if inVoteUi then
                local textParts = {object.Name}
                if object:IsA("TextButton") then
                    table.insert(textParts, object.Text)
                end
                for _, child in ipairs(object:GetDescendants()) do
                    if child:IsA("TextLabel") or child:IsA("TextButton") then
                        table.insert(textParts, child.Text)
                    end
                end
                local combined = normalizeMapText(table.concat(textParts, " "))
                if combined:find(wanted, 1, true) then
                    return object
                end
            end
        end
    end
    return nil
end

local function updateVoteStatus(message, color)
    if voteStatusLabel and voteStatusLabel.Parent then
        voteStatusLabel.Text = tostring(message)
        voteStatusLabel.TextColor3 = color or DIM
    end
end

local function startVoteAssistant()
    if voteRunning then
        updateVoteStatus("Голосование уже ожидается", Color3.fromRGB(232, 176, 78))
        return
    end
    local mapName = voteMapBox and voteMapBox.Text or ""
    mapName = tostring(mapName):match("^%s*(.-)%s*$")
    if mapName == "" then
        updateVoteStatus("Введи точное название карты", Color3.fromRGB(228, 96, 106))
        return
    end

    voteRunning = true
    voteCancelled = false
    updateVoteStatus("Жду официальное меню голосования…", Color3.fromRGB(232, 176, 78))
    task.spawn(function()
        local deadline = os.clock() + 120
        while voteRunning and not voteCancelled and os.clock() < deadline and not shuttingDown do
            local button = findOfficialMapVoteButton(mapName)
            if button then
                local ok = pcall(function()
                    button:Activate()
                end)
                if ok then
                    updateVoteStatus("Нажата кнопка карты: " .. mapName .. ". Проверь подтверждение в игре.", Color3.fromRGB(74, 200, 140))
                else
                    updateVoteStatus("Не удалось нажать кнопку игры", Color3.fromRGB(228, 96, 106))
                end
                voteRunning = false
                return
            end
            task.wait(0.25)
        end

        voteRunning = false
        if voteCancelled then
            updateVoteStatus("Ожидание отменено", DIM)
        elseif not shuttingDown then
            updateVoteStatus("Официальная кнопка не найдена. Открой голосование в игре.", Color3.fromRGB(228, 96, 106))
        end
    end)
end

local function cancelVoteAssistant()
    voteCancelled = true
    voteRunning = false
    updateVoteStatus("Ожидание отменено", DIM)
end

-- Separate compact map-vote window. It does not teleport, kill the player,
-- or invoke hidden remotes; it only activates the visible official map button.
votePanel = Instance.new("Frame")
votePanel.Name = "MapVoteAssistant"
votePanel.Size = UDim2.fromOffset(278, 184)
votePanel.Position = UDim2.new(1, -296, 1, -204)
votePanel.BackgroundColor3 = PANEL
votePanel.BorderSizePixel = 0
votePanel.Visible = false
votePanel.ZIndex = 70
votePanel.Parent = gui
corner(votePanel, 12)
stroke(votePanel, ACCENT, 1)

local voteTitle = Instance.new("TextLabel")
voteTitle.Size = UDim2.new(1, -42, 0, 34)
voteTitle.Position = UDim2.fromOffset(12, 2)
voteTitle.BackgroundTransparency = 1
voteTitle.Font = Enum.Font.GothamBold
voteTitle.TextSize = 13
voteTitle.TextXAlignment = Enum.TextXAlignment.Left
voteTitle.TextColor3 = TEXT
voteTitle.Text = "🗳 MAP VOTE ASSISTANT"
voteTitle.ZIndex = 71
voteTitle.Parent = votePanel

local voteClose = Instance.new("TextButton")
voteClose.Size = UDim2.fromOffset(24, 24)
voteClose.Position = UDim2.new(1, -30, 0, 6)
voteClose.BackgroundColor3 = Color3.fromRGB(150, 60, 70)
voteClose.Text = "×"
voteClose.TextColor3 = TEXT
voteClose.Font = Enum.Font.GothamBold
voteClose.TextSize = 16
voteClose.ZIndex = 72
voteClose.Parent = votePanel
corner(voteClose, 7)
voteClose.MouseButton1Click:Connect(function() votePanel.Visible = false end)

local voteHint = Instance.new("TextLabel")
voteHint.Size = UDim2.new(1, -24, 0, 28)
voteHint.Position = UDim2.fromOffset(12, 36)
voteHint.BackgroundTransparency = 1
voteHint.Font = Enum.Font.Gotham
voteHint.TextSize = 10
voteHint.TextWrapped = true
voteHint.TextXAlignment = Enum.TextXAlignment.Left
voteHint.TextColor3 = DIM
voteHint.Text = "Введи название карты. Панель нажмёт её кнопку, когда появится официальное голосование."
voteHint.ZIndex = 71
voteHint.Parent = votePanel

voteMapBox = Instance.new("TextBox")
voteMapBox.Size = UDim2.new(1, -24, 0, 30)
voteMapBox.Position = UDim2.fromOffset(12, 70)
voteMapBox.BackgroundColor3 = ITEM
voteMapBox.BorderSizePixel = 0
voteMapBox.Font = Enum.Font.Gotham
voteMapBox.TextSize = 12
voteMapBox.TextColor3 = TEXT
voteMapBox.PlaceholderColor3 = DIM
voteMapBox.PlaceholderText = "Например: Mansion2"
voteMapBox.Text = ""
voteMapBox.ClearTextOnFocus = false
voteMapBox.ZIndex = 71
voteMapBox.Parent = votePanel
corner(voteMapBox, 7)

local voteStart = Instance.new("TextButton")
voteStart.Size = UDim2.new(0.5, -16, 0, 30)
voteStart.Position = UDim2.fromOffset(12, 108)
voteStart.BackgroundColor3 = ACCENT
voteStart.Text = "▶  Начать"
voteStart.TextColor3 = TEXT
voteStart.Font = Enum.Font.GothamBold
voteStart.TextSize = 12
voteStart.ZIndex = 71
voteStart.Parent = votePanel
corner(voteStart, 7)
voteStart.MouseButton1Click:Connect(startVoteAssistant)

local voteStop = Instance.new("TextButton")
voteStop.Size = UDim2.new(0.5, -16, 0, 30)
voteStop.Position = UDim2.new(0.5, 4, 0, 108)
voteStop.BackgroundColor3 = ITEM
voteStop.Text = "■  Стоп"
voteStop.TextColor3 = TEXT
voteStop.Font = Enum.Font.GothamBold
voteStop.TextSize = 12
voteStop.ZIndex = 71
voteStop.Parent = votePanel
corner(voteStop, 7)
voteStop.MouseButton1Click:Connect(cancelVoteAssistant)

voteStatusLabel = Instance.new("TextLabel")
voteStatusLabel.Size = UDim2.new(1, -24, 0, 34)
voteStatusLabel.Position = UDim2.fromOffset(12, 145)
voteStatusLabel.BackgroundTransparency = 1
voteStatusLabel.Font = Enum.Font.Gotham
voteStatusLabel.TextSize = 10
voteStatusLabel.TextWrapped = true
voteStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
voteStatusLabel.TextYAlignment = Enum.TextYAlignment.Top
voteStatusLabel.TextColor3 = DIM
voteStatusLabel.Text = "Ожидание выключено"
voteStatusLabel.ZIndex = 71
voteStatusLabel.Parent = votePanel

local function getDisplayedCoinCount()
    local leaderstats = lp:FindFirstChild("leaderstats")
    if not leaderstats then
        return nil
    end
    local accepted = {coins = true, coin = true, coinscollected = true, collectedcoins = true}
    for _, valueObject in ipairs(leaderstats:GetChildren()) do
        local key = string.lower(valueObject.Name):gsub("[^%w]", "")
        if accepted[key] and (valueObject:IsA("IntValue") or valueObject:IsA("NumberValue")) then
            return valueObject.Value
        end
    end
    return nil
end

local function readRoundPhase()
    local playerGui = lp:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        for _, object in ipairs(playerGui:GetDescendants()) do
            if object:IsA("TextLabel") and object.Visible then
                local textValue = tostring(object.Text or "")
                local lower = string.lower(textValue)
                if lower:find("intermission", 1, true)
                    or lower:find("waiting", 1, true)
                    or lower:find("victory", 1, true)
                    or lower:find("survive", 1, true)
                    or lower:find("round", 1, true)
                    or lower:find("loading", 1, true) then
                    return textValue
                end
            end
        end
    end
    local humanoid = getHum()
    if not humanoid or humanoid.Health <= 0 then
        return "Персонаж погиб / наблюдение"
    end
    return "Фаза не распознана"
end

local statsCoinLabel
local statsRoundLabel
local statsPerfLabel
local statsRoleLabel
local roundStarts = 0
local lastPhase = nil
local statsAccumulator = 0
local fpsFrames = 0
local currentFPS = 0

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
farmInfo.Text = "Ищет Coin_Server и летит к ближайшей монете. firetouchinterest используется только если API доступен; иначе проверяется обычное касание."
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

-- Skins / avatar by username
addSection(pSkins, "Смена внешнего вида по нику")
local skinInfo = Instance.new("TextLabel")
skinInfo.Size = UDim2.new(1, 0, 0, 54)
skinInfo.BackgroundTransparency = 1
skinInfo.Font = Enum.Font.Gotham
skinInfo.TextSize = 11
skinInfo.TextWrapped = true
skinInfo.TextYAlignment = Enum.TextYAlignment.Top
skinInfo.TextXAlignment = Enum.TextXAlignment.Left
skinInfo.TextColor3 = DIM
skinInfo.Text = "Введи Roblox username игрока (именно username, не Display Name), чтобы попробовать скопировать его аватар: одежду, аксессуары и тип тела. Изменение локальное и может быть отменено сервером/игрой."
skinInfo.Parent = pSkins

local skinNameBox = Instance.new("TextBox")
skinNameBox.Size = UDim2.new(1, 0, 0, 36)
skinNameBox.BackgroundColor3 = ITEM
skinNameBox.BorderSizePixel = 0
skinNameBox.Font = Enum.Font.Gotham
skinNameBox.TextSize = 13
skinNameBox.TextColor3 = TEXT
skinNameBox.PlaceholderColor3 = DIM
skinNameBox.PlaceholderText = "Например: Builderman"
skinNameBox.Text = ""
skinNameBox.ClearTextOnFocus = false
skinNameBox.TextXAlignment = Enum.TextXAlignment.Left
skinNameBox.Parent = pSkins
corner(skinNameBox, 8)
local skinBoxPadding = Instance.new("UIPadding")
skinBoxPadding.PaddingLeft = UDim.new(0, 12)
skinBoxPadding.PaddingRight = UDim.new(0, 12)
skinBoxPadding.Parent = skinNameBox

addButton(pSkins, "🎭  Применить аватар по нику", function()
    applyAvatarByUsername(skinNameBox.Text)
end, ACCENT)
addButton(pSkins, "↩  Вернуть мой исходный вид", restoreOriginalAvatar, ITEM)
local skinStatus = Instance.new("TextLabel")
skinStatus.Size = UDim2.new(1, 0, 0, 32)
skinStatus.BackgroundTransparency = 1
skinStatus.Font = Enum.Font.Gotham
skinStatus.TextSize = 10
skinStatus.TextWrapped = true
skinStatus.TextXAlignment = Enum.TextXAlignment.Left
skinStatus.TextYAlignment = Enum.TextYAlignment.Top
skinStatus.TextColor3 = DIM
skinStatus.Text = "Это меняет только внешний вид персонажа на твоём клиенте. Ножи и пистолеты MM2 не разблокируются."
skinStatus.Parent = pSkins

-- Stats / helper tools (ten client-side utilities and readouts)
addSection(pStats, "Монеты и раунды")
statsCoinLabel = Instance.new("TextLabel")
statsCoinLabel.Size = UDim2.new(1, 0, 0, 30)
statsCoinLabel.BackgroundColor3 = ITEM
statsCoinLabel.Font = Enum.Font.GothamSemibold
statsCoinLabel.TextSize = 12
statsCoinLabel.TextColor3 = TEXT
statsCoinLabel.TextXAlignment = Enum.TextXAlignment.Left
statsCoinLabel.Text = "Монеты: счётчик недоступен · фарм: 0"
statsCoinLabel.Parent = pStats
corner(statsCoinLabel, 8)

statsRoundLabel = Instance.new("TextLabel")
statsRoundLabel.Size = UDim2.new(1, 0, 0, 42)
statsRoundLabel.BackgroundColor3 = ITEM
statsRoundLabel.Font = Enum.Font.Gotham
statsRoundLabel.TextSize = 11
statsRoundLabel.TextWrapped = true
statsRoundLabel.TextColor3 = TEXT
statsRoundLabel.TextXAlignment = Enum.TextXAlignment.Left
statsRoundLabel.Text = "Раунд: определение…"
statsRoundLabel.Parent = pStats
corner(statsRoundLabel, 8)

statsRoleLabel = Instance.new("TextLabel")
statsRoleLabel.Size = UDim2.new(1, 0, 0, 28)
statsRoleLabel.BackgroundColor3 = ITEM
statsRoleLabel.Font = Enum.Font.GothamSemibold
statsRoleLabel.TextSize = 12
statsRoleLabel.TextColor3 = TEXT
statsRoleLabel.TextXAlignment = Enum.TextXAlignment.Left
statsRoleLabel.Text = "Роль: определение…"
statsRoleLabel.Parent = pStats
corner(statsRoleLabel, 8)

statsPerfLabel = Instance.new("TextLabel")
statsPerfLabel.Size = UDim2.new(1, 0, 0, 34)
statsPerfLabel.BackgroundColor3 = ITEM
statsPerfLabel.Font = Enum.Font.GothamSemibold
statsPerfLabel.TextSize = 12
statsPerfLabel.TextColor3 = TEXT
statsPerfLabel.TextWrapped = true
statsPerfLabel.TextXAlignment = Enum.TextXAlignment.Left
statsPerfLabel.Text = "FPS: — · Ping: —"
statsPerfLabel.Parent = pStats
corner(statsPerfLabel, 8)

addSection(pStats, "Настройки клиента")
addToggle(pStats, "Crosshair — прицел по центру", false, setCrosshair)
addSlider(pStats, "FOV камеры", 60, 120, cfg.fieldOfView, setFOV)
addToggle(pStats, "FPS Boost — убрать эффекты", false, setFPSBoost)

addSection(pStats, "Ещё инструменты")
local utilityInfo = Instance.new("TextLabel")
utilityInfo.Size = UDim2.new(1, 0, 0, 82)
utilityInfo.BackgroundTransparency = 1
utilityInfo.Font = Enum.Font.Gotham
utilityInfo.TextSize = 10
utilityInfo.TextWrapped = true
utilityInfo.TextYAlignment = Enum.TextYAlignment.Top
utilityInfo.TextXAlignment = Enum.TextXAlignment.Left
utilityInfo.TextColor3 = DIM
utilityInfo.Text = "Включены: Coin Tracker, Farm Session Counter, Round Tracker, Role Detector, HP Monitor, FPS Counter, Ping Monitor, Crosshair, FOV Changer и FPS Boost. Серверная невидимость в публичной MM2 недоступна для LocalScript: локальное скрытие не скроет персонажа от других игроков."
utilityInfo.Parent = pStats

addButton(pStats, "🗳  Открыть маленькое меню голосования", function()
    votePanel.Visible = not votePanel.Visible
end, ACCENT)

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

-- Trolling: effects are limited to the local player's client.
addSection(pTroll, "Локальные розыгрыши")
addToggle(pTroll, "Fake Lag — визуальная имитация", false, setTrollFakeLag)
addToggle(pTroll, "Тряска камеры", false, setTrollShake)
addSlider(pTroll, "Сила тряски", 1, 10, cfg.trollShakeIntensity, function(value)
    cfg.trollShakeIntensity = value
end)

addSection(pTroll, "Скорость персонажа")
addToggle(pTroll, "Troll Speed", false, function(value)
    state.trollSpeed = value
    if not value then
        local humanoid = getHum()
        if humanoid then
            humanoid.WalkSpeed = state.speed and cfg.walkSpeed or 16
        end
    end
end)
addSlider(pTroll, "Скорость WalkSpeed", 16, 100, cfg.trollSpeed, function(value)
    cfg.trollSpeed = value
end)

addButton(pTroll, "↻  Сбросить эффекты троллинга", stopTrollingEffects, Color3.fromRGB(110, 75, 145))

local trollInfo = Instance.new("TextLabel")
trollInfo.Size = UDim2.new(1, 0, 0, 54)
trollInfo.BackgroundTransparency = 1
trollInfo.Font = Enum.Font.Gotham
trollInfo.TextSize = 11
trollInfo.TextWrapped = true
trollInfo.TextYAlignment = Enum.TextYAlignment.Top
trollInfo.TextXAlignment = Enum.TextXAlignment.Left
trollInfo.TextColor3 = DIM
trollInfo.Text = "Fake Lag и тряска — только визуальные эффекты на твоём экране. Они не создают сетевую задержку и не изменяют других игроков. Скорость меняет локальный WalkSpeed и может быть ограничена сервером."
trollInfo.Parent = pTroll

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
addSection(pMisc, "Голосование")
addButton(pMisc, "🗳  Открыть меню выбора карты", function()
    votePanel.Visible = not votePanel.Visible
end, ACCENT)

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

addSection(pMisc, "Совместимость с Solara")
addButton(pMisc, "Проверить доступные API", function()
    local touchText = EXECUTOR_CAPS.firetouchinterest and "доступен" or "недоступен"
    local huiText = EXECUTOR_CAPS.gethui and "доступен" or "используется PlayerGui"
    local loadText = EXECUTOR_CAPS.loadstring and "доступен" or "недоступен"
    setStatus("Solara/API: touch=" .. touchText .. " · UI=" .. huiText .. " · loadstring=" .. loadText,
        Color3.fromRGB(232, 176, 78))
end)

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
        if not EXECUTOR_CAPS.loadstring then
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
        if state.trollSpeed then
            humanoid.WalkSpeed = cfg.trollSpeed
        elseif state.speed then
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

    statsAccumulator += dt
    fpsFrames += 1
    if statsAccumulator >= 0.75 then
        currentFPS = math.floor(fpsFrames / math.max(statsAccumulator, 0.001) + 0.5)
        fpsFrames = 0
        statsAccumulator = 0

        local coinValue = getDisplayedCoinCount()
        if statsCoinLabel and statsCoinLabel.Parent then
            local coinText = coinValue ~= nil and tostring(coinValue) or "недоступен"
            statsCoinLabel.Text = "Монеты: " .. coinText .. "  ·  фарм подтверждён: " .. tostring(farmCoinsCollected)
        end

        local phaseText = readRoundPhase()
        if lastPhase ~= phaseText then
            local low = string.lower(phaseText)
            if low:find("round", 1, true) or low:find("survive", 1, true) then
                if not lastPhase or not (string.lower(lastPhase):find("round", 1, true) or string.lower(lastPhase):find("survive", 1, true)) then
                    roundStarts += 1
                end
            end
            lastPhase = phaseText
        end
        if statsRoundLabel and statsRoundLabel.Parent then
            statsRoundLabel.Text = string.format("Фаза: %s\nРаундов замечено: %d", phaseText, roundStarts)
        end
        if statsRoleLabel and statsRoleLabel.Parent then
            local humanoidNow = getHum()
            local hp = humanoidNow and math.floor(humanoidNow.Health) or 0
            statsRoleLabel.Text = "Роль: " .. roleOf(lp) .. "  ·  HP: " .. tostring(hp)
        end

        local pingText = "—"
        local pingOK, pingValue = pcall(function()
            return lp:GetNetworkPing()
        end)
        if pingOK and type(pingValue) == "number" then
            pingText = tostring(math.floor(pingValue * 1000 + 0.5)) .. " ms"
        end
        if statsPerfLabel and statsPerfLabel.Parent then
            statsPerfLabel.Text = "FPS: " .. tostring(currentFPS) .. "  ·  Ping: " .. pingText
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
    cancelVoteAssistant()
    setFPSBoost(false)
    setCrosshair(false)
    stopTrollingEffects()
    if originalFov ~= nil and workspace.CurrentCamera then
        pcall(function() workspace.CurrentCamera.FieldOfView = originalFov end)
    end

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
setStatus("NEXUS MM2 Hub v3 готов · Solara-safe · L — меню")
playLoadingAnimation()
