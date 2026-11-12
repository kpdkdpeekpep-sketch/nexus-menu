--============================================================
-- kemlopHub | Powered by Airflow (FINAL + CURSORS + SAVE)
--============================================================
local Players  = game:GetService("Players")
local RS       = game:GetService("RunService")
local UIS      = game:GetService("UserInputService")
local VU       = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")
local Teleport = game:GetService("TeleportService")
local Cam      = workspace.CurrentCamera
local LP       = Players.LocalPlayer
local PG       = LP:WaitForChild("PlayerGui")

-- Очистка старых версий
pcall(function()
    for _, g in ipairs(PG:GetChildren()) do
        if g:IsA("ScreenGui") and (string.find(g.Name, "^kemlopHub") or string.find(g.Name, "^Nexus")) then
            g:Destroy()
        end
    end
end)

-- Загрузка Airflow
local Airflow
local UI_SOURCES = {
    "https://raw.githubusercontent.com/bobloscript/Robly_Airflow/main/Source.luau",
    "https://raw.githubusercontent.com/PookiePepelsss/Airflow-UI/refs/heads/main/Source.luau",
}
for _, url in ipairs(UI_SOURCES) do
    local ok, lib = pcall(function() return loadstring(game:HttpGet(url))() end)
    if ok and type(lib) == "table" and type(lib.CreateWindow) == "function" then
        Airflow = lib
        break
    end
end
if not Airflow then error("[kemlopHub] Не удалось загрузить Airflow.") end

--============================================================
-- ЛОГИКА КУРСОРОВ (Инициализация)
--============================================================
local cursorGui = Instance.new("ScreenGui")
cursorGui.Name = "kemlopHubCursor"
cursorGui.ResetOnSpawn = false
cursorGui.IgnoreGuiInset = false
cursorGui.DisplayOrder = 2147483647
cursorGui.Parent = PG

local cursorImg = Instance.new("ImageLabel")
cursorImg.Size = UDim2.fromOffset(32, 32)
cursorImg.AnchorPoint = Vector2.new(0.5, 0.5)
cursorImg.BackgroundTransparency = 1
cursorImg.Visible = false
cursorImg.ZIndex = 2147483647
cursorImg.Parent = cursorGui

local currentCursorId = nil
local cursorNames = {
    ["None"] = nil, ["Маленький прицел"] = 1827745860, ["Средний круглый"] = 1478500977,
    ["Большой прицел"] = 2555584348, ["Красная точка"] = 412284862, ["Красный круглый"] = 1012273002,
    ["Пентаграмма"] = 51838212, ["Ромб"] = 61210994, ["Звезда"] = 11716557686,
    ["Звезда 2"] = 11716560177, ["Сердце"] = 11722368307, ["Сердце 2"] = 11722865980,
    ["Глаз"] = 12534101433, ["Глаз 2"] = 12232793816, ["Снежинка"] = 11780968239,
    ["Hello Kitty"] = 10973237327, ["Hello Kitty 2"] = 11710308636, ["Hello Kitty 3"] = 11716290197,
    ["Hello Kitty 4"] = 11717813996, ["Лягушка"] = 10763952275, ["Черепаха"] = 7590894535,
    ["Медведь"] = 11150110589, ["Пончик"] = 11717093063, ["Shoot this guy"] = 8680062686,
    ["Koopa"] = 4876554, ["Соник"] = 12233185690, ["Slipknot"] = 9967264,
    ["Star Wars"] = 5462831, ["Солнце"] = 2747009680, ["Пейзаж"] = 42341278,
    ["Набросок"] = 1143727, ["Фен"] = 12356743, ["Трискелион"] = 7643532, ["Курсор-рука"] = 63627885,
}

local function setCursor(id)
    if not id then
        currentCursorId = nil
        cursorImg.Visible = false
        UIS.MouseIconEnabled = true
        return
    end
    currentCursorId = id
    cursorImg.Image = "rbxassetid://" .. tostring(id)
    cursorImg.Visible = true
    UIS.MouseIconEnabled = false
