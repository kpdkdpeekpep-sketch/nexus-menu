--============================================================
-- kemlopHub | pure Roblox GUI | no libraries
--============================================================
local Players  = game:GetService("Players")
local RS       = game:GetService("RunService")
local UIS      = game:GetService("UserInputService")
local VU       = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")
local TW       = game:GetService("TweenService")
local Teleport = game:GetService("TeleportService")
local Cam      = workspace.CurrentCamera
local LP       = Players.LocalPlayer
local PG       = LP:WaitForChild("PlayerGui")

-- FIX: clean both kemlopHub and legacy Nexus GUIs to prevent cursor/menu stacking
pcall(function()
    for _, g in ipairs(PG:GetChildren()) do
        if g:IsA("ScreenGui") and (string.find(g.Name, "^kemlopHub")
        or string.find(g.Name, "^KemlopHub")
        or string.find(g.Name, "^Nexus")) then
            g:Destroy()
        end
    end
end)

local C = {
    bg=Color3.fromRGB(20,20,25), bg2=Color3.fromRGB(27,27,33),
    bg3=Color3.fromRGB(34,34,41), bg4=Color3.fromRGB(44,44,53),
    acc=Color3.fromRGB(130,90,255), txt=Color3.fromRGB(210,210,215),
    dim=Color3.fromRGB(135,135,145), off=Color3.fromRGB(55,55,65),
}
local function inst(cls, props, parent)
    local o = Instance.new(cls)
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

--============================================================ LANGUAGE
local Lang = {
    RU = {
        tab_aimbot="Аимбот",tab_silent="Тихий аим",tab_killaura="Килл Аура",
        tab_farm="Авто Фарм",tab_fly="Полёт",tab_bomb="Авто Бомба",
        tab_esp="ESP",tab_player="Игрок",tab_world="Мир",
        tab_cursors="Курсоры",tab_settings="Настройки",
        aimbot="Аимбот",lock="Захват цели",vis="Только видимые",
        autoshoot="Авто-выстрел",silent="Тихий аим",wallbang="Сквозь стены",
        ka="Килл Аура",farm="Авто Фарм (Z)",fly="Полёт (WASD+Space)",
        bomb="Авто Бомба",autothrow="Авто-бросок",alltools="Все инстр.",
        esp="ESP",box="Рамка",nm="Имя",hp="Здоровье",tracer="Линия",
        noclip="Ноклип",infjump="Беск. прыжок",antiafk="Анти-АФК",
        antikill="Анти-убийство",freeze="Заморозить",ragdoll="Убрать рэгдолл",
        bright="Яркость",nofog="Без тумана",
        fov="FOV",smooth="Плавность",delay="Задержка",
        precision="Точность (px)",prediction="Предсказание (мс)",
        radius="Радиус",offset="Смещение",hits="Ударов",
        flyspeed="Скорость",flyvert="Вертикаль",walkspeed="WalkSpeed",
        jumppower="JumpPower",csize="Размер курсора",
        jumpdelay="Задержка прыжка",throwdelay="Задержка броска",
        flytime="Время полёта",farmdist="Дистанция",
        firecount="Выстрелов",firegap="Интервал",stay="Стоять",
        part="Часть",mode="Режим",target="Цель",
        reset="Сбросить персонажа",fps="FPS Boost",color="Сменить цвет",
        rejoin="Переподключиться",notifytest="Тест уведомления",
        tprandom="ТП к случайному",spawn="На спавн",
        lang="Язык",loaded="kemlopHub загружен. K — меню, Z — фарм.",
        stats="Статистика",fpslabel="FPS",pinglabel="Пинг",
        removelights="Убрать свет",resetws="Сброс скорости",
    },
    EN = {
        tab_aimbot="Aimbot",tab_silent="Silent Aim",tab_killaura="Kill Aura",
        tab_farm="Auto Farm",tab_fly="Fly",tab_bomb="Auto Bomb",
        tab_esp="ESP",tab_player="Player",tab_world="World",
        tab_cursors="Cursors",tab_settings="Settings",
        aimbot="Aimbot",lock="Target Lock",vis="Visible only",
        autoshoot="Auto-Shoot",silent="Silent Aim",wallbang="Wallbang",
        ka="Kill Aura",farm="Auto Farm (Z)",fly="Fly (WASD+Space)",
        bomb="Auto Bomb",autothrow="Auto throw",alltools="All tools",
        esp="ESP",box="Box",nm="Name",hp="Health",tracer="Tracer",
        noclip="Noclip",infjump="Infinite Jump",antiafk="Anti-AFK",
        antikill="Anti-Kill",freeze="Freeze Self",ragdoll="Ragdoll Remover",
        bright="Fullbright",nofog="No Fog",
        fov="FOV",smooth="Smooth",delay="Delay",
        precision="Precision (px)",prediction="Prediction (ms)",
        radius="Radius",offset="Offset",hits="Hits",
        flyspeed="Speed",flyvert="Vertical",walkspeed="WalkSpeed",
        jumppower="JumpPower",csize="Cursor size",
        jumpdelay="Jump delay",throwdelay="Throw delay",
        flytime="Fly time",farmdist="Distance",
        firecount="Shots",firegap="Fire gap",stay="Stay",
        part="Part",mode="Mode",target="Target",
        reset="Reset Character",fps="FPS Boost",color="Change color",
        rejoin="Rejoin",notifytest="Test notification",
        tprandom="TP random player",spawn="TP to spawn",
        lang="Language",loaded="kemlopHub loaded. K — menu, Z — farm.",
        stats="Statistics",fpslabel="FPS",pinglabel="Ping",
        removelights="Remove lights",resetws="Reset speed",
    },
    UA = {
        tab_aimbot="Аімбот",tab_silent="Тихий аім",tab_killaura="Кілл Аура",
        tab_farm="Авто Фарм",tab_fly="Політ",tab_bomb="Авто Бомба",
        tab_esp="ESP",tab_player="Гравець",tab_world="Світ",
        tab_cursors="Курсори",tab_settings="Налаштування",
        aimbot="Аімбот",lock="Захват цілі",vis="Тільки видимі",
        autoshoot="Авто-постріл",silent="Тихий аім",wallbang="Крізь стіни",
        ka="Кілл Аура",farm="Авто Фарм (Z)",fly="Політ (WASD+Space)",
        bomb="Авто Бомба",autothrow="Авто-кидок",alltools="Всі інстр.",
        esp="ESP",box="Рамка",nm="Ім'я",hp="Здоров'я",tracer="Лінія",
        noclip="Нокліп",infjump="Безкін. стрибок",antiafk="Анти-АФК",
        antikill="Анти-вбивство",freeze="Заморозити",ragdoll="Прибрати рендом",
        bright="Яскравість",nofog="Без туману",
        fov="FOV",smooth="Плавність",delay="Затримка",
        precision="Точність (px)",prediction="Передбачення (мс)",
        radius="Радіус",offset="Зсув",hits="Ударів",
        flyspeed="Швидкість",flyvert="Вертикаль",walkspeed="WalkSpeed",
        jumppower="JumpPower",csize="Розмір курсора",
        jumpdelay="Затримка стрибка",throwdelay="Затримка кидка",
        flytime="Час польоту",farmdist="Дистанція",
        firecount="Пострілів",firegap="Інтервал",stay="Стояти",
        part="Частина",mode="Режим",target="Ціль",
        reset="Скинути персонажа",fps="FPS Boost",color="Змінити колір",
        rejoin="Перепідключитися",notifytest="Тест сповіщення",
        tprandom="ТП до випадкового",spawn="На спавн",
        lang="Мова",loaded="kemlopHub завантажено. K — меню, Z — фарм.",
        stats="Статистика",fpslabel="FPS",pinglabel="Пінг",
        removelights="Прибрати світло",resetws="Скинути швидкість",
    },
}
local curLang = "RU"
local function T(k)
    local t = Lang[curLang]
    return (t and t[k]) or k
end

local tabMap, tabBtnMap = {}, {}
local langWatchers = {}
local function watch(obj, getter)
    langWatchers[obj] = getter
    obj.Text = getter()
end
local function refreshLang()
    for obj, getter in pairs(langWatchers) do
        if obj.Parent then pcall(function() obj.Text = getter() end) end
    end
    for k, b in pairs(tabBtnMap) do
        b.Text = T("tab_" .. k)
    end
end

--============================================================ shell
local gui = inst("ScreenGui", {
    Name="kemlopHubMenu", ResetOnSpawn=false, IgnoreGuiInset=true,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
}, PG)
local main = inst("Frame", {
    Size=UDim2.fromOffset(560,460), Position=UDim2.new(.5,-280,.5,-230),
    BackgroundColor3=C.bg, BorderSizePixel=0, Visible=false,
}, gui)
inst("UICorner", {CornerRadius=UDim.new(0,6)}, main)
inst("UIStroke", {Color=C.acc, Thickness=1}, main)

local bar = inst("Frame", {
    Size=UDim2.new(1,0,0,38), BackgroundColor3=C.bg2, BorderSizePixel=0,
}, main)
inst("UICorner", {CornerRadius=UDim.new(0,6)}, bar)
inst("TextLabel", {
    Size=UDim2.new(1,-60,1,0), Position=UDim2.new(0,14,0,0),
    BackgroundTransparency=1, Text="kemlopHub",
    TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBold,
    TextSize=14, TextXAlignment=Enum.TextXAlignment.Left,
}, bar)
local close = inst("TextButton", {
    Size=UDim2.fromOffset(26,26), Position=UDim2.new(1,-33,0,6),
    BackgroundColor3=C.bg3, BorderSizePixel=0,
    Text="×", TextColor3=C.txt, Font=Enum.Font.GothamBold, TextSize=17,
}, bar)
inst("UICorner", {CornerRadius=UDim.new(0,4)}, close)
close.MouseButton1Click:Connect(function() main.Visible = false end)

do
    local drag, sPos, start
    bar.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
        or i.UserInputType==Enum.UserInputType.Touch then
            drag, sPos, start = true, i.Position, main.Position
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if drag and (i.UserInputType==Enum.UserInputType.MouseMovement
        or i.UserInputType==Enum.UserInputType.Touch) then
            local d = i.Position - sPos
            main.Position = UDim2.new(start.X.Scale,start.X.Offset+d.X,
                                      start.Y.Scale,start.Y.Offset+d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
        or i.UserInputType==Enum.UserInputType.Touch then drag=false end
    end)
end

local side = inst("Frame", {
    Size=UDim2.new(0,140,1,-52), Position=UDim2.new(0,10,0,48),
    BackgroundColor3=C.bg2, BorderSizePixel=0,
}, main)
inst("UICorner", {CornerRadius=UDim.new(0,5)}, side)
inst("UIListLayout", {Padding=UDim.new(0,3)}, side)
inst("UIPadding", {PaddingTop=UDim.new(0,6),
    PaddingLeft=UDim.new(0,6), PaddingRight=UDim.new(0,6)}, side)

local content = inst("Frame", {
    Size=UDim2.new(1,-166,1,-58), Position=UDim2.new(0,156,0,48),
    BackgroundTransparency=1,
}, main)

--============================================================ tabs
local function tab(key)
    local btn = inst("TextButton", {
        Size=UDim2.new(1,0,0,28), BackgroundColor3=C.bg3,
        BorderSizePixel=0, Text=T("tab_"..key), TextColor3=C.txt,
        Font=Enum.Font.Gotham, TextSize=12, AutoButtonColor=false,
    }, side)
    inst("UICorner", {CornerRadius=UDim.new(0,4)}, btn)
    local sf = inst("ScrollingFrame", {
        Size=UDim2.fromScale(1,1), BackgroundTransparency=1,
        BorderSizePixel=0, ScrollBarThickness=3,
        ScrollBarImageColor3=C.acc, CanvasSize=UDim2.new(),
        AutomaticCanvasSize=Enum.AutomaticSize.Y, Visible=false,
    }, content)
    inst("UIListLayout", {Padding=UDim.new(0,5)}, sf)
    inst("UIPadding", {PaddingTop=UDim.new(0,4), PaddingBottom=UDim.new(0,6)}, sf)
    tabMap[key], tabBtnMap[key] = sf, btn
    btn.MouseButton1Click:Connect(function()
        for _, f in pairs(tabMap) do f.Visible = false end
        for _, b in pairs(tabBtnMap) do b.BackgroundColor3 = C.bg3 end
        sf.Visible = true; btn.BackgroundColor3 = C.acc
    end)
    return sf
end

--============================================================ widgets
local function toggle(p, key, def, cb)
    local b = inst("TextButton", {
        Size=UDim2.new(1,0,0,32), BackgroundColor3=C.bg3,
        BorderSizePixel=0, Text="", AutoButtonColor=false,
    }, p)
    inst("UICorner", {CornerRadius=UDim.new(0,4)}, b)
    local lbl = inst("TextLabel", {
        Size=UDim2.new(1,-55,1,0), Position=UDim2.new(0,11,0,0),
        BackgroundTransparency=1, TextColor3=C.txt,
        Font=Enum.Font.Gotham, TextSize=12,
        TextXAlignment=Enum.TextXAlignment.Left,
    }, b)
    watch(lbl, function() return T(key) end)
    local pill = inst("Frame", {
        Size=UDim2.fromOffset(34,18), Position=UDim2.new(1,-45,.5,-9),
        BackgroundColor3=C.off, BorderSizePixel=0,
    }, b)
    inst("UICorner", {CornerRadius=UDim.new(1,0)}, pill)
    local knob = inst("Frame", {
        Size=UDim2.fromOffset(14,14), Position=UDim2.new(0,2,.5,-7),
        BackgroundColor3=Color3.fromRGB(170,170,180), BorderSizePixel=0,
    }, pill)
    inst("UICorner", {CornerRadius=UDim.new(1,0)}, knob)
    local on = def
    local function render()
        pill.BackgroundColor3 = on and C.acc or C.off
        knob.Position = on and UDim2.new(1,-16,.5,-7) or UDim2.new(0,2,.5,-7)
        knob.BackgroundColor3 = on and Color3.new(1,1,1) or Color3.fromRGB(170,170,180)
    end
    local function set(v) on=v; render(); pcall(cb,v) end
    render()
    b.MouseButton1Click:Connect(function() set(not on) end)
    return set
end