end

RS.RenderStepped:Connect(function()
    if currentCursorId then
        local pos = UIS:GetMouseLocation()
        cursorImg.Position = UDim2.fromOffset(pos.X, pos.Y)
    end
end)

-- Загрузка сохранённого курсора
local savedCursorId = nil
pcall(function()
    if isfile and readfile and isfile("kemlopHub_Cursor.txt") then
        savedCursorId = tonumber(readfile("kemlopHub_Cursor.txt"))
        if savedCursorId then setCursor(savedCursorId) end
    end
end)

-- Поиск имени сохранённого курсора для UI
local savedCursorName = "None"
for name, id in pairs(cursorNames) do
    if id == savedCursorId then savedCursorName = name break end
end

--============================================================
-- ПЕРЕМЕННЫЕ СОСТОЯНИЯ
--============================================================
local aimEnabled, aimFOV, aimSmooth = false, 500, 14
local aimPart, aimVisibleOnly, aimLock = "Head", true, true
local autoShootOn, lastShot = false, 0
local aimPrediction, aimWallbang = 0.12, false
local lockedTarget = nil
local lastVisCheck, lastVisResult = 0, true

local silentOn, wallbang = false, false
local antiKill = false
local targetPart, targetChar = nil, nil

local kaOn, kaRadius, kaDelay = false, 500, 0.1
local espOn, espBox, espName = false, true, true
local flyOn, flySpeed = false, 60
local noclipOn, infJumpOn = false, false
local currentWS, currentJP = 16, 50
local farmOn, farmDist, farmShots = false, 6, 3

--============================================================
-- КЕШИ И ХЕЛПЕРЫ
--============================================================
local cachedPlayers = {}
local function refreshPlayers()
    cachedPlayers = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then table.insert(cachedPlayers, p) end
    end
end
refreshPlayers()
Players.PlayerAdded:Connect(refreshPlayers)
Players.PlayerRemoving:Connect(refreshPlayers)

local function isAlive(p)
    local c = p.Character; if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

local function isVisible(part)
    if not part or not part.Parent then return false end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = {LP.Character}
    rp.IgnoreWater = true
    local r = workspace:Raycast(Cam.CFrame.Position, part.Position - Cam.CFrame.Position, rp)
    return not r or r.Instance:IsDescendantOf(part.Parent)
end

local function instantFire()
    if type(mouse1click) == "function" then pcall(mouse1click)
    else
        local t = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
        if t then pcall(function() t:Activate() end) end
    end
end

local function fire()
    if type(mouse1press) == "function" and type(mouse1release) == "function" then
        pcall(function() mouse1press(); task.wait(0.03); mouse1release() end)
    else instantFire() end
end

--============================================================
-- ХУКИ (Silent + Anti-Kill)
--============================================================
pcall(function()
    if type(hookmetamethod) ~= "function" then return end
    local old
    old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local m = getnamecallmethod()
        if antiKill then
            local myHum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if myHum and self == myHum and (m == "TakeDamage" or m == "Kill") then return end
        end
        if silentOn and targetPart and targetPart.Parent and m == "Raycast" then
            local origin, dir, params = ...
            if typeof(origin) == "Vector3" and typeof(dir) == "Vector3" and dir.Magnitude > 60 then
                local newDir = targetPart.Position - origin
                if wallbang and targetChar and targetChar.Character then
                    local np = RaycastParams.new()
                    np.FilterType = Enum.RaycastFilterType.Include
                    np.FilterDescendantsInstances = {targetChar.Character}
                    return old(self, origin, newDir, np)
                else return old(self, origin, newDir, params) end
            end
        end
        return old(self, ...)
    end))
end)

--============================================================
-- INFINITE JUMP
--============================================================
UIS.JumpRequest:Connect(function()
    if infJumpOn then
        local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

--============================================================
-- ОСНОВНОЙ ЦИКЛ (Скорость, Полёт, Noclip, Silent)
--============================================================
local flyBV, flyBG
local scanAccum = 0

RS.Heartbeat:Connect(function(dt)
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if hum then
        if hum.WalkSpeed ~= currentWS then hum.WalkSpeed = currentWS end
        if hum.UseJumpPower and hum.JumpPower ~= currentJP then hum.JumpPower = currentJP end
    end

    if noclipOn and char then
        for _, b in ipairs(char:GetDescendants()) do
            if b:IsA("BasePart") and b.CanCollide then b.CanCollide = false end
        end
    end

    if flyOn and hrp then
        if not flyBV then
            flyBV = Instance.new("BodyVelocity", hrp); flyBV.MaxForce = Vector3.new(9e9,9e9,9e9)
            flyBG = Instance.new("BodyGyro", hrp); flyBG.MaxTorque = Vector3.new(9e9,9e9,9e9)
        end
        local look, right = Cam.CFrame.LookVector, Cam.CFrame.RightVector
        local mv = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then mv = mv + look end
        if UIS:IsKeyDown(Enum.KeyCode.S) then mv = mv - look end
        if UIS:IsKeyDown(Enum.KeyCode.D) then mv = mv + right end
        if UIS:IsKeyDown(Enum.KeyCode.A) then mv = mv - right end
        local v = mv * flySpeed
        if UIS:IsKeyDown(Enum.KeyCode.Space) then v = v + Vector3.new(0, 40, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then v = v - Vector3.new(0, 40, 0) end
        flyBV.Velocity = v; flyBG.CFrame = CFrame.new(hrp.Position, hrp.Position + look)
    else
        if flyBV then flyBV:Destroy(); flyBV = nil end
        if flyBG then flyBG:Destroy(); flyBG = nil end
    end

    if silentOn then
        scanAccum = scanAccum + dt
        if scanAccum >= 0.05 then
            scanAccum = 0
            local best, bd = nil, 500
            local mid = Vector2.new(Cam.ViewportSize.X/2, Cam.ViewportSize.Y/2)
            for _, p in ipairs(cachedPlayers) do
                if isAlive(p) then
                    local part = p.Character:FindFirstChild("Head")
                    if part then
                        local sp, on = Cam:WorldToViewportPoint(part.Position)
                        if on then
                            local d = (Vector2.new(sp.X, sp.Y) - mid).Magnitude
                            if d < bd then best, bd = {part, p}, d end
                        end
                    end
                end
            end
            if best then targetPart, targetChar = best[1], best[2] else targetPart, targetChar = nil, nil end
        end
    end
end)

--============================================================
-- УЛУЧШЕННЫЙ АИМБОТ
--============================================================
RS:BindToRenderStep("kemlopAim", Enum.RenderPriority.Camera.Value + 1, function(dt)
    if not aimEnabled then lockedTarget = nil; return end
    local mid = Vector2.new(Cam.ViewportSize.X / 2, Cam.ViewportSize.Y / 2)
    local partName = type(aimPart) == "table" and aimPart[1] or aimPart

    if lockedTarget and lockedTarget.Parent then
        local h = lockedTarget.Parent:FindFirstChildOfClass("Humanoid")
        if h and h.Health > 0 then
            local sp, on = Cam:WorldToViewportPoint(lockedTarget.Position)
            if on and (Vector2.new(sp.X, sp.Y) - mid).Magnitude <= aimFOV then
            else lockedTarget = nil end
        else lockedTarget = nil end
    else lockedTarget = nil end

    if not lockedTarget then
        local best, bd = nil, aimFOV
        for _, p in ipairs(cachedPlayers) do
            if isAlive(p) then
                local part = p.Character:FindFirstChild(partName)
                if part then
                    local sp, on = Cam:WorldToViewportPoint(part.Position)
                    if on then
                        local d = (Vector2.new(sp.X, sp.Y) - mid).Magnitude
                        if d < bd then
                            local canSee = true
                            if aimVisibleOnly and not aimWallbang then
                                local now = tick()
                                if now - lastVisCheck > 0.1 then
                                    lastVisCheck = now; lastVisResult = isVisible(part)
                                end
                                canSee = lastVisResult
                            end
                            if canSee then best, bd = part, d end
                        end
                    end
                end
            end
        end
        lockedTarget = best
    end

    if lockedTarget and lockedTarget.Parent then
        local targetPos = lockedTarget.Position
        local hrp = lockedTarget.Parent:FindFirstChild("HumanoidRootPart")
        if hrp and aimPrediction > 0 then targetPos = targetPos + (hrp.AssemblyLinearVelocity * aimPrediction) end
        local a = 1 - math.exp(-aimSmooth * dt)
        Cam.CFrame = Cam.CFrame:Lerp(CFrame.lookAt(Cam.CFrame.Position, targetPos), a)
        if autoShootOn and tick() - lastShot >= 0.05 then
            local sp, on = Cam:WorldToViewportPoint(targetPos)
            if on and (Vector2.new(sp.X, sp.Y) - mid).Magnitude <= 50 then
                lastShot = tick(); instantFire()
            end
        end
    end
end)

--============================================================
-- KILL AURA
--============================================================
task.spawn(function()
    while task.wait(0.1) do
        if not kaOn then continue end
        local my = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not my then continue end
        for _, p in ipairs(cachedPlayers) do
            if isAlive(p) then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - my.Position).Magnitude <= kaRadius then
                    Cam.CFrame = CFrame.lookAt(Cam.CFrame.Position, hrp.Position)
                    fire(); task.wait(kaDelay)
                end
            end
        end
    end
end)

--============================================================
-- АВТО ФАРМ
--============================================================
task.spawn(function()
    while task.wait(0.2) do
        if not farmOn then continue end
        local my = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not my then continue end
        local validTargets = {}
        for _, p in ipairs(cachedPlayers) do if isAlive(p) then table.insert(validTargets, p) end end
        if #validTargets == 0 then continue end
        local t = validTargets[math.random(#validTargets)]
        local hrp = t.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local dest = hrp.Position + (my.Position - hrp.Position).Unit * farmDist
            pcall(function()
                my.Anchored = true; my.CFrame = CFrame.lookAt(dest, hrp.Position)
                Cam.CFrame = CFrame.lookAt(Cam.CFrame.Position, hrp.Position)
            end)
            task.wait(0.3)
            for i = 1, farmShots do
                if not farmOn then break end
                Cam.CFrame = CFrame.lookAt(Cam.CFrame.Position, hrp.Position)
                fire(); task.wait(0.15)
            end
            pcall(function() my.Anchored = false end)
        end
    end
end)

--============================================================
-- ESP
--============================================================
local espObjs = {}
local espAccum = 0
RS.Heartbeat:Connect(function(dt)
    if not espOn then
        for p, o in pairs(espObjs) do for _, d in pairs(o) do d.Visible = false end end
        return
    end
    espAccum = espAccum + dt
    if espAccum < 0.05 then return end
    espAccum = 0
    for _, p in ipairs(cachedPlayers) do
        if not espObjs[p] then
            espObjs[p] = { Box = Drawing.new("Square"), Name = Drawing.new("Text") }
            espObjs[p].Box.Thickness = 1; espObjs[p].Box.Filled = false
            espObjs[p].Name.Size = 14; espObjs[p].Name.Center = true; espObjs[p].Name.Outline = true
        end
        local o = espObjs[p]
        local ch = p.Character; local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if hrp and hum and hum.Health > 0 then
            local pos, on = Cam:WorldToViewportPoint(hrp.Position)
            if on then
                local dst = (Cam.CFrame.Position - hrp.Position).Magnitude
                local h = math.clamp(1500/dst, 25, 200)
                o.Box.Size = Vector2.new(h/2, h); o.Box.Position = Vector2.new(pos.X - h/4, pos.Y - h/2)
                o.Box.Color = Color3.fromRGB(255,80,80); o.Box.Visible = espBox
                o.Name.Text = p.Name; o.Name.Position = Vector2.new(pos.X, pos.Y - h/2 - 16); o.Name.Visible = espName
            else o.Box.Visible = false; o.Name.Visible = false end
        else o.Box.Visible = false; o.Name.Visible = false end
    end
end)

--============================================================
-- ИНТЕРФЕЙС AIRFLOW
--============================================================
local Window = Airflow:CreateWindow({
    Name = "kemlopHub",
    LoadingSubtitle = "FINAL WORKING",
    ToggleUIKeybind = "K",
    ConfigurationSaving = { Enabled = false },
})

local CombatTab = Window:CreateTab({ Name = "Combat", Icon = "crosshair" })
local AimG = CombatTab:AddLeftGroupbox({ Name = "Aimbot", Icon = "target" })
local KaG = CombatTab:AddRightGroupbox({ Name = "Kill Aura", Icon = "swords" })

AimG:CreateToggle({ Name = "Aimbot", CurrentValue = false, Callback = function(v) aimEnabled = v end })
AimG:CreateToggle({ Name = "Target Lock", CurrentValue = true, Callback = function(v) aimLock = v end })
AimG:CreateToggle({ Name = "Visible Only", CurrentValue = true, Callback = function(v) aimVisibleOnly = v end })
AimG:CreateToggle({ Name = "Wallbang (Aim)", CurrentValue = false, Callback = function(v) aimWallbang = v end })
AimG:CreateToggle({ Name = "Auto Shoot", CurrentValue = false, Callback = function(v) autoShootOn = v end })
AimG:CreateSlider({ Name = "FOV", Range = {50, 2000}, Increment = 10, CurrentValue = 500, Callback = function(v) aimFOV = v end })
AimG:CreateSlider({ Name = "Smooth (1 = Snappy)", Range = {1, 40}, Increment = 1, CurrentValue = 14, Callback = function(v) aimSmooth = v end })
AimG:CreateSlider({ Name = "Prediction (sec)", Range = {0, 0.5}, Increment = 0.01, CurrentValue = 0.12, Callback = function(v) aimPrediction = v end })
AimG:CreateDropdown({ Name = "Target Part", Options = {"Head","HumanoidRootPart","UpperTorso","Torso"}, CurrentOption = {"Head"}, Callback = function(o) aimPart = o[1] end })

KaG:CreateToggle({ Name = "Kill Aura", CurrentValue = false, Callback = function(v) kaOn = v end })
KaG:CreateSlider({ Name = "Radius", Range = {10, 5000}, Increment = 10, CurrentValue = 500, Callback = function(v) kaRadius = v end })
KaG:CreateSlider({ Name = "Delay", Range = {0.03, 0.5}, Increment = 0.01, CurrentValue = 0.1, Callback = function(v) kaDelay = v end })

local FarmTab = Window:CreateTab({ Name = "Auto Farm", Icon = "gamepad-2" })
local FarmG = FarmTab:AddLeftGroupbox({ Name = "Farm", Icon = "pickaxe" })
FarmG:CreateToggle({ Name = "Enable Farm", CurrentValue = false, Callback = function(v) farmOn = v end })
FarmG:CreateSlider({ Name = "Distance", Range = {2, 25}, Increment = 1, CurrentValue = 6, Callback = function(v) farmDist = v end })
FarmG:CreateSlider({ Name = "Shots", Range = {1, 10}, Increment = 1, CurrentValue = 3, Callback = function(v) farmShots = v end })

local PlrTab = Window:CreateTab({ Name = "Player", Icon = "user" })
local MoveG = PlrTab:AddLeftGroupbox({ Name = "Movement", Icon = "move" })
local StatsG = PlrTab:AddRightGroupbox({ Name = "Stats", Icon = "bar-chart" })

MoveG:CreateToggle({ Name = "Fly (WASD)", CurrentValue = false, Callback = function(v) flyOn = v end })
MoveG:CreateSlider({ Name = "Fly Speed", Range = {10, 300}, Increment = 1, CurrentValue = 60, Callback = function(v) flySpeed = v end })
MoveG:CreateToggle({ Name = "Infinite Jump", CurrentValue = false, Callback = function(v) infJumpOn = v end })
MoveG:CreateToggle({ Name = "Noclip", CurrentValue = false, Callback = function(v) noclipOn = v end })

StatsG:CreateSlider({ Name = "WalkSpeed", Range = {16, 500}, Increment = 1, CurrentValue = 16, Callback = function(v) currentWS = v end })
StatsG:CreateSlider({ Name = "JumpPower", Range = {50, 500}, Increment = 1, CurrentValue = 50, Callback = function(v) currentJP = v end })
StatsG:CreateToggle({ Name = "Anti-Kill", CurrentValue = false, Callback = function(v) antiKill = v end })

local VisTab = Window:CreateTab({ Name = "Visuals", Icon = "eye" })
local EspG = VisTab:AddLeftGroupbox({ Name = "ESP", Icon = "box" })
local WorldG = VisTab:AddRightGroupbox({ Name = "World", Icon = "globe" })

EspG:CreateToggle({ Name = "ESP", CurrentValue = false, Callback = function(v) espOn = v end })
EspG:CreateToggle({ Name = "Box", CurrentValue = true, Callback = function(v) espBox = v end })
EspG:CreateToggle({ Name = "Name", CurrentValue = true, Callback = function(v) espName = v end })

WorldG:CreateToggle({ Name = "Fullbright", CurrentValue = false, Callback = function(v)
    if v then Lighting.Brightness = 3; Lighting.ClockTime = 12; Lighting.GlobalShadows = false; Lighting.FogEnd = 1e5
    else Lighting.Brightness = 2; Lighting.ClockTime = 14; Lighting.GlobalShadows = true; Lighting.FogEnd = 1000 end
end })
WorldG:CreateButton({ Name = "FPS Boost", Callback = function()
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Smoke") then pcall(function() v.Enabled = false end) end
    end
end })

-- Вкладка КУРСОРЫ (в самом низу)
local SetTab = Window:CreateTab({ Name = "Cursors", Icon = "mouse-pointer" })
local CursorG = SetTab:AddLeftGroupbox({ Name = "Custom Cursor", Icon = "mouse-pointer" })

CursorG:CreateDropdown({
    Name = "Select Cursor",
    Options = {
        "None", "Маленький прицел", "Средний круглый", "Большой прицел", "Красная точка", 
        "Красный круглый", "Пентаграмма", "Ромб", "Звезда", "Звезда 2", "Сердце", 
        "Сердце 2", "Глаз", "Глаз 2", "Снежинка", "Hello Kitty", "Hello Kitty 2", 
        "Hello Kitty 3", "Hello Kitty 4", "Лягушка", "Черепаха", "Медведь", "Пончик", 
        "Shoot this guy", "Koopa", "Соник", "Slipknot", "Star Wars", "Солнце", 
        "Пейзаж", "Набросок", "Фен", "Трискелион", "Курсор-рука"
    },
    CurrentOption = {savedCursorName},
    Callback = function(opt)
        local name = opt[1]
        local id = cursorNames[name]
        setCursor(id)
        
        -- Сохранение курсора
        pcall(function()
            if writefile then
                if id then writefile("kemlopHub_Cursor.txt", tostring(id))
                elseif delfile and isfile and isfile("kemlopHub_Cursor.txt") then delfile("kemlopHub_Cursor.txt") end
            end
        end)
    end
})