local function slider(p, key, min, max, def, cb)
    local w = inst("Frame", {
        Size=UDim2.new(1,0,0,46), BackgroundColor3=C.bg3, BorderSizePixel=0,
    }, p)
    inst("UICorner", {CornerRadius=UDim.new(0,4)}, w)
    local lbl = inst("TextLabel", {
        Size=UDim2.new(1,-80,0,20), Position=UDim2.new(0,11,0,2),
        BackgroundTransparency=1, TextColor3=C.txt,
        Font=Enum.Font.Gotham, TextSize=12,
        TextXAlignment=Enum.TextXAlignment.Left,
    }, w)
    watch(lbl, function() return T(key) end)
    local vLbl = inst("TextLabel", {
        Size=UDim2.fromOffset(64,20), Position=UDim2.new(1,-75,0,2),
        BackgroundTransparency=1, Text=tostring(def), TextColor3=C.acc,
        Font=Enum.Font.Gotham, TextSize=12,
        TextXAlignment=Enum.TextXAlignment.Right,
    }, w)
    local track = inst("Frame", {
        Size=UDim2.new(1,-22,0,6), Position=UDim2.new(0,11,0,30),
        BackgroundColor3=C.off, BorderSizePixel=0,
    }, w)
    inst("UICorner", {CornerRadius=UDim.new(1,0)}, track)
    local fill = inst("Frame", {
        Size=UDim2.new((def-min)/(max-min),0,1,0),
        BackgroundColor3=C.acc, BorderSizePixel=0,
    }, track)
    inst("UICorner", {CornerRadius=UDim.new(1,0)}, fill)
    local dragging = false
    local function setX(x)
        local rel = math.clamp((x-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
        local v = min + (max-min)*rel
        v = (max-min<=10) and math.floor(v*100+.5)/100 or math.floor(v+.5)
        fill.Size = UDim2.new((v-min)/(max-min),0,1,0)
        vLbl.Text = tostring(v); pcall(cb,v)
    end
    track.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
        or i.UserInputType==Enum.UserInputType.Touch then
            dragging=true; setX(i.Position.X)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement
        or i.UserInputType==Enum.UserInputType.Touch) then setX(i.Position.X) end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
        or i.UserInputType==Enum.UserInputType.Touch then dragging=false end
    end)
end

local function dropdown(p, key, opts, def, cb)
    local w = inst("Frame", {
        Size=UDim2.new(1,0,0,32), BackgroundColor3=C.bg3,
        BorderSizePixel=0, ClipsDescendants=true,
    }, p)
    inst("UICorner", {CornerRadius=UDim.new(0,4)}, w)
    local head = inst("TextButton", {
        Size=UDim2.new(1,0,0,32), BackgroundTransparency=1, Text="",
    }, w)
    local lbl = inst("TextLabel", {
        Size=UDim2.new(1,-35,0,32), Position=UDim2.new(0,11,0,0),
        BackgroundTransparency=1, TextColor3=C.txt,
        Font=Enum.Font.Gotham, TextSize=12,
        TextXAlignment=Enum.TextXAlignment.Left,
    }, w)
    local cur = def
    watch(lbl, function() return T(key)..": "..tostring(cur) end)
    local arr = inst("TextLabel", {
        Size=UDim2.fromOffset(18,32), Position=UDim2.new(1,-22,0,0),
        BackgroundTransparency=1, Text="v", TextColor3=C.dim,
        Font=Enum.Font.Gotham, TextSize=11,
    }, w)
    local list = inst("Frame", {
        Size=UDim2.new(1,0,0,#opts*26), Position=UDim2.new(0,0,0,32),
        BackgroundTransparency=1,
    }, w)
    inst("UIListLayout", {Padding=UDim.new(0,2)}, list)
    for _, opt in ipairs(opts) do
        local o = inst("TextButton", {
            Size=UDim2.new(1,-8,0,24), BackgroundColor3=C.bg4,
            BorderSizePixel=0, Text=tostring(opt), TextColor3=C.txt,
            Font=Enum.Font.Gotham, TextSize=11, AutoButtonColor=false,
        }, list)
        inst("UICorner", {CornerRadius=UDim.new(0,3)}, o)
        o.MouseButton1Click:Connect(function()
            cur = opt
            lbl.Text = T(key)..": "..tostring(opt)
            w.Size = UDim2.new(1,0,0,32); arr.Text = "v"
            pcall(cb, opt)
        end)
    end
    head.MouseButton1Click:Connect(function()
        if w.Size.Y.Offset > 32 then
            w.Size = UDim2.new(1,0,0,32); arr.Text = "v"
        else
            w.Size = UDim2.new(1,0,0,32+#opts*26); arr.Text = "^"
        end
    end)
end

local function button(p, key, cb)
    local b = inst("TextButton", {
        Size=UDim2.new(1,0,0,32), BackgroundColor3=C.acc,
        BorderSizePixel=0, TextColor3=Color3.new(1,1,1),
        Font=Enum.Font.GothamBold, TextSize=12, AutoButtonColor=false,
    }, p)
    inst("UICorner", {CornerRadius=UDim.new(0,4)}, b)
    watch(b, function() return T(key) end)
    b.MouseButton1Click:Connect(function() pcall(cb) end)
end

--============================================================ notify
local function notify(title, body, dur)
    local ng = inst("ScreenGui", {
        Name="kemlopHubNotify", ResetOnSpawn=false,
        IgnoreGuiInset=true, DisplayOrder=2147483646,
    }, PG)
    local f = inst("Frame", {
        Size=UDim2.fromOffset(300,76), Position=UDim2.new(1,20,0,20),
        BackgroundColor3=C.bg, BorderSizePixel=0,
    }, ng)
    inst("UICorner", {CornerRadius=UDim.new(0,6)}, f)
    inst("UIStroke", {Color=C.acc, Thickness=1}, f)
    inst("Frame", {
        Size=UDim2.new(0,3,1,-16), Position=UDim2.new(0,0,0,8),
        BackgroundColor3=C.acc, BorderSizePixel=0,
    }, f)
    inst("TextLabel", {
        Size=UDim2.new(1,-20,0,18), Position=UDim2.new(0,12,0,8),
        BackgroundTransparency=1, Text=title, TextColor3=C.acc,
        Font=Enum.Font.GothamBold, TextSize=13,
        TextXAlignment=Enum.TextXAlignment.Left,
    }, f)
    inst("TextLabel", {
        Size=UDim2.new(1,-20,0,42), Position=UDim2.new(0,12,0,28),
        BackgroundTransparency=1, Text=body, TextColor3=C.txt,
        Font=Enum.Font.Gotham, TextSize=11,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Top, TextWrapped=true,
    }, f)
    TW:Create(f, TweenInfo.new(.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out), {
        Position=UDim2.new(1,-320,0,20),
    }):Play()
    task.delay(dur or 4, function()
        if not f.Parent then return end
        TW:Create(f, TweenInfo.new(.25,Enum.EasingStyle.Quad,Enum.EasingDirection.In), {
            Position=UDim2.new(1,20,0,20),
        }):Play()
        task.wait(.35); ng:Destroy()
    end)
end

--============================================================ helpers
local function alive(p)
    local c = p.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0 and h:GetState() ~= Enum.HumanoidStateType.Dead
end
local function visible(part)
    if not part or not part.Parent then return false end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = {LP.Character}
    rp.IgnoreWater = true
    local r = workspace:Raycast(Cam.CFrame.Position, part.Position-Cam.CFrame.Position, rp)
    return not r or r.Instance:IsDescendantOf(part.Parent)
end
local function fire()
    if type(mouse1press)=="function" and type(mouse1release)=="function" then
        pcall(function() mouse1press(); task.wait(.03); mouse1release() end)
    elseif type(mouse1click)=="function" then
        pcall(mouse1click)
    else
        local t = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
        if t then pcall(function() t:Activate() end); return end
        pcall(function() VU:ClickButton1(Cam.ViewportSize/2) end)
    end
end

--============================================================ silent aim + anti-kill
local antiKill = false
local silentOn, wallbang, silentVis = false, false, false
local silentFOV, silentPart = 500, "Head"
local targetPart, targetChar = nil, nil
local lastScan = 0

local myHum
local function grabHum()
    myHum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if myHum then
        myHum.HealthChanged:Connect(function(hp)
            if antiKill and hp < myHum.MaxHealth then
                pcall(function() myHum.Health = myHum.MaxHealth end)
            end
        end)
    end
end
grabHum()
LP.CharacterAdded:Connect(function() task.wait(.3); grabHum() end)
RS.Heartbeat:Connect(function()
    if not antiKill then return end
    local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if h and h.Health < h.MaxHealth then
        pcall(function() h.Health = h.MaxHealth end)
    end
end)

local function scanSilent()
    local best, bd = nil, silentFOV
    local mid = Vector2.new(Cam.ViewportSize.X/2, Cam.ViewportSize.Y/2)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and alive(p) then
            local part = p.Character:FindFirstChild(silentPart)
            if part and part.Parent then
                local sp, on = Cam:WorldToViewportPoint(part.Position)
                if on then
                    local d = (Vector2.new(sp.X,sp.Y)-mid).Magnitude
                    if d < bd then
                        local ok = true
                        if silentVis then
                            local w = silentOn; silentOn = false
                            ok = visible(part); silentOn = w
                        end
                        if ok then best, bd = {part,p}, d end
                    end
                end
            end
        end
    end
    if best then targetPart, targetChar = best[1], best[2]
    else targetPart, targetChar = nil, nil end
end

RS.Heartbeat:Connect(function()
    if not silentOn then targetPart, targetChar = nil, nil; return end
    local now = tick()
    if now - lastScan < .05 then return end
    lastScan = now
    pcall(scanSilent)
end)

pcall(function()
    if type(hookmetamethod) ~= "function" then return end
    local old
    old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local m = getnamecallmethod()
        if antiKill and myHum and self == myHum then
            if m == "TakeDamage" or m == "Kill" then return end
        end
        if silentOn and targetPart and targetPart.Parent then
            if m == "Raycast" then
                local origin, dir, params = ...
                if typeof(origin)=="Vector3" and typeof(dir)=="Vector3"
                and dir.Magnitude > 60 and params and params.FilterType ~= nil then
                    local newDir = targetPart.Position - origin
                    if wallbang and targetChar and targetChar.Character then
                        local np = RaycastParams.new()
                        np.FilterType = Enum.RaycastFilterType.Include
                        np.FilterDescendantsInstances = {targetChar.Character}
                        np.IgnoreWater = true
                        return old(self, origin, newDir, np)
                    else
                        return old(self, origin, newDir, params)
                    end
                end
            elseif m=="FindPartOnRay" or m=="FindPartOnRayWithIgnoreList"
            or m=="FindPartOnRayWithWhitelist" then
                return targetPart, targetPart.Position,
                       Vector3.new(0,1,0), targetPart.Material
            end
        end
        return old(self, ...)
    end))
end)

pcall(function()
    if type(getrawmetatable)~="function" or type(setreadonly)~="function" then return end
    local mouse = LP:GetMouse()
    local mt = getrawmetatable(mouse)
    if not mt or not mt.__index then return end
    local oi = mt.__index
    setreadonly(mt, false)
    mt.__index = newcclosure(function(self, k)
        if silentOn and targetPart and targetPart.Parent then
            if k == "Hit" then return CFrame.new(targetPart.Position) end
            if k == "Target" then return targetPart end
        end
        return oi(self, k)
    end)
    setreadonly(mt, true)
end)

--============================================================ AIMBOT
do
    local t = tab("aimbot")
    local on, fov, smooth, part = false, 500, 14, "Head"
    local vis, lock, pred = true, true, 0
    local auto, autoDelay, thresh = false, .05, 100
    local lastShot, cur = 0, nil

    local function find()
        if lock and cur and cur.Parent then
            local h = cur.Parent:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 and (not vis or visible(cur)) then return cur end
        end
        local best, bd = nil, fov
        local mid = Vector2.new(Cam.ViewportSize.X/2, Cam.ViewportSize.Y/2)
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and alive(p) then
                local pp = p.Character:FindFirstChild(part)
                if pp and pp.Parent then
                    local sp, onc = Cam:WorldToViewportPoint(pp.Position)
                    if onc then
                        local d = (Vector2.new(sp.X,sp.Y)-mid).Magnitude
                        if d < bd and (not vis or visible(pp)) then best, bd = pp, d end
                    end
                end
            end
        end
        cur = best; return best
    end
    local bind = "kemlopAim"
    local function start()
        RS:BindToRenderStep(bind, Enum.RenderPriority.Camera.Value+1, function(dt)
            if not on then return end
            local tg = find()
            if not tg then return end
            local pos = tg.Position
            if pred > 0 then
                local hrp = tg.Parent and tg.Parent:FindFirstChild("HumanoidRootPart")
                if hrp then pos = pos + hrp.AssemblyLinearVelocity*(pred/1000) end
            end
            local a = 1 - math.exp(-smooth*dt)
            Cam.CFrame = Cam.CFrame:Lerp(CFrame.lookAt(Cam.CFrame.Position, pos), a)
            if auto and tick()-lastShot >= autoDelay then
                local sp, onc = Cam:WorldToViewportPoint(pos)
                if onc and (Vector2.new(sp.X,sp.Y)
                - Vector2.new(Cam.ViewportSize.X/2, Cam.ViewportSize.Y/2)).Magnitude <= thresh then
                    lastShot = tick(); task.spawn(fire)
                end
            end
        end)
    end
    local function stop() pcall(function() RS:UnbindFromRenderStep(bind) end) end

    toggle(t, "aimbot", false, function(v) on=v; if v then start() else stop() end end)
    toggle(t, "lock", true, function(v) lock=v end)
    toggle(t, "vis", true, function(v) vis=v end)
    toggle(t, "autoshoot", false, function(v) auto=v end)
    slider(t, "fov", 50, 2000, 500, function(v) fov=v end)
    slider(t, "smooth", 2, 40, 14, function(v) smooth=v end)
    slider(t, "delay", .02, .5, .05, function(v) autoDelay=v end)
    slider(t, "precision", 20, 300, 100, function(v) thresh=v end)
    slider(t, "prediction", 0, 300, 0, function(v) pred=v end)
    dropdown(t, "part", {"Head","HumanoidRootPart","UpperTorso","Torso"}, "Head",
        function(o) part=o end)
end

--============================================================ SILENT AIM
do
    local t = tab("silent")
    toggle(t, "silent", false, function(v) silentOn=v end)
    toggle(t, "wallbang", false, function(v) wallbang=v end)
    toggle(t, "vis", false, function(v) silentVis=v end)
    slider(t, "fov", 50, 2000, 500, function(v) silentFOV=v end)
    dropdown(t, "target", {"Head","HumanoidRootPart","UpperTorso","Torso"}, "Head",
        function(o) silentPart=o end)
end

--============================================================ KILL AURA
do
    local t = tab("killaura")
    local on, mode, radius, delay = false, "Teleport", 500, .1
    local vis, offset, hits, running = false, 3, 2, false

    local function tpAttack(hrp)
        local my = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not my or not hrp or not hrp.Parent then return end
        local sc, scam, sv = my.CFrame, Cam.CFrame, my.AssemblyLinearVelocity
        local d = hrp.Position - my.Position
        if d.Magnitude < .1 then d = Vector3.new(0,0,1) end
        pcall(function()
            my.CFrame = CFrame.lookAt(hrp.Position-d.Unit*offset, hrp.Position)
            my.AssemblyLinearVelocity = Vector3.zero
        end)
        task.wait(.05)
        for _ = 1, hits do
            if not hrp.Parent then break end
            local h = hrp.Parent:FindFirstChildOfClass("Humanoid")
            if not h or h.Health <= 0 then break end
            Cam.CFrame = CFrame.lookAt(Cam.CFrame.Position, hrp.Position)
            fire(); task.wait(.04)
        end
        pcall(function()
            my.CFrame = sc; my.AssemblyLinearVelocity = sv; Cam.CFrame = scam
        end)
    end

    local function loop()
        if running then return end
        running = true
        task.spawn(function()
            while on do
                local my = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                if not my then task.wait(.2); continue end
                local list = {}
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LP and alive(p) then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position-my.Position).Magnitude <= radius
                        and (not vis or visible(hrp)) then
                            table.insert(list, hrp)
                        end
                    end
                end
                if #list == 0 then task.wait(.15); continue end
                table.sort(list, function(a,b)
                    return (a.Position-my.Position).Magnitude < (b.Position-my.Position).Magnitude
                end)
                for _, hrp in ipairs(list) do
                    if not on or not hrp.Parent then break end
                    local h = hrp.Parent:FindFirstChildOfClass("Humanoid")
                    if not h or h.Health <= 0 then continue end
                    if mode == "Teleport" then tpAttack(hrp)
                    else
                        Cam.CFrame = CFrame.lookAt(Cam.CFrame.Position, hrp.Position)
                        task.wait(.02); fire()
                    end
                    task.wait(delay)
                end
            end
            running = false
        end)
    end

    toggle(t, "ka", false, function(v) on=v; if v then loop() end end)
    dropdown(t, "mode", {"Teleport","Instant"}, "Teleport", function(o) mode=o end)
    slider(t, "radius", 10, 5000, 500, function(v) radius=v end)
    slider(t, "delay", .03, .5, .1, function(v) delay=v end)
    slider(t, "offset", 1, 10, 3, function(v) offset=v end)
    slider(t, "hits", 1, 5, 2, function(v) hits=v end)
    toggle(t, "vis", false, function(v) vis=v end)
end

--============================================================ AUTO FARM
do
    local t = tab("farm")
    local on, running = false, false
    local noclipConn, aimBind, aimTarget = nil, "kemlopFarmAim", nil
    local mode, flyTime = "Fly", .35
    local delay, dist, count, gap, stay = .4, 6, 3, .08, .5
    local aimPart = "Head"

    local function noclip(state)
        if state then
            if not noclipConn then
                noclipConn = RS.Stepped:Connect(function()
                    if not on then return end
                    local c = LP.Character
                    if c then
                        for _, b in ipairs(c:GetDescendants()) do
                            if b:IsA("BasePart") and b.CanCollide then b.CanCollide = false end
                        end
                    end
                end)
            end
        else
            if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
        end
    end

    local function equip()
        local c = LP.Character
        if not c or c:FindFirstChildOfClass("Tool") then return end
        local bp = LP:FindFirstChild("Backpack")
        local h = c:FindFirstChildOfClass("Humanoid")
        if bp and h then
            local tool = bp:FindFirstChildWhichIsA("Tool")
            if tool then pcall(function() h:EquipTool(tool) end) end
        end
    end

    local function aimStart(part)
        aimTarget = part
        pcall(function() RS:UnbindFromRenderStep(aimBind) end)
        RS:BindToRenderStep(aimBind, Enum.RenderPriority.Camera.Value+1, function()
            if not on then return end
            local tg = aimTarget
            if not tg or not tg.Parent then return end
            pcall(function() Cam.CFrame = CFrame.lookAt(Cam.CFrame.Position, tg.Position) end)
            local c = LP.Character
            local my = c and c:FindFirstChild("HumanoidRootPart")
            if my then
                local flat = Vector3.new(tg.Position.X, my.Position.Y, tg.Position.Z)
                pcall(function() my.CFrame = CFrame.lookAt(my.Position, flat) end)
            end
        end)
    end
    local function aimStop()
        aimTarget = nil
        pcall(function() RS:UnbindFromRenderStep(aimBind) end)
    end

    local function flyTo(dest, dur)
        local c = LP.Character
        local my = c and c:FindFirstChild("HumanoidRootPart")
        if not my then return false end
        my.Anchored = true
        local from = my.Position
        local t0 = tick()
        while on do
            local a = math.clamp((tick()-t0)/dur, 0, 1)
            if a >= 1 then break end
            local p = from:Lerp(dest, a)
            pcall(function()
                my.CFrame = CFrame.lookAt(p, dest)
                Cam.CFrame = CFrame.lookAt(Cam.CFrame.Position, dest)
            end)
            RS.RenderStepped:Wait()
        end
        pcall(function() my.CFrame = CFrame.lookAt(dest, dest) end)
        return true
    end

    local function pick()
        local pool = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and alive(p) then
                local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then table.insert(pool, {p=p, hrp=hrp}) end
            end
        end
        return pool[math.random(#pool)]
    end

    local function cycle()
        local c = LP.Character
        local my = c and c:FindFirstChild("HumanoidRootPart")
        if not my then return end
        my.Anchored = true
        local tg = pick()
        if not tg then return end
        local away = my.Position - tg.hrp.Position
        if away.Magnitude < .5 then away = Vector3.new(0,0,1) end
        local dest = tg.hrp.Position + away.Unit * dist
        if mode == "Teleport" then
            pcall(function()
                my.CFrame = CFrame.lookAt(dest, tg.hrp.Position)
                Cam.CFrame = CFrame.lookAt(Cam.CFrame.Position, tg.hrp.Position)
            end)
        else flyTo(dest, flyTime) end
        if not on or not alive(tg.p) then return end
        local pPart = tg.p.Character and
            (tg.p.Character:FindFirstChild(aimPart) or tg.p.Character:FindFirstChild("HumanoidRootPart"))
        if pPart then aimStart(pPart) end
        local w = 0
        while on and w < delay do
            if not alive(tg.p) then break end
            task.wait(.05); w = w + .05
        end
        if not on then aimStop(); return end
        local p2 = tg.p.Character and
            (tg.p.Character:FindFirstChild(aimPart) or tg.p.Character:FindFirstChild("HumanoidRootPart"))
        if p2 then
            equip()
            for _ = 1, count do
                if not on or not p2.Parent then break end
                fire(); task.wait(gap)
            end
        end
        if stay > 0 then task.wait(stay) end
        aimStop()
    end

    local function loop()
        if running then return end
        running = true
        task.spawn(function()
            while on do pcall(cycle); task.wait(.05) end
            aimStop()
            local c = LP.Character
            local my = c and c:FindFirstChild("HumanoidRootPart")
            if my then my.Anchored = false end
            running = false
        end)
    end

    local setFarm = toggle(t, "farm", false, function(v)
        on = v; noclip(v)
        if v then loop()
        else
            aimStop()
            local c = LP.Character
            local my = c and c:FindFirstChild("HumanoidRootPart")
            if my then my.Anchored = false end
            noclip(false)
        end
    end)
    _G.KemlopFarm = setFarm

    dropdown(t, "mode", {"Fly","Teleport"}, "Fly", function(o) mode=o end)
    slider(t, "flytime", .1, 1.5, .35, function(v) flyTime=v end)
    slider(t, "delay", .05, 2, .4, function(v) delay=v end)
    slider(t, "farmdist", 2, 25, 6, function(v) dist=v end)
    slider(t, "firecount", 1, 10, 3, function(v) count=v end)
    slider(t, "firegap", .02, .5, .08, function(v) gap=v end)
    slider(t, "stay", 0, 3, .5, function(v) stay=v end)
    dropdown(t, "part", {"Head","HumanoidRootPart","UpperTorso","Torso"}, "Head",
        function(o) aimPart=o end)
end

--============================================================ FLY
do
    local t = tab("fly")
    local on, speed, vert = false, 60, 40
    local bv, bg, bind = nil, nil, "kemlopFly"

    local function start()
        local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        bv = inst("BodyVelocity", {
            MaxForce=Vector3.new(9e9,9e9,9e9), Velocity=Vector3.zero, P=1250,
        }, hrp)
        bg = inst("BodyGyro", {
            MaxTorque=Vector3.new(9e9,9e9,9e9), P=3000, D=100, CFrame=hrp.CFrame,
        }, hrp)
        RS:BindToRenderStep(bind, Enum.RenderPriority.Character.Value+1, function()
            if not on or not bv or not bg then return end
            local c = LP.Character
            local root = c and c:FindFirstChild("HumanoidRootPart")
            if not root then return end
            local look, right = Cam.CFrame.LookVector, Cam.CFrame.RightVector
            local mv = Vector3.zero
            if UIS:IsKeyDown(Enum.KeyCode.W) then mv = mv + look end
            if UIS:IsKeyDown(Enum.KeyCode.S) then mv = mv - look end
            if UIS:IsKeyDown(Enum.KeyCode.D) then mv = mv + right end
            if UIS:IsKeyDown(Enum.KeyCode.A) then mv = mv - right end
            local v = mv * speed
            if UIS:IsKeyDown(Enum.KeyCode.Space) then v = v + Vector3.new(0,vert,0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl)
            or UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
                v = v - Vector3.new(0,vert,0)
            end
            bv.Velocity = v
            bg.CFrame = CFrame.new(root.Position, root.Position+look)
            local h = c:FindFirstChildOfClass("Humanoid")
            if h then h.PlatformStand = true end
        end)
    end
    local function stop()
        if bv then bv:Destroy(); bv = nil end
        if bg then bg:Destroy(); bg = nil end
        pcall(function() RS:UnbindFromRenderStep(bind) end)
        local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if h then h.PlatformStand = false end
    end

    toggle(t, "fly", false, function(v) on=v; if v then start() else stop() end end)
    slider(t, "flyspeed", 10, 300, 60, function(v) speed=v end)
    slider(t, "flyvert", 10, 200, 40, function(v) vert=v end)
    LP.CharacterAdded:Connect(function() task.wait(.5); if on then stop(); start() end end)
end

--============================================================ AUTO BOMB
do
    local t = tab("bomb")
    local on, jumpDelay, autoThrow = false, .2, true
    local throwDelay, allTools, busy = .15, false, false
    local function equipped()
        local tl = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
        if not tl then return false end
        if allTools then return true end
        local n = tl.Name:lower()
        return n:find("bomb") ~= nil or n:find("бомб") ~= nil
    end
    local function forceJump()
        local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if not h then return end
        local s = h:GetState()
        if s == Enum.HumanoidStateType.Jumping
        or s == Enum.HumanoidStateType.Freefall then
            h:ChangeState(Enum.HumanoidStateType.Freefall); task.wait()
        end
        h:ChangeState(Enum.HumanoidStateType.Jumping)
    end
    UIS.JumpRequest:Connect(function()
        if not on or busy or not equipped() then return end
        busy = true
        task.delay(jumpDelay, function()
            if not on or not equipped() then busy = false return end
            forceJump()
            if autoThrow then
                task.delay(throwDelay, function()
                    if on and equipped() then fire() end
                    busy = false
                end)
            else busy = false end
        end)
    end)
    toggle(t, "bomb", false, function(v) on=v end)
    slider(t, "jumpdelay", .05, .5, .2, function(v) jumpDelay=v end)
    toggle(t, "autothrow", true, function(v) autoThrow=v end)
    slider(t, "throwdelay", .02, .4, .15, function(v) throwDelay=v end)
    toggle(t, "alltools", false, function(v) allTools=v end)
end

--============================================================ ESP
do
    local t = tab("esp")
    local on, boxOn, nameOn, hpOn, tracerOn = false, true, true, true, false
    local color = Color3.fromRGB(255,80,80)
    local objs = {}
    local hasDraw = type(Drawing)=="table" or type(Drawing)=="userdata"
    if hasDraw then
        local function mk(cls, props)
            local d = Drawing.new(cls)
            for k, v in pairs(props) do d[k] = v end
            d.Visible = false; return d
        end
        local function create(p)
            if objs[p] then return end
            objs[p] = {
                box = mk("Square", {Thickness=1, Filled=false, Color=color}),
                name = mk("Text", {Size=14, Center=true, Outline=true, Color=Color3.new(1,1,1)}),
                hp = mk("Square", {Thickness=0, Filled=true, Color=Color3.fromRGB(0,255,0)}),
                tr = mk("Line", {Thickness=1, Color=color}),
            }
        end
        local function remove(p)
            local o = objs[p]
            if o then for _, d in pairs(o) do d:Remove() end; objs[p]=nil end
        end
        local function update()
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP then
                    if not objs[p] then create(p) end
                    local o = objs[p]
                    local ch = p.Character
                    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                    if not (hrp and hum and hum.Health > 0) then
                        for _, d in pairs(o) do d.Visible = false end
                    else
                        local pos, onc = Cam:WorldToViewportPoint(hrp.Position)
                        if not onc then
                            for _, d in pairs(o) do d.Visible = false end
                        else
                            local dst = (Cam.CFrame.Position-hrp.Position).Magnitude
                            local hh = math.clamp(1500/dst, 25, 200); local ww = hh/2
                            local tl = Vector2.new(pos.X-ww/2, pos.Y-hh/2)
                            o.box.Size=Vector2.new(ww,hh); o.box.Position=tl
                            o.box.Color=color; o.box.Visible=on and boxOn
                            o.name.Text=p.Name
                            o.name.Position=Vector2.new(pos.X, tl.Y-14)
                            o.name.Visible=on and nameOn
                            local r = hum.Health/hum.MaxHealth
                            o.hp.Size=Vector2.new(3,hh*r)
                            o.hp.Position=Vector2.new(tl.X-5, tl.Y+hh*(1-r))
                            o.hp.Color=Color3.fromRGB(255*(1-r),255*r,0)
                            o.hp.Visible=on and hpOn
                            o.tr.From=Vector2.new(Cam.ViewportSize.X/2, Cam.ViewportSize.Y)
                            o.tr.To=Vector2.new(pos.X,pos.Y)
                            o.tr.Color=color; o.tr.Visible=on and tracerOn
                        end
                    end
                end
            end
        end
        RS.RenderStepped:Connect(function() if on then update() end end)
        Players.PlayerRemoving:Connect(remove)

        toggle(t, "esp", false, function(v)
            on = v
            if not v then for p in pairs(objs) do remove(p) end end
        end)
        toggle(t, "box", true, function(v) boxOn=v end)
        toggle(t, "nm", true, function(v) nameOn=v end)
        toggle(t, "hp", true, function(v) hpOn=v end)
        toggle(t, "tracer", false, function(v) tracerOn=v end)
        button(t, "color", function()
            color = Color3.fromRGB(math.random(100,255), math.random(50,255), math.random(50,255))
        end)
    else
        inst("TextLabel", {
            Size=UDim2.new(1,0,0,40), BackgroundColor3=C.bg3,
            BorderSizePixel=0, Text="Drawing API недоступен",
            TextColor3=Color3.fromRGB(255,120,120),
            Font=Enum.Font.Gotham, TextSize=12, TextWrapped=true,
        }, t)
    end
end

--============================================================ PLAYER
do
    local t = tab("player")
    local noclipOn, noclipConn = false, nil
    toggle(t, "noclip", false, function(v)
        noclipOn = v
        if v and not noclipConn then
            noclipConn = RS.Stepped:Connect(function()
                if noclipOn and LP.Character then
                    for _, b in ipairs(LP.Character:GetDescendants()) do
                        if b:IsA("BasePart") then b.CanCollide = false end
                    end
                end
            end)
        elseif not v then
            if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
            if LP.Character then
                for _, b in ipairs(LP.Character:GetDescendants()) do
                    if b:IsA("BasePart") then b.CanCollide = true end
                end
            end
        end
    end)

    local infJump = false
    UIS.JumpRequest:Connect(function()
        if infJump then
            local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end)
    toggle(t, "infjump", false, function(v) infJump=v end)

    local ws, jp = 16, 50
    local function applyWS()
        local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = ws end
    end
    local function applyJP()
        local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if h then h.UseJumpPower = true; h.JumpPower = jp end
    end
    slider(t, "walkspeed", 16, 500, 16, function(v) ws=v; applyWS() end)
    slider(t, "jumppower", 50, 500, 50, function(v) jp=v; applyJP() end)

    local afk = false
    LP.Idled:Connect(function()
        if afk then
            pcall(function() VU:CaptureController(); VU:ClickButton2(Vector2.new()) end)
        end
    end)
    toggle(t, "antiafk", false, function(v) afk=v end)
    toggle(t, "antikill", false, function(v)
        antiKill = v
        if v then
            local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if h then pcall(function() h.Health = h.MaxHealth end) end
        end
    end)

    local freeze = false
    toggle(t, "freeze", false, function(v)
        freeze = v
        local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Anchored = v end
    end)

    local ragdoll = false
    RS.Heartbeat:Connect(function()
        if not ragdoll then return end
        local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if not h then return end
        local s = h:GetState()
        if s == Enum.HumanoidStateType.Physics
        or s == Enum.HumanoidStateType.Ragdoll then
            h:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end)
    toggle(t, "ragdoll", false, function(v) ragdoll=v end)

    button(t, "resetws", function() ws=16; jp=50; applyWS(); applyJP() end)
    button(t, "reset", function()
        local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if h then h.Health = 0 end
    end)
    button(t, "rejoin", function()
        pcall(function() Teleport:Teleport(game.PlaceId, LP) end)
    end)
    button(t, "spawn", function()
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local sp = workspace:FindFirstChildOfClass("SpawnLocation")
        if sp then hrp.CFrame = sp.CFrame + Vector3.new(0,5,0) end
    end)

    LP.CharacterAdded:Connect(function(c)
        task.wait(.8)
        if freeze then
            local hrp = c:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.Anchored = true end
        end
        applyWS(); applyJP()
    end)
end

--============================================================ WORLD
do
    local t = tab("world")
    local orig = {
        Brightness=Lighting.Brightness, ClockTime=Lighting.ClockTime,
        GlobalShadows=Lighting.GlobalShadows, FogEnd=Lighting.FogEnd,
        FogStart=Lighting.FogStart, OutdoorAmbient=Lighting.OutdoorAmbient,
        Ambient=Lighting.Ambient,
    }
    toggle(t, "bright", false, function(v)
        if v then
            Lighting.Brightness = 3; Lighting.ClockTime = 12
            Lighting.GlobalShadows = false; Lighting.FogEnd = 1e5
            Lighting.OutdoorAmbient = Color3.new(1,1,1); Lighting.Ambient = Color3.new(1,1,1)
        else
            for k, val in pairs(orig) do Lighting[k] = val end
        end
    end)
    toggle(t, "nofog", false, function(v)
        if v then Lighting.FogEnd = 1e5; Lighting.FogStart = 0
        else Lighting.FogEnd = orig.FogEnd; Lighting.FogStart = orig.FogStart end
    end)
    button(t, "fps", function()
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Smoke")
            or v:IsA("Fire") or v:IsA("Sparkles") then
                pcall(function() v.Enabled = false end)
            end
        end
    end)
    button(t, "removelights", function()
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("PointLight") or v:IsA("SpotLight")
            or v:IsA("SurfaceLight") then
                pcall(function() v.Enabled = false end)
            end
        end
    end)
    button(t, "tprandom", function()
        local pool = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then table.insert(pool, hrp) end
            end
        end
        if #pool > 0 then
            local tgt = pool[math.random(#pool)]
            local my = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if my then my.CFrame = tgt.CFrame + Vector3.new(0,3,0) end
        end
    end)

    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then table.insert(names, p.Name) end
    end
    if #names > 0 then
        dropdown(t, "tprandom", names, names[1], function(name)
            local p = Players:FindFirstChild(name)
            if p and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                local my = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                if hrp and my then my.CFrame = hrp.CFrame + Vector3.new(0,3,0) end
            end
        end)
    end
end

--============================================================ CURSORS (fixed)
do
    local t = tab("cursors")
    local cg = inst("ScreenGui", {
        Name="kemlopHubCursor", ResetOnSpawn=false,
        IgnoreGuiInset=false, DisplayOrder=2147483647,
        ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
    }, PG)
    local img = inst("ImageLabel", {
        Name="Cursor", Size=UDim2.fromOffset(32,32),
        AnchorPoint=Vector2.new(.5,.5), BackgroundTransparency=1,
        ScaleType=Enum.ScaleType.Fit, Active=false,
        Visible=false, ZIndex=2147483647,
    }, cg)

    local active, size = false, 32
    local mouse = LP:GetMouse()

    local function currentPos()
        local ok, mx, my = pcall(function() return mouse.X, mouse.Y end)
        if ok and mx and my then
            return Vector2.new(mx, my)
        end
        local ok2, p = pcall(function() return UIS:GetMouseLocation() end)
        if ok2 and p and typeof(p) == "Vector2" then return p end
        return Vector2.new(0, 0)
    end

    local function updatePos()
        if not active then
            if img.Visible then img.Visible = false end
            return
        end
        if not img.Visible then img.Visible = true end
        pcall(function()
            local p = currentPos()
            img.Position = UDim2.fromOffset(p.X, p.Y)
        end)
    end

    RS.RenderStepped:Connect(updatePos)
    UIS.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            updatePos()
        end
    end)

    local function setCursor(id)
        if not id then
            active = false; img.Visible = false
            UIS.MouseIconEnabled = true; return
        end
        img.Image = "rbxassetid://"..tostring(id)
        img.Size = UDim2.fromOffset(size, size)
        active = true; img.Visible = true
        UIS.MouseIconEnabled = false
        updatePos()
    end

    task.spawn(function()
        while cg.Parent do
            if active and UIS.MouseIconEnabled then UIS.MouseIconEnabled = false end
            task.wait(.5)
        end
    end)

    slider(t, "csize", 16, 96, 32, function(v)
        size = v
        if active then img.Size = UDim2.fromOffset(v, v) end
    end)

    local list = {
        {1827745860,"Маленький прицел"},{1478500977,"Средний круглый"},
        {2555584348,"Большой прицел"},{412284862,"Красная точка"},
        {1012273002,"Красный круглый"},{51838212,"Пентаграмма"},
        {61210994,"Ромб"},{11716557686,"Звезда"},
        {11716560177,"Звезда 2"},{11722368307,"Сердце"},
        {11722865980,"Сердце 2"},{12534101433,"Глаз"},
        {12232793816,"Глаз 2"},{11780968239,"Снежинка"},
        {10973237327,"Hello Kitty"},{11710308636,"Hello Kitty 2"},
        {11716290197,"Hello Kitty 3"},{11717813996,"Hello Kitty 4"},
        {10763952275,"Лягушка"},{7590894535,"Черепаха"},
        {11150110589,"Розовый медведь"},{11717093063,"Пончик"},
        {8680062686,"Shoot this guy"},{4876554,"Koopa"},
        {12233185690,"Соник"},{9967264,"Slipknot"},
        {5462831,"Star Wars"},{2747009680,"Солнце"},
        {42341278,"Пейзаж"},{1143727,"Набросок"},
        {12356743,"Фен"},{7643532,"Трискелион"},
        {63627885,"Курсор-рука"},
    }
    local grid = inst("Frame", {
        Size=UDim2.new(1,0,0,0),
        AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1,
    }, t)
    inst("UIGridLayout", {
        CellSize=UDim2.new(0,84,0,96),
        CellPadding=UDim2.new(0,5,0,5),
        SortOrder=Enum.SortOrder.LayoutOrder,
    }, grid)

    local function card(name, id, order, isOff)
        local c = inst("TextButton", {
            Size=UDim2.new(0,84,0,96),
            BackgroundColor3=C.bg3, BorderSizePixel=0,
            AutoButtonColor=false, Text="", LayoutOrder=order,
        }, grid)
        inst("UICorner", {CornerRadius=UDim.new(0,4)}, c)
        local stroke = inst("UIStroke", {Color=C.off, Thickness=1}, c)
        if not isOff then
            inst("ImageLabel", {
                Size=UDim2.fromOffset(52,52), Position=UDim2.new(.5,-26,0,6),
                BackgroundTransparency=1, Image="rbxassetid://"..id,
                ScaleType=Enum.ScaleType.Fit,
            }, c)
        else
            inst("TextLabel", {
                Size=UDim2.new(1,0,0,52), Position=UDim2.new(0,0,0,6),
                BackgroundTransparency=1, Text="×",
                TextColor3=Color3.fromRGB(255,100,100),
                Font=Enum.Font.GothamBold, TextSize=30,
            }, c)
        end
        inst("TextLabel", {
            Size=UDim2.new(1,-4,0,34), Position=UDim2.new(0,2,1,-36),
            BackgroundTransparency=1, Text=name, TextColor3=C.txt,
            Font=Enum.Font.Gotham, TextSize=10, TextWrapped=true,
        }, c)
        c.MouseButton1Click:Connect(function()
            setCursor(isOff and nil or id)
            for _, x in ipairs(grid:GetChildren()) do
                if x:IsA("TextButton") then
                    x.BackgroundColor3 = C.bg3
                    local s = x:FindFirstChildOfClass("UIStroke")
                    if s then s.Color = C.off end
                end
            end
            c.BackgroundColor3 = C.acc
            stroke.Color = C.acc
        end)
    end
    card("Выкл", nil, 0, true)
    for i, e in ipairs(list) do card(e[2], e[1], i, false) end
end

--============================================================ SETTINGS
do
    local t = tab("settings")
    dropdown(t, "lang", {"RU","EN","UA"}, curLang, function(o)
        curLang = o
        refreshLang()
    end)
    local statsLbl = inst("TextLabel", {
        Size=UDim2.new(1,0,0,44), BackgroundColor3=C.bg3,
        BorderSizePixel=0, TextColor3=C.txt,
        Font=Enum.Font.Gotham, TextSize=12, TextWrapped=true,
    }, t)
    inst("UICorner", {CornerRadius=UDim.new(0,4)}, statsLbl)
    local acc, cnt = 0, 0
    RS.RenderStepped:Connect(function(dt)
        acc = acc + dt; cnt = cnt + 1
        if acc >= .5 then
            local fps = math.floor(cnt / acc)
            local ping = 0
            pcall(function() ping = math.floor(LP:GetNetworkPing() * 1000) end)
            statsLbl.Text = T("fpslabel")..": "..fps.."  |  "..T("pinglabel")..": "..ping.."ms"
            acc, cnt = 0, 0
        end
    end)
    button(t, "notifytest", function() notify("kemlopHub", T("loaded"), 3) end)
end

--============================================================ STARTUP LANGUAGE PICKER
tabBtnMap["aimbot"].BackgroundColor3 = C.acc
tabMap["aimbot"].Visible = true

local function showLangPicker()
    local pick = inst("ScreenGui", {
        Name="kemlopHubLangPick", ResetOnSpawn=false,
        IgnoreGuiInset=true, DisplayOrder=2147483645,
    }, PG)
    local overlay = inst("Frame", {
        Size=UDim2.fromScale(1,1), BackgroundColor3=Color3.new(),
        BackgroundTransparency=.55, BorderSizePixel=0,
    }, pick)
    local box = inst("Frame", {
        Size=UDim2.fromOffset(320,250),
        Position=UDim2.new(.5,-160,.5,-125),
        BackgroundColor3=C.bg, BorderSizePixel=0,
    }, pick)
    inst("UICorner", {CornerRadius=UDim.new(0,8)}, box)
    inst("UIStroke", {Color=C.acc, Thickness=2}, box)
    inst("TextLabel", {
        Size=UDim2.new(1,0,0,56), BackgroundTransparency=1,
        Text="kemlopHub\nChoose language / Выбери язык / Обери мову",
        TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBold,
        TextSize=15, TextWrapped=true,
    }, box)
    local opts = {
        {code="RU", name="Русский"},
        {code="EN", name="English"},
        {code="UA", name="Українська"},
    }
    for i, o in ipairs(opts) do
        local b = inst("TextButton", {
            Size=UDim2.new(1,-40,0,44),
            Position=UDim2.new(0,20,0,64+(i-1)*52),
            BackgroundColor3=C.bg3, BorderSizePixel=0,
            Text=o.name, TextColor3=C.txt,
            Font=Enum.Font.Gotham, TextSize=14, AutoButtonColor=false,
        }, box)
        inst("UICorner", {CornerRadius=UDim.new(0,6)}, b)
        b.MouseButton1Click:Connect(function()
            curLang = o.code
            refreshLang()
            pick:Destroy()
            main.Visible = true
            task.delay(.2, function() notify("kemlopHub", T("loaded"), 5) end)
        end)
    end
end

showLangPicker()

UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.K then main.Visible = not main.Visible end
    if i.KeyCode == Enum.KeyCode.Z and _G.KemlopFarm then _G.KemlopFarm(true) end
end)

print("[kemlopHub] loaded")
