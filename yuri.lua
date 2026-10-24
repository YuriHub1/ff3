-- yuri | ff3
-- boot patterns inspired by solid hub loaders (unload / safe fn / no double-run)
print('[Yuri] loading...')
getgenv().YURI_VERSION = '3.2.0-quality'
print('[Yuri] version', getgenv().YURI_VERSION)

if getgenv and getgenv().YuriHub and getgenv().YuriHub.Unload then
    pcall(function() getgenv().YuriHub.Unload() end)
end

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Yuri = { connections = {}, cleanups = {}, destroyed = false }
if getgenv then getgenv().YuriHub = Yuri end

local function yuriFn(name)
    local v
    pcall(function() v = getfenv(0)[name] end)
    if type(v) ~= 'function' then pcall(function() v = getfenv()[name] end) end
    if type(v) ~= 'function' and getgenv then pcall(function() v = getgenv()[name] end) end
    return type(v) == 'function' and v or nil
end

local function yuriTrack(c)
    if c then
        Yuri.connections[#Yuri.connections + 1] = c
    end
    return c
end

local function yuriOnUnload(f)
    Yuri.cleanups[#Yuri.cleanups + 1] = f
end

function Yuri.Unload()
    if Yuri.destroyed then return end
    Yuri.destroyed = true
    for _, f in ipairs(Yuri.cleanups) do pcall(f) end
    for _, c in ipairs(Yuri.connections) do
        pcall(function()
            if typeof(c) == 'RBXScriptConnection' then c:Disconnect()
            elseif type(c) == 'table' and c.Disconnect then c:Disconnect() end
        end)
    end
    table.clear(Yuri.connections)
    table.clear(Yuri.cleanups)
    pcall(function()
        if YuriUI and YuriUI._lastGui then YuriUI._lastGui:Destroy() end
    end)
    if getgenv and getgenv().YuriHub == Yuri then getgenv().YuriHub = nil end
    print('[Yuri] unloaded')
end

local UserInputService = game:GetService('UserInputService')
local TweenService = game:GetService('TweenService')
local RunService = game:GetService('RunService')
local CoreGui = game:GetService('CoreGui')
local Players = game:GetService('Players')
local TextService = game:GetService('TextService')
local HttpService = game:GetService('HttpService')

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    local t0 = os.clock()
    while not Players.LocalPlayer and os.clock() - t0 < 10 do
        task.wait(0.1)
    end
    LocalPlayer = Players.LocalPlayer
end
if not LocalPlayer then
    warn('[Yuri] LocalPlayer not found - execute while in a game')
    return
end

local lp = LocalPlayer
local player = LocalPlayer
local players = Players
print('[Yuri] player:', lp.Name)
pcall(function()
    print('[Yuri] executor:', (yuriFn('identifyexecutor') and yuriFn('identifyexecutor')()) or (yuriFn('getexecutorname') and yuriFn('getexecutorname')()) or 'unknown')
end)
print('[Yuri] boot ok')
local YURI_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
print('[Yuri] device:', YURI_MOBILE and 'mobile/touch' or 'pc')
local function yuriWait(pc, mobile)
    task.wait(YURI_MOBILE and (mobile or 0.12) or (pc or 0.03))
end

-- Glass HUD palette (glass-ui-v2)
local ACCENT = Color3.fromRGB(79, 147, 238)
local ACCENT_DIM = Color3.fromRGB(60, 120, 200)
local ACCENT_HOT = Color3.fromRGB(79, 147, 238)
local BG = Color3.fromRGB(28, 32, 40)
local BG2 = Color3.fromRGB(36, 40, 50)
local BG3 = Color3.fromRGB(48, 54, 66)
local ROW = Color3.fromRGB(40, 44, 54)
local TEXT = Color3.fromRGB(233, 237, 245)
local TEXT_DIM = Color3.fromRGB(143, 152, 170)
local STROKE = Color3.fromRGB(255, 255, 255)
local GLASS = Color3.fromRGB(32, 36, 46)
local CYAN = ACCENT
local CYAN_DIM = ACCENT_DIM
local AMBER = Color3.fromRGB(242, 162, 60)
local AMBER_DIM = Color3.fromRGB(200, 130, 40)

local gethui_ = yuriFn('gethui')
local function getGuiParent()
    local ok, gui = pcall(function()
        if gethui_ then
            local h = gethui_()
            if h then return h end
        end
        return CoreGui
    end)
    if ok and gui then return gui end
    local pg = LocalPlayer:FindFirstChild('PlayerGui')
    if pg then return pg end
    pg = LocalPlayer:WaitForChild('PlayerGui', 5)
    if pg then return pg end
    return CoreGui
end

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
    return c
end

local function stroke(p, col, th, tr)
    local s = Instance.new("UIStroke")
    s.Color = col or STROKE
    s.Thickness = th or 1
    s.Transparency = tr or 0.3
    s.Parent = p
    return s
end

local function pad(p, t, b, l, r)
    local u = Instance.new("UIPadding")
    u.PaddingTop = UDim.new(0, t or 8)
    u.PaddingBottom = UDim.new(0, b or 8)
    u.PaddingLeft = UDim.new(0, l or 10)
    u.PaddingRight = UDim.new(0, r or 10)
    u.Parent = p
    return u
end

local function gradient(p, c1, c2, rot)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, c1),
        ColorSequenceKeypoint.new(1, c2),
    })
    g.Rotation = rot or 90
    g.Parent = p
    return g
end

local _usedNames = {}
local function uniqueName(name)
    name = (type(name) == "string" and name ~= "" and name) or "Flag"
    if not _usedNames[name] then _usedNames[name] = true return name end
    local i = 2
    while _usedNames[name .. " " .. i] do i += 1 end
    local out = name .. " " .. i
    _usedNames[out] = true
    return out
end

local YuriUI = {}
YuriUI.__index = YuriUI

function YuriUI:CreateWindow(opts)
    opts = opts or {}
    local self = setmetatable({}, YuriUI)

    local gui = Instance.new("ScreenGui")
    gui.Name = "YuriHub"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 100
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(gui) end
    end)
    gui.Parent = getGuiParent()
    self.Gui = gui
    YuriUI._lastGui = gui


    -- Yuri Hub glass status pill (top)
    local fpsHud = Instance.new("Frame")
    fpsHud.Name = "FpsHud"
    fpsHud.AutomaticSize = Enum.AutomaticSize.X
    fpsHud.Size = UDim2.fromOffset(0, 28)
    fpsHud.Position = UDim2.new(0.5, 0, 0, 12)
    fpsHud.AnchorPoint = Vector2.new(0.5, 0)
    fpsHud.BackgroundColor3 = Color3.fromRGB(245, 247, 250)
    fpsHud.BackgroundTransparency = 0.08
    fpsHud.BorderSizePixel = 0
    fpsHud.Parent = gui
    corner(fpsHud, 14)
    local fpsStroke = stroke(fpsHud, Color3.fromRGB(200, 205, 215), 1, 0.55)

    local fpsPad = Instance.new("UIPadding")
    fpsPad.PaddingLeft = UDim.new(0, 10)
    fpsPad.PaddingRight = UDim.new(0, 12)
    fpsPad.Parent = fpsHud

    local fpsLayout = Instance.new("UIListLayout")
    fpsLayout.FillDirection = Enum.FillDirection.Horizontal
    fpsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    fpsLayout.Padding = UDim.new(0, 8)
    fpsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    fpsLayout.Parent = fpsHud

    local function pillSep()
        local s = Instance.new("Frame")
        s.Size = UDim2.fromOffset(1, 12)
        s.BackgroundColor3 = Color3.fromRGB(180, 185, 195)
        s.BackgroundTransparency = 0.35
        s.BorderSizePixel = 0
        s.LayoutOrder = 50
        s.Parent = fpsHud
        return s
    end

    local logoDot = Instance.new("Frame")
    logoDot.Size = UDim2.fromOffset(16, 16)
    logoDot.BackgroundColor3 = ACCENT
    logoDot.BorderSizePixel = 0
    logoDot.LayoutOrder = 1
    logoDot.Parent = fpsHud
    corner(logoDot, 8)
    local logoT = Instance.new("TextLabel")
    logoT.BackgroundTransparency = 1
    logoT.Size = UDim2.fromScale(1, 1)
    logoT.Font = Enum.Font.GothamBold
    logoT.TextSize = 9
    logoT.TextColor3 = Color3.new(1, 1, 1)
    logoT.Text = "Y"
    logoT.Parent = logoDot

    local nameLbl = Instance.new("TextLabel")
    nameLbl.BackgroundTransparency = 1
    nameLbl.AutomaticSize = Enum.AutomaticSize.X
    nameLbl.Size = UDim2.fromOffset(0, 28)
    nameLbl.Font = Enum.Font.GothamMedium
    nameLbl.TextSize = 12
    nameLbl.TextColor3 = Color3.fromRGB(40, 44, 52)
    nameLbl.Text = "Yuri Hub"
    nameLbl.LayoutOrder = 2
    nameLbl.Parent = fpsHud

    local sep1 = Instance.new("Frame")
    sep1.Size = UDim2.fromOffset(1, 12)
    sep1.BackgroundColor3 = Color3.fromRGB(180, 185, 195)
    sep1.BackgroundTransparency = 0.35
    sep1.BorderSizePixel = 0
    sep1.LayoutOrder = 3
    sep1.Parent = fpsHud

    local fpsLbl = Instance.new("TextLabel")
    fpsLbl.BackgroundTransparency = 1
    fpsLbl.AutomaticSize = Enum.AutomaticSize.X
    fpsLbl.Size = UDim2.fromOffset(0, 28)
    fpsLbl.Font = Enum.Font.GothamMedium
    fpsLbl.TextSize = 12
    fpsLbl.TextColor3 = Color3.fromRGB(40, 44, 52)
    fpsLbl.Text = "-- FPS"
    fpsLbl.LayoutOrder = 6
    fpsLbl.Parent = fpsHud

    local sep3 = Instance.new("Frame")
    sep3.Size = UDim2.fromOffset(1, 12)
    sep3.BackgroundColor3 = Color3.fromRGB(180, 185, 195)
    sep3.BackgroundTransparency = 0.35
    sep3.BorderSizePixel = 0
    sep3.LayoutOrder = 7
    sep3.Parent = fpsHud

    local pingLbl = Instance.new("TextLabel")
    pingLbl.BackgroundTransparency = 1
    pingLbl.AutomaticSize = Enum.AutomaticSize.X
    pingLbl.Size = UDim2.fromOffset(0, 28)
    pingLbl.Font = Enum.Font.GothamMedium
    pingLbl.TextSize = 12
    pingLbl.TextColor3 = Color3.fromRGB(40, 44, 52)
    pingLbl.Text = "-- PING"
    pingLbl.LayoutOrder = 8
    pingLbl.Parent = fpsHud

    local sep4 = Instance.new("Frame")
    sep4.Size = UDim2.fromOffset(1, 12)
    sep4.BackgroundColor3 = Color3.fromRGB(180, 185, 195)
    sep4.BackgroundTransparency = 0.35
    sep4.BorderSizePixel = 0
    sep4.LayoutOrder = 9
    sep4.Parent = fpsHud

    local clockLbl = Instance.new("TextLabel")
    clockLbl.BackgroundTransparency = 1
    clockLbl.AutomaticSize = Enum.AutomaticSize.X
    clockLbl.Size = UDim2.fromOffset(0, 28)
    clockLbl.Font = Enum.Font.Gotham
    clockLbl.TextSize = 12
    clockLbl.TextColor3 = Color3.fromRGB(70, 76, 88)
    clockLbl.Text = "--:--"
    clockLbl.LayoutOrder = 10
    clockLbl.Parent = fpsHud

    task.spawn(function()
        local frames, t0 = 0, os.clock()
        game:GetService("RunService").RenderStepped:Connect(function()
            frames += 1
            local now = os.clock()
            if now - t0 >= 0.5 then
                local fps = math.floor(frames / (now - t0) + 0.5)
                frames, t0 = 0, now
                fpsLbl.Text = tostring(fps) .. " FPS"
                pcall(function()
                    local p = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
                    pingLbl.Text = math.floor(p + 0.5) .. " PING"
                end)
                local t = os.date("*t")
                local h = t.hour % 12
                if h == 0 then h = 12 end
                local am = t.hour < 12 and "AM" or "PM"
                clockLbl.Text = string.format("%d:%02d %s", h, t.min, am)
            end
        end)
    end)



    ------------------------------------------------------------------
    -- Floating toggle (Yuna-style presence, original mark - not a tree)
    ------------------------------------------------------------------

    local openBtn = Instance.new("TextButton")
    openBtn.Name = "OpenBtn"
    openBtn.Size = UDim2.fromOffset(44, 44)
    openBtn.Position = UDim2.new(0, 14, 0.5, -22)
    openBtn.BackgroundColor3 = BG
    openBtn.BackgroundTransparency = 0.15
    openBtn.Text = "Y"
    openBtn.TextColor3 = Color3.new(1, 1, 1)
    openBtn.TextSize = 18
    openBtn.Font = Enum.Font.GothamBold
    openBtn.AutoButtonColor = false
    openBtn.Parent = gui
    corner(openBtn, 13)
    stroke(openBtn, ACCENT, 1.5, 0.35)
    local openFill = Instance.new("Frame")
    openFill.Size = UDim2.fromScale(1, 1)
    openFill.BackgroundColor3 = ACCENT
    openFill.BackgroundTransparency = 0.15
    openFill.BorderSizePixel = 0
    openFill.ZIndex = 0
    openFill.Parent = openBtn
    corner(openFill, 13)
    openBtn.TextTransparency = 0
    openBtn.ZIndex = 2

    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.new(0, 620, 0, 470)
    main.Position = UDim2.new(0.5, -310, 0.5, -235)
    main.BackgroundColor3 = BG
    main.BackgroundTransparency = 0.12
    main.BorderSizePixel = 0
    main.Visible = true
    main.ClipsDescendants = true
    main.Parent = gui
    corner(main, 16)
    local mainStroke = stroke(main, Color3.fromRGB(255, 255, 255), 1, 0.88)

    -- Glass top bar
    local top = Instance.new("Frame")
    top.Size = UDim2.new(1, 0, 0, 48)
    top.BackgroundColor3 = BG2
    top.BackgroundTransparency = 0.35
    top.BorderSizePixel = 0
    top.Parent = main
    corner(top, 16)
    local topFix = Instance.new("Frame")
    topFix.Size = UDim2.new(1, 0, 0, 16)
    topFix.Position = UDim2.new(0, 0, 1, -16)
    topFix.BackgroundColor3 = BG2
    topFix.BackgroundTransparency = 0.35
    topFix.BorderSizePixel = 0
    topFix.Parent = top

    local logo = Instance.new("Frame")
    logo.Size = UDim2.fromOffset(30, 30)
    logo.Position = UDim2.new(0, 12, 0.5, -15)
    logo.BackgroundColor3 = ACCENT
    logo.BorderSizePixel = 0
    logo.Parent = top
    corner(logo, 10)
    local logoT = Instance.new("TextLabel")
    logoT.BackgroundTransparency = 1
    logoT.Size = UDim2.fromScale(1, 1)
    logoT.Font = Enum.Font.GothamBold
    logoT.TextSize = 14
    logoT.TextColor3 = Color3.new(1, 1, 1)
    logoT.Text = "Y"
    logoT.Parent = logo

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, 50, 0, 0)
    title.Size = UDim2.new(0.4, 0, 1, 0)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = TEXT
    title.Text = "Yuri Hub"
    title.Parent = top

    local sub = Instance.new("TextLabel")
    sub.BackgroundTransparency = 1
    sub.Position = UDim2.new(0.45, 0, 0, 0)
    sub.Size = UDim2.new(0.35, 0, 1, 0)
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 11
    sub.TextColor3 = TEXT_DIM
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Text = "FF3  |  glass"
    sub.Parent = top

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -38, 0.5, -14)
    closeBtn.BackgroundColor3 = BG3
    closeBtn.Text = "x"
    closeBtn.TextColor3 = TEXT_DIM
    closeBtn.TextSize = 18
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = top
    corner(closeBtn, 8)
    stroke(closeBtn, STROKE, 1, 0.5)

    -- Sidebar
    local side = Instance.new("Frame")
    side.Size = UDim2.new(0, 54, 1, -46)
    side.Position = UDim2.new(0, 0, 0, 46)
    side.BackgroundColor3 = ROW
    side.BackgroundTransparency = 0.35
    side.BorderSizePixel = 0
    side.Parent = main

    local sideAccent = Instance.new("Frame")
    sideAccent.Size = UDim2.new(0, 2, 1, 0)
    sideAccent.Position = UDim2.new(1, -2, 0, 0)
    sideAccent.BackgroundColor3 = CYAN
    sideAccent.BackgroundTransparency = 0.7
    sideAccent.BorderSizePixel = 0
    sideAccent.Parent = side

    local sideList = Instance.new("UIListLayout")
    sideList.Padding = UDim.new(0, 6)
    sideList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    sideList.Parent = side
    pad(side, 10, 10, 0, 0)

    -- Content
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -62, 1, -54)
    content.Position = UDim2.new(0, 58, 0, 50)
    content.BackgroundTransparency = 1
    content.Parent = main

    -- Yuna-style search bar
    local searchWrap = Instance.new("Frame")
    searchWrap.Name = "SearchBar"
    searchWrap.Size = UDim2.new(1, -8, 0, 32)
    searchWrap.Position = UDim2.new(0, 4, 0, 4)
    searchWrap.BackgroundColor3 = Color3.fromRGB(32, 34, 40)
    searchWrap.BorderSizePixel = 0
    searchWrap.Parent = content
    corner(searchWrap, 8)

    local searchIcon = Instance.new("TextLabel")
    searchIcon.BackgroundTransparency = 1
    searchIcon.Size = UDim2.fromOffset(28, 32)
    searchIcon.Position = UDim2.new(0, 4, 0, 0)
    searchIcon.Font = Enum.Font.Gotham
    searchIcon.TextSize = 14
    searchIcon.TextColor3 = TEXT_DIM
    searchIcon.Text = "Q"
    searchIcon.Parent = searchWrap
    -- use unicode magnifier if possible
    pcall(function() searchIcon.Text = "?" end)

    local searchBox = Instance.new("TextBox")
    searchBox.Name = "SearchBox"
    searchBox.BackgroundTransparency = 1
    searchBox.Position = UDim2.new(0, 30, 0, 0)
    searchBox.Size = UDim2.new(1, -60, 1, 0)
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextSize = 13
    searchBox.TextColor3 = TEXT
    searchBox.PlaceholderColor3 = TEXT_DIM
    searchBox.PlaceholderText = "Search features..."
    searchBox.Text = ""
    searchBox.ClearTextOnFocus = false
    searchBox.TextXAlignment = Enum.TextXAlignment.Left
    searchBox.Parent = searchWrap

    local searchClear = Instance.new("TextButton")
    searchClear.Name = "Clear"
    searchClear.Size = UDim2.fromOffset(28, 28)
    searchClear.Position = UDim2.new(1, -30, 0.5, -14)
    searchClear.BackgroundTransparency = 1
    searchClear.Text = "x"
    searchClear.Font = Enum.Font.GothamBold
    searchClear.TextSize = 16
    searchClear.TextColor3 = TEXT_DIM
    searchClear.Visible = false
    searchClear.Parent = searchWrap

    local pagesHost = Instance.new("Frame")
    pagesHost.Name = "PagesHost"
    pagesHost.Size = UDim2.new(1, 0, 1, -40)
    pagesHost.Position = UDim2.new(0, 0, 0, 40)
    pagesHost.BackgroundTransparency = 1
    pagesHost.Parent = content

    local pages = {}
    local tabsOrder = {}
    local activeTab = nil

    local function applySearchFilter(query)
        query = string.lower(tostring(query or ""):gsub("^%s+", ""):gsub("%s+$", ""))
        searchClear.Visible = #query > 0
        for _, page in pairs(pages) do
            for _, child in ipairs(page:GetChildren()) do
                if child:IsA("Frame") or child:IsA("TextButton") then
                    local lbl = child:FindFirstChildOfClass("TextLabel")
                    local text = ""
                    if lbl then text = string.lower(lbl.Text or "") end
                    if child:IsA("TextButton") then
                        text = text .. " " .. string.lower(child.Text or "")
                    end
                    if query == "" then
                        child.Visible = true
                    else
                        child.Visible = string.find(text, query, 1, true) ~= nil
                    end
                end
            end
        end
    end

    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        applySearchFilter(searchBox.Text)
    end)
    searchClear.MouseButton1Click:Connect(function()
        searchBox.Text = ""
        applySearchFilter("")
    end)

    local function showTab(name)
        for n, page in pairs(pages) do
            page.Visible = (n == name)
        end
        activeTab = name
        for _, btn in ipairs(tabsOrder) do
            local on = btn.Name == name
            btn.BackgroundColor3 = on and CYAN_DIM or BG3
            btn.TextColor3 = on and Color3.new(1,1,1) or TEXT_DIM
            local img = btn:FindFirstChildOfClass("ImageLabel")
            if img then
                img.ImageColor3 = on and Color3.new(1,1,1) or TEXT_DIM
            end
            local ind = btn:FindFirstChild("ActiveBar")
            if ind then ind.Visible = on end
        end
        title.Text = name
    end

    -- Drag main
    do
        local dragging, dragStart, startPos
        top.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = main.Position
            end
        end)
        top.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local d = input.Position - dragStart
                main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)
    end

    local menuOpen = false
    local function setOpen(v)
        menuOpen = v
        main.Visible = v
    end
    setOpen(false) -- start closed
    openBtn.MouseButton1Click:Connect(function() setOpen(not menuOpen) end)
    closeBtn.MouseButton1Click:Connect(function() setOpen(false) end)

    -- Drag open button
    do
        local dragging, start, origin, moved
        openBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                moved = false
                start = input.Position
                origin = openBtn.Position
            end
        end)
        openBtn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if not dragging then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                local d = input.Position - start
                if d.Magnitude > 4 then moved = true end
                openBtn.Position = UDim2.new(origin.X.Scale, origin.X.Offset + d.X, origin.Y.Scale, origin.Y.Offset + d.Y)
            end
        end)
    end

    function self:CreateTab(opts)
        opts = opts or {}
        local name = opts.Name or "Tab"
        local icon = opts.Icon
        if type(icon) ~= "string" or icon == "" then
            icon = nil
        end

        local tabBtn = Instance.new("TextButton")
        tabBtn.Name = name
        tabBtn.Size = UDim2.new(0, 36, 0, 36)
        tabBtn.BackgroundColor3 = ROW
        tabBtn.BackgroundTransparency = 0.25
        tabBtn.Text = string.sub(name, 1, 1)
        tabBtn.TextColor3 = TEXT_DIM
        tabBtn.TextSize = 14
        tabBtn.Font = Enum.Font.GothamBold
        tabBtn.AutoButtonColor = false
        tabBtn.Parent = side
        corner(tabBtn, 10)

        if icon and icon:find("rbxassetid") then
            tabBtn.Text = ""
            local img = Instance.new("ImageLabel")
            img.BackgroundTransparency = 1
            img.Size = UDim2.new(0, 18, 0, 18)
            img.Position = UDim2.new(0.5, -9, 0.5, -9)
            img.Image = icon
            img.ImageColor3 = TEXT_DIM
            img.Parent = tabBtn
        end

        local activeBar = Instance.new("Frame")
        activeBar.Name = "ActiveBar"
        activeBar.Size = UDim2.new(0, 3, 0, 16)
        activeBar.Position = UDim2.new(0, 2, 0.5, -8)
        activeBar.BackgroundColor3 = CYAN
        activeBar.BorderSizePixel = 0
        activeBar.Visible = false
        activeBar.Parent = tabBtn
        corner(activeBar, 2)

        table.insert(tabsOrder, tabBtn)

        local page = Instance.new("ScrollingFrame")
        page.Name = name
        page.Size = UDim2.new(1, -4, 1, -4)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 3
        page.ScrollBarImageColor3 = CYAN
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.Visible = false
        page.Parent = pagesHost

        local list = Instance.new("UIListLayout")
        list.Padding = UDim.new(0, 5)
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Parent = page
        pad(page, 8, 14, 8, 10)

        pages[name] = page
        tabBtn.MouseButton1Click:Connect(function() showTab(name) end)
        if not activeTab then showTab(name) end

        local tab = {}
        local order = 0
        local function nextOrder()
            order += 1
            return order
        end

        local function makeRow(labelText)
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, -6, 0, 36)
            row.BackgroundColor3 = ROW
            row.BackgroundTransparency = 0.2
            row.BorderSizePixel = 0
            row.LayoutOrder = nextOrder()
            row.Parent = page
            corner(row, 10)

            local lbl = Instance.new("TextLabel")
            lbl.BackgroundTransparency = 1
            lbl.Position = UDim2.new(0, 12, 0, 0)
            lbl.Size = UDim2.new(0.62, 0, 1, 0)
            lbl.Font = Enum.Font.GothamMedium
            lbl.TextSize = 12
            lbl.TextColor3 = TEXT
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Text = labelText
            lbl.Parent = row
            return row, lbl
        end

        function tab:CreateToggle(o)
            o = o or {}
            local name = uniqueName(o.Name or "Toggle")
            local flag = { Value = o.Default == true, Name = name }
            local row = select(1, makeRow(name))

            local track = Instance.new("Frame")
            track.Size = UDim2.new(0, 36, 0, 20)
            track.Position = UDim2.new(1, -48, 0.5, -10)
            track.BackgroundColor3 = flag.Value and ACCENT or Color3.fromRGB(58, 64, 78)
            track.BorderSizePixel = 0
            track.Parent = row
            corner(track, 12)

            local knob = Instance.new("Frame")
            knob.Size = UDim2.new(0, 16, 0, 16)
            knob.Position = flag.Value and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
            knob.BackgroundColor3 = Color3.new(1, 1, 1)
            knob.BorderSizePixel = 0
            knob.Parent = track
            corner(knob, 9)

            local function render()
                TweenService:Create(track, TweenInfo.new(0.15), {
                    BackgroundColor3 = flag.Value and ACCENT_HOT or Color3.fromRGB(45, 50, 58)
                }):Play()
                TweenService:Create(knob, TweenInfo.new(0.15), {
                    Position = flag.Value and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
                }):Play()
            end

            local hit = Instance.new("TextButton")
            hit.Size = UDim2.new(1, 0, 1, 0)
            hit.BackgroundTransparency = 1
            hit.Text = ""
            hit.Parent = row
            hit.MouseButton1Click:Connect(function()
                flag.Value = not flag.Value
                render()
                if o.Callback then pcall(o.Callback, flag.Value) end
            end)

            return flag
        end

        function tab:CreateSlider(o)
            o = o or {}
            local name = uniqueName(o.Name or "Slider")
            local min = o.Min or 0
            local max = o.Max or 100
            local val = o.Default or min
            local flag = { Value = val, Name = name }

            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, -4, 0, 56)
            row.BackgroundColor3 = ROW
            row.BorderSizePixel = 0
            row.LayoutOrder = nextOrder()
            row.Parent = page
            corner(row, 10)

            local lbl = Instance.new("TextLabel")
            lbl.BackgroundTransparency = 1
            lbl.Position = UDim2.new(0, 12, 0, 4)
            lbl.Size = UDim2.new(0.7, 0, 0, 18)
            lbl.Font = Enum.Font.GothamMedium
            lbl.TextSize = 13
            lbl.TextColor3 = TEXT
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Text = name
            lbl.Parent = row

            local valLbl = Instance.new("TextLabel")
            valLbl.BackgroundTransparency = 1
            valLbl.Position = UDim2.new(1, -60, 0, 4)
            valLbl.Size = UDim2.new(0, 50, 0, 18)
            valLbl.Font = Enum.Font.Gotham
            valLbl.TextSize = 12
            valLbl.TextColor3 = CYAN
            valLbl.TextXAlignment = Enum.TextXAlignment.Right
            valLbl.Text = tostring(val)
            valLbl.Parent = row

            local bar = Instance.new("Frame")
            bar.Size = UDim2.new(1, -24, 0, 6)
            bar.Position = UDim2.new(0, 12, 1, -18)
            bar.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
            bar.BorderSizePixel = 0
            bar.Parent = row
            corner(bar, 3)

            local fill = Instance.new("Frame")
            fill.Size = UDim2.new(math.clamp((val - min) / math.max(max - min, 1e-6), 0, 1), 0, 1, 0)
            fill.BackgroundColor3 = ACCENT_HOT
            fill.BorderSizePixel = 0
            fill.Parent = bar
            corner(fill, 3)

            local sliding = false
            local function setFromX(x)
                local rel = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
                local v = min + rel * (max - min)
                local inc = o.Increment or 0.1
                v = math.floor(v / inc + 0.5) * inc
                v = math.clamp(v, min, max)
                flag.Value = v
                fill.Size = UDim2.new(rel, 0, 1, 0)
                valLbl.Text = (inc >= 1) and tostring(math.floor(v)) or string.format("%.2f", v)
                if o.Callback then pcall(o.Callback, v) end
            end
            bar.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    sliding = true
                    setFromX(input.Position.X)
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    sliding = false
                end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    setFromX(input.Position.X)
                end
            end)
            return flag
        end

        function tab:CreateDropdown(o)
            o = o or {}
            local name = uniqueName(o.Name or "Dropdown")
            local options = o.Options or { "A" }
            local cur = o.Default or options[1]
            local flag = { Value = cur, Name = name }
            local row = select(1, makeRow(name))
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0, 110, 0, 26)
            btn.Position = UDim2.new(1, -122, 0.5, -13)
            btn.BackgroundColor3 = BG3
            btn.Text = tostring(cur)
            btn.TextColor3 = TEXT
            btn.TextSize = 12
            btn.Font = Enum.Font.Gotham
            btn.AutoButtonColor = false
            btn.Parent = row
            corner(btn, 8)
            local idx = 1
            for i, v in ipairs(options) do
                if v == cur then idx = i break end
            end
            btn.MouseButton1Click:Connect(function()
                idx = idx % #options + 1
                flag.Value = options[idx]
                btn.Text = tostring(flag.Value)
                if o.Callback then pcall(o.Callback, flag.Value) end
            end)
            return flag
        end

        function tab:CreateKeybind(o)
            o = o or {}
            local name = uniqueName(o.Name or "Keybind")
            local flag = { Value = o.Default, Name = name }
            local row = select(1, makeRow(name))
            local chip = Instance.new("TextButton")
            chip.Size = UDim2.new(0, 90, 0, 26)
            chip.Position = UDim2.new(1, -102, 0.5, -13)
            chip.BackgroundColor3 = BG3
            chip.Text = (flag.Value and flag.Value.Name) or "None"
            chip.TextColor3 = TEXT
            chip.TextSize = 11
            chip.Font = Enum.Font.GothamBold
            chip.AutoButtonColor = false
            chip.Parent = row
            corner(chip, 8)
            local listening = false
            chip.MouseButton1Click:Connect(function()
                listening = true
                chip.Text = "..."
                chip.BackgroundColor3 = ACCENT
            end)
            local conn
            conn = UserInputService.InputBegan:Connect(function(input, gpe)
                if not listening then return end
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    flag.Value = input.KeyCode
                    chip.Text = input.KeyCode.Name
                    chip.BackgroundColor3 = BG3
                    listening = false
                    if o.Callback then pcall(o.Callback, flag.Value) end
                end
            end)
            return flag
        end

        function tab:CreateButton(o)
            o = o or {}
            local name = uniqueName(o.Name or "Button")
            local row = Instance.new("TextButton")
            row.Size = UDim2.new(1, -4, 0, 36)
            row.BackgroundColor3 = ACCENT
            row.BackgroundTransparency = 0.82
            row.Text = name
            row.TextColor3 = ACCENT
            row.TextSize = 13
            row.Font = Enum.Font.GothamBold
            row.AutoButtonColor = true
            row.LayoutOrder = nextOrder()
            row.Parent = page
            corner(row, 10)
            row.MouseButton1Click:Connect(function()
                if o.Callback then pcall(o.Callback) end
            end)
            return { Name = name, Callback = o.Callback, Fire = function() if o.Callback then pcall(o.Callback) end end }
        end

        function tab:CreateDivider()
            local d = Instance.new("Frame")
            d.Size = UDim2.new(1, -4, 0, 1)
            d.BackgroundColor3 = STROKE
            d.BackgroundTransparency = 0.5
            d.BorderSizePixel = 0
            d.LayoutOrder = nextOrder()
            d.Parent = page
        end

        function tab:CreateSection(_) return tab end
        function tab:CreateInput(o)
            o = o or {}
            local name = uniqueName(o.Name or "Input")
            local flag = { Value = o.Default or "", Name = name }
            local row = select(1, makeRow(name))
            local box = Instance.new("TextBox")
            box.Size = UDim2.new(0, 120, 0, 26)
            box.Position = UDim2.new(1, -132, 0.5, -13)
            box.BackgroundColor3 = BG3
            box.Text = tostring(flag.Value)
            box.TextColor3 = TEXT
            box.TextSize = 12
            box.Font = Enum.Font.Gotham
            box.ClearTextOnFocus = false
            box.Parent = row
            corner(box, 8)
            box.FocusLost:Connect(function()
                flag.Value = box.Text
                if o.Callback then pcall(o.Callback, flag.Value) end
            end)
            return flag
        end
        function tab:CreateParagraph(_) end
        function tab:CreateLabel(_) end
        return tab
    end

    self.UISettings = self:CreateTab({ Name = "Settings", Icon = "rbxassetid://6031280882" })
    self.Configs = self:CreateTab({ Name = "Configs", Icon = "rbxassetid://6031225988" })
    function self:UpdateScale() end
    return self
end

local YuriLib = {
    Flags = {},
    Notify = function(...) end,
    ShowNotifications = false,
    ShowTooltips = false,
}


-- ========== Nexonix structure + glass theme (Claude palette) ==========
local Window
local uiOk, uiErr = true, nil
local function applyGlassTheme(Lib)
    if not Lib or not Lib.Theme then return end
    -- Claude glass palette on Nexonix tokens
    Lib.Theme["Background"] = Color3.fromRGB(28, 32, 40)
    Lib.Theme["Inline"] = Color3.fromRGB(32, 36, 46)
    Lib.Theme["Accent"] = Color3.fromRGB(79, 147, 238)
    Lib.Theme["Tab"] = Color3.fromRGB(36, 40, 50)
    Lib.Theme["Dark Icon"] = Color3.fromRGB(100, 110, 130)
    Lib.Theme["Element"] = Color3.fromRGB(40, 44, 54)
    Lib.Theme["Liner"] = Color3.fromRGB(48, 54, 66)
    Lib.Theme["Outline"] = Color3.fromRGB(60, 70, 90)
    Lib.Theme["Dark Text"] = Color3.fromRGB(143, 152, 170)
    Lib.Theme["Text"] = Color3.fromRGB(233, 237, 245)
    Lib.Theme["Toggle"] = Color3.fromRGB(48, 54, 66)
    Lib.Theme["Hovered Element"] = Color3.fromRGB(48, 54, 66)
end

local function loadNexonix()
    local urls = {
        "https://raw.githubusercontent.com/sametexe001/sametlibs/refs/heads/main/nexonix/Library.lua",
        "https://raw.githubusercontent.com/sametexe001/sametlibs/main/nexonix/Library.lua",
    }
    for _, url in ipairs(urls) do
        local ok, src = pcall(function() return game:HttpGet(url) end)
        if ok and type(src) == "string" and #src > 1000 then
            local fn, err = loadstring(src)
            if not fn then fn, err = load(src) end
            if fn then
                local ok2, lib = pcall(fn)
                if ok2 and type(lib) == "table" and (lib.Window or lib.Flags) then
                    return lib
                end
            end
        end
    end
    return nil
end

local function makeValueProxy(default, onSet)
    local proxy = { Value = default }
    local mt = {
        __newindex = function(t, k, v)
            if k == "Value" then
                rawset(t, "Value", v)
                if onSet then pcall(onSet, v) end
            else
                rawset(t, k, v)
            end
        end,
    }
    return setmetatable(proxy, mt)
end

local function adaptNexonix(NX)
    applyGlassTheme(NX)
    local rawWin = NX:Window({ Logo = "rbxassetid://0" })
    local pageIcons = {
        ["QB Aimbot"] = "rbxassetid://6034684949",
        ["Catching"] = "rbxassetid://6034227067",
        ["Player"] = "rbxassetid://6034287594",
        ["Physics"] = "rbxassetid://6031225988",
        ["Visual"] = "rbxassetid://6031280882",
        ["Automatics"] = "rbxassetid://6031068421",
        ["Misc"] = "rbxassetid://6031280882",
        ["Settings"] = "rbxassetid://6031280882",
        ["Configs"] = "rbxassetid://6031225988",
    }
    local adapted = { Gui = nil, _raw = rawWin, _pages = {} }
    pcall(function()
        if NX and getgenv and getgenv().Library then
            -- try find screen gui
        end
    end)
    function adapted:CreateTab(opts)
        opts = opts or {}
        local name = opts.Name or "Tab"
        local page = rawWin:Page({ Icon = opts.Icon or pageIcons[name] or "rbxassetid://6031280882", Name = name })
        -- Nexonix pages often use icon-only; set name if supported
        pcall(function() if page.SetName then page:SetName(name) end end)
        local secL, secR
        local function left()
            if not secL then secL = page:Section({ Name = name, Side = 1 }) end
            return secL
        end
        local function right()
            if not secR then secR = page:Section({ Name = name .. " ", Side = 2 }) end
            return secR
        end
        local tab = { _page = page, Name = name }
        function tab:CreateToggle(o)
            o = o or {}
            local proxy = { Value = o.Default == true }
            local sec = left()
            local obj = sec:Toggle({
                Name = o.Name or "Toggle",
                Flag = (o.Name or "Toggle") .. tostring(math.random(1,1e9)),
                Default = proxy.Value,
                Tooltip = o.Tip or o.Tooltip or "",
                Callback = function(v)
                    proxy.Value = v
                    if o.Callback then pcall(o.Callback, v) end
                end,
            })
            return proxy
        end
        function tab:CreateSlider(o)
            o = o or {}
            local proxy = { Value = o.Default or o.Min or 0 }
            left():Slider({
                Name = o.Name or "Slider",
                Flag = (o.Name or "Slider") .. tostring(math.random(1,1e9)),
                Min = o.Min or 0,
                Max = o.Max or 100,
                Default = proxy.Value,
                Decimals = (o.Increment and o.Increment < 1) and 2 or 0,
                Suffix = o.Suffix or "",
                Tooltip = o.Tip or "",
                Callback = function(v)
                    proxy.Value = v
                    if o.Callback then pcall(o.Callback, v) end
                end,
            })
            return proxy
        end
        function tab:CreateDropdown(o)
            o = o or {}
            local proxy = { Value = o.Default or (o.Options and o.Options[1]) or "" }
            left():Dropdown({
                Name = o.Name or "Dropdown",
                Flag = (o.Name or "Dropdown") .. tostring(math.random(1,1e9)),
                Default = proxy.Value,
                Items = o.Options or o.Items or {},
                Tooltip = o.Tip or "",
                Callback = function(v)
                    proxy.Value = v
                    if o.Callback then pcall(o.Callback, v) end
                end,
            })
            return proxy
        end
        function tab:CreateKeybind(o)
            o = o or {}
            local proxy = { Value = o.Default or Enum.KeyCode.Unknown }
            -- Nexonix keybind may differ; store default and optional callback
            pcall(function()
                if left().Keybind then
                    left():Keybind({
                        Name = o.Name or "Keybind",
                        Flag = (o.Name or "Key") .. tostring(math.random(1,1e9)),
                        Default = proxy.Value,
                        Callback = function(v)
                            proxy.Value = v
                        end,
                    })
                end
            end)
            return proxy
        end
        function tab:CreateButton(o)
            o = o or {}
            left():Button({
                Name = o.Name or "Button",
                Tooltip = o.Tip or "",
                Callback = function()
                    if o.Callback then pcall(o.Callback) end
                end,
            })
            return {}
        end
        function tab:CreateDivider(o)
            pcall(function()
                if left().Label then
                    left():Label({ Name = (o and o.Name) or "—" })
                end
            end)
            return {}
        end
        function tab:CreateInput(o)
            o = o or {}
            local proxy = { Value = o.Default or "" }
            pcall(function()
                if left().Textbox or left().TextBox then
                    local f = left().Textbox or left().TextBox
                    f(left(), {
                        Name = o.Name or "Input",
                        Default = proxy.Value,
                        Callback = function(v) proxy.Value = v end,
                    })
                end
            end)
            return proxy
        end
        return tab
    end
    function adapted:UpdateScale() end
    return adapted
end

print('[Yuri] loading UI...')
local NX = nil
uiOk, uiErr = pcall(function()
    NX = loadNexonix()
    if NX then
        print('[Yuri] Nexonix loaded (glass theme)')
        Window = adaptNexonix(NX)
    else
        error('nexonix download failed')
    end
end)
if not uiOk or not Window then
    warn('[Yuri] Nexonix failed, falling back to YuriUI:', uiErr)
    print('[Yuri] Nexonix failed, fallback YuriUI:', uiErr)
    uiOk, uiErr = pcall(function()
        Window = YuriUI:CreateWindow({ Title = "FF3", Prefix = "Yuri" })
    end)
end
if not uiOk or not Window then
    warn('[Yuri] UI failed:', uiErr)
    print('[Yuri] UI failed:', uiErr)
    return
end
print('[Yuri] UI ready')

yuriOnUnload(function()
    pcall(function() if Window and Window.Gui then Window.Gui:Destroy() end end)
    pcall(function() if YuriUI and YuriUI._lastGui then YuriUI._lastGui:Destroy() end end)
end)


print('[Yuri] building tabs...')
local ThrowingTab = Window:CreateTab({ Name = 'QB Aimbot', Icon = 'rbxassetid://6034684949' })

enableQbAimbot = ThrowingTab:CreateToggle({
    Name = 'Enable QB Aimbot',
    Default = false,
    Tip = 'QBA V2: lower-latency lock, velocity lead prediction, route-aware trajectory.',
})

aimMode = ThrowingTab:CreateDropdown({
    Name = 'Aim Mode',
    Options = {'Target', 'Mouse', 'Camera'},
    Default = 'Target',
    Tip = 'Where QBA aims: locked receiver, mouse ray, or camera look.',
})

autoThrow = ThrowingTab:CreateToggle({
    Name = 'Auto Throw',
    Default = false,
    Tip = 'Releases throw when QBA has a solid target and you hold the ball.',
})

autoThrowDelay = ThrowingTab:CreateSlider({
    Name = 'Auto Throw Delay',
    Min = 0.05,
    Max = 1.5,
    Default = 0.35,
    Increment = 0.05,
    Tip = 'Wait after lock before auto-throwing.',
})


throwAimbot = ThrowingTab:CreateToggle({
    Name = 'Mouse Aimbot',
    Default = false,
    Tip = 'Throws land where your mouse points (full kinematics, not preview only).',
})

mouseThrowArc = ThrowingTab:CreateDropdown({
    Name = 'Mouse Throw Arc',
    Options = {'Auto', 'Low', 'High'},
    Default = 'Auto',
    Tip = 'Low = flatter bullet; High = lob; Auto = solver pick.',
})

throwLineViz = ThrowingTab:CreateToggle({
    Name = 'Throw Line Visualiser',
    Default = true,
    Tip = 'Shows the QBA / mouse throw beam (Relay-style throw line).',
})


autoChooseWr = ThrowingTab:CreateToggle({
    Name = 'Auto Choose Open Reciever',
    Default = false,
    Tip = 'Automatically selects the most open receiver for each throw.',
})

autoSelectThrowMode = ThrowingTab:CreateToggle({
    Name = 'Auto Select Throw Type',
    Default = false,
    Tip = 'Auto picks mode. OFF = you choose with Forced Pass Mode / keybinds / cycle.',
})

forcedPassMode = ThrowingTab:CreateDropdown({
    Name = 'Forced Pass Mode',
    Options = {'Bullet', 'Dime', 'Mag', 'Dive', 'Jump', 'Angle'},
    Default = 'Bullet',
    Tip = 'Used when Auto Select is OFF. Angle = high-arc Dime-style.',
})

lockPassMode = ThrowingTab:CreateToggle({
    Name = 'Lock Pass Mode',
    Default = false,
    Tip = 'Ignores Auto Select and always uses Forced Pass Mode.',
})

autoPower = ThrowingTab:CreateToggle({
    Name = 'Auto Power',
    Default = false,
    Tip = 'Automatically sets the optimal throw power.',
})

autoAngle = ThrowingTab:CreateToggle({
    Name = 'Auto Angle',
    Default = false,
    Tip = 'Automatically adjusts throw angle for better accuracy.',
})

-- Cons-style SmartFit retouch: distance curve for auto power / angle
smartFit = ThrowingTab:CreateToggle({
    Name = 'SmartFit',
    Default = false,
    Tip = 'V2: defender distance + coverage geometry; tunes power/arc for tight windows.',
})

smartFitAggression = ThrowingTab:CreateSlider({
    Name = 'SmartFit Strength',
    Min = 0.5,
    Max = 1.5,
    Default = 1.0,
    Increment = 0.05,
    Tip = 'How hard SmartFit pushes power/angle toward the distance curve.',
})

smartFitLock = ThrowingTab:CreateToggle({
    Name = 'SmartFit Lock',
    Default = false,
    Tip = 'Keeps SmartFit on the same receiver until throw or they drop open status.',
})
fadeLead = ThrowingTab:CreateSlider({
    Name = 'Fade Lead',
    Min = -10,
    Max = 25,
    Default = 6,
    Increment = 0.5,
    Tip = 'Extra lead on fade / go routes.',
})
catchHeightLead = ThrowingTab:CreateSlider({
    Name = 'Catch Height',
    Min = 0,
    Max = 12,
    Default = 3,
    Increment = 0.5,
    Tip = 'Raises aim point for jump/high-point catches.',
})
wrHorizReach = ThrowingTab:CreateSlider({
    Name = 'WR Horizontal Reach',
    Min = 0,
    Max = 8,
    Default = 2,
    Increment = 0.25,
    Tip = 'Extra lead along the receiver move direction.',
})
wrVertReach = ThrowingTab:CreateSlider({
    Name = 'WR Vertical Reach',
    Min = 0,
    Max = 8,
    Default = 2,
    Increment = 0.25,
    Tip = 'Raises the aim point for high-point catches.',
})
dbHorizReach = ThrowingTab:CreateSlider({
    Name = 'DB Horizontal Reach',
    Min = 0,
    Max = 8,
    Default = 2,
    Increment = 0.25,
    Tip = 'Pushes the lead away from nearby defenders.',
})
dbVertReach = ThrowingTab:CreateSlider({
    Name = 'DB Vertical Reach',
    Min = 0,
    Max = 8,
    Default = 1.5,
    Increment = 0.25,
    Tip = 'Vertical bias when a DB is under the throw.',
})
wrReaction = ThrowingTab:CreateSlider({
    Name = 'WR Reaction Time',
    Min = 0,
    Max = 0.6,
    Default = 0.12,
    Increment = 0.02,
    Tip = 'Predicts how long the WR needs to react to the ball.',
})
dbReaction = ThrowingTab:CreateSlider({
    Name = 'DB Reaction Time',
    Min = 0,
    Max = 0.6,
    Default = 0.15,
    Increment = 0.02,
    Tip = 'How early the aim accounts for a closing DB.',
})
ignoreDefenders = ThrowingTab:CreateToggle({
    Name = 'Ignore Defenders (SmartFit)',
    Default = false,
    Tip = 'SmartFit ignores DB pressure when fitting power/angle.',
})
boundsTolerance = ThrowingTab:CreateSlider({
    Name = 'Bounds Tolerance',
    Min = 0,
    Max = 20,
    Default = 5,
    Increment = 0.5,
    Tip = 'Extra field edge padding with Anti OOB.',
})



highPowerOnly = ThrowingTab:CreateToggle({
    Name = 'High Power Only',
    Default = false,
    Tip = 'Only uses high-power throws when passing.',
})

-- Arcane-style FF3 controls
pingCompensation = ThrowingTab:CreateToggle({
    Name = 'Ping Compensation',
    Default = false,
    Tip = 'Adds lead based on your ping so throws arrive on time.',
})

laneCheck = ThrowingTab:CreateToggle({
    Name = 'Lane Check',
    Default = false,
    Tip = 'Warns / adjusts when defenders sit under the flight path.',
})

always95Power = ThrowingTab:CreateToggle({
    Name = 'Always 95 Power',
    Default = false,
    Tip = 'Forces power near 95 on throws when Auto Power is on.',
})

ignoreDefenders = ThrowingTab:CreateToggle({
    Name = 'Ignore Defenders',
    Default = false,
    Tip = 'Does not cancel throw when a defender could contest.',
})

tToThrow = ThrowingTab:CreateToggle({
    Name = 'T To Throw',
    Default = false,
    Tip = 'Press T to throw while QBA is active (keeps mouse free).',
})

leadMultiplier = ThrowingTab:CreateSlider({
    Name = 'Lead Multiplier',
    Min = 0.5,
    Max = 1.5,
    Default = 1.0,
    Increment = 0.05,
    Tip = 'Scales all mode leads.',
})

safetyMargin = ThrowingTab:CreateSlider({
    Name = 'Safety Margin',
    Min = 0,
    Max = 15,
    Default = 5,
    Increment = 0.5,
    Tip = 'Extra inset for Anti OOB / bounds tolerance.',
})


task.spawn(function()
    local lastThrow = 0
    while true do
        task.wait(0.08)
        if not autoThrow or not autoThrow.Value then continue end
        if not enableQbAimbot or not enableQbAimbot.Value then continue end
        local char = lp.Character
        if not char or not char:FindFirstChild('Football') then continue end
        if not target then continue end
        local now = tick()
        local delay = (autoThrowDelay and tonumber(autoThrowDelay.Value)) or 0.35
        if now - lastThrow < delay then continue end
        lastThrow = now
        -- try common throw remotes used across hubs
        yuriFire('Game', 'Throw')
        yuriFire('PlayerActions', 'throw')
        yuriFire('PlayerActions', 'Throw')
        pcall(function()
            local vu = game:GetService('VirtualInputManager')
            -- no synthetic key by default; remote only
        end)
    end
end)

forceThrow = ThrowingTab:CreateToggle({
    Name = 'Force Throw',
    Default = false,
    Tip = 'Pushes power toward a strong window when throwing.',
})
perfectThrow = ThrowingTab:CreateToggle({
    Name = 'Perfect Throw',
    Default = false,
    Tip = 'Locks power near 95 when QBA is calculating.',
})




antiDB = ThrowingTab:CreateToggle({
    Name = 'Anti DB',
    Default = false,
    Tip = 'Avoids throws that defenders can easily intercept.',
})

antiDBThreshold = ThrowingTab:CreateSlider({
    Name = 'Anti DB Threshold',
    Min = 0,
    Max = 15,
    Default = 4,
    Increment = 0.1,
    Suffix = '',
    Tip = 'Sets how aggressively defender coverage is avoided.',
})

antiOOB = ThrowingTab:CreateToggle({
    Name = 'Anti OOB',
    Default = false,
    Tip = 'V2: live field bounds; pulls lead back inside when routes drift near sidelines.',
})

antiOOBThreshold = ThrowingTab:CreateSlider({
    Name = 'Anti OOB Threshold',
    Min = 0,
    Max = 15,
    Default = 5,
    Increment = 0.1,
    Suffix = '',
    Tip = 'Sets how close targets can be to the sideline.',
})

throwLeadOffset = ThrowingTab:CreateSlider({
    Name = 'Throw Lead Offset',
    Min = -10,
    Max = 10,
    Default = 2,
    Increment = 0.1,
    Suffix = '',
    Tip = 'Adjusts how far ahead passes are led.',
})

throwHeightOffset = ThrowingTab:CreateSlider({
    Name = 'Throw Height Offset',
    Min = -10,
    Max = 10,
    Default = 1,
    Increment = 0.1,
    Suffix = '',
    Tip = 'Adjusts the height of targeted throws.',
})

autoJuke = ThrowingTab:CreateToggle({
    Name = 'Auto Juke Rusher',
    Default = false,
    Tip = 'Automatically jukes nearby rushers before throwing.',
})

hideCards = ThrowingTab:CreateToggle({
    Name = 'Hide QB Aimbot Cards',
    Default = false,
    Tip = 'Hides QB Aimbot visual cards from the screen.',
})

autoChangePowerUI = ThrowingTab:CreateToggle({
    Name = 'Auto Change Power UI',
    Default = false,
    Tip = 'Automatically updates the power UI to match throws.',
})

autoJumpWhenThrow = ThrowingTab:CreateToggle({
    Name = 'Auto Jump Before Throw',
    Default = false,
    Tip = 'Automatically jumps before releasing the ball.',
})


autoHike = ThrowingTab:CreateToggle({
    Name = 'Auto Hike',
    Default = false,
    Tip = 'Attempts hike when PrePlay and you are QB with BallGui.',
})

task.spawn(function()
    while true do
        task.wait(0.2)
        if not autoHike.Value then continue end
        local flags = replicatedStorage:FindFirstChild('Flags')
        local status = flags and flags:FindFirstChild('Status')
        if not status or status.Value ~= 'PrePlay' then continue end
        local pg = player:FindFirstChild('PlayerGui')
        local ballGui = pg and pg:FindFirstChild('BallGui')
        if not ballGui then continue end
        pcall(function()
            local rem = replicatedStorage:FindFirstChild('Remotes')
            if rem and rem:FindFirstChild('CharacterSoundEvent') then
                rem.CharacterSoundEvent:FireServer('Game', 'Hike')
            end
        end)
    end
end)


autoThrowAfterSack = ThrowingTab:CreateToggle({
    Name = 'Auto Throw Before Getting Sacked',
    Default = false,
    Tip = 'Automatically throws the ball when a sack is imminent.',
})

dimeKeybind = ThrowingTab:CreateKeybind({
    Name = 'Dime Mode Keybind',
    Default = Enum.KeyCode.One,
    Tip = 'Switches to Dime throw mode.',
})

magKeybind = ThrowingTab:CreateKeybind({
    Name = 'Mag Mode Keybind',
    Default = Enum.KeyCode.Two,
    Tip = 'Switches to Mag throw mode.',
})

diveKeybind = ThrowingTab:CreateKeybind({
    Name = 'Dive Mode Keybind',
    Default = Enum.KeyCode.Three,
    Tip = 'Switches to Dive throw mode.',
})

jumpKeybind = ThrowingTab:CreateKeybind({
    Name = 'Jump Mode Keybind',
    Default = Enum.KeyCode.Four,
    Tip = 'Switches to Jump throw mode.',
})

bulletKeybind = ThrowingTab:CreateKeybind({
    Name = 'Bullet Mode Keybind',
    Default = Enum.KeyCode.Five,
    Tip = 'Switches to Bullet throw mode.',
})

throwBallAwayKeybind = ThrowingTab:CreateKeybind({
    Name = 'Throw Ball Away Keybind',
    Default = Enum.KeyCode.T,
    Tip = 'Instantly throws the ball away.',
})

increaseAngleKeybind = ThrowingTab:CreateKeybind({
    Name = 'Increase Angle Keybind',
    Default = Enum.KeyCode.R,
    Tip = 'Increases the current throw angle.',
})

decreaseAngleKeybind = ThrowingTab:CreateKeybind({
    Name = 'Decrease Angle Keybind',
    Default = Enum.KeyCode.F,
    Tip = 'Decreases the current throw angle.',
})

lockKeybind = ThrowingTab:CreateKeybind({
    Name = 'Lock To Target Keybind',
    Default = Enum.KeyCode.Y,
    Tip = 'Locks passes onto the current target.',
})

cycleModeKeybind = ThrowingTab:CreateKeybind({
    Name = 'Cycle Pass Mode Keybind',
    Default = Enum.KeyCode.Q,
    Tip = 'Cycles Dime / Mag / Dive / Jump / Bullet.',
})


local players = Players
local replicatedStorage = game:GetService('ReplicatedStorage')
local tweenService = TweenService
local userInputService = UserInputService
local runService = RunService
local stats = game:GetService('Stats')
local camera = workspace.CurrentCamera
local firetouchinterest = firetouchinterest
pcall(function()
    if type(firetouchinterest) ~= 'function' and getfenv then
        local e = getfenv()
        if type(e) == 'table' and type(e.firetouchinterest) == 'function' then
            firetouchinterest = e.firetouchinterest
        end
    end
    if type(firetouchinterest) ~= 'function' and getgenv then
        local e = getgenv()
        if type(e) == 'table' and type(e.firetouchinterest) == 'function' then
            firetouchinterest = e.firetouchinterest
        end
    end
end)

-- lp already defined at top
if not lp then
    local t0 = os.clock()
    while not players.LocalPlayer and os.clock()-t0 < 8 do
        task.wait(0.1)
    end
    lp = players.LocalPlayer
end
if not lp then
    warn('[Yuri] LocalPlayer lost')
    return
end
local mouse = lp:GetMouse()
player = lp
lp = lp

local function yuriFire(category, action)
    return pcall(function()
        local rem = replicatedStorage:FindFirstChild('Remotes') or replicatedStorage:FindFirstChild('Remote')
        if not rem then return end
        local names = {'CharacterSoundEvent', 'CharacterEvent', 'PlayerEvent', 'ActionEvent'}
        for _, n in ipairs(names) do
            local ev = rem:FindFirstChild(n)
            if ev and ev:IsA('RemoteEvent') then
                pcall(function() ev:FireServer(category, action) end)
            end
        end
        -- also try direct children on RS
        for _, ch in ipairs(replicatedStorage:GetChildren()) do
            if ch:IsA('RemoteEvent') and (ch.Name:lower():find('sound') or ch.Name:lower():find('action') or ch.Name:lower():find('char')) then
                pcall(function() ch:FireServer(category, action) end)
            end
        end
    end)
end



local isPractice = (game.PlaceId == 81310542478972)
if isPractice then
    autoJuke.Value = false
end

local targetLocked = false
local lockedTarget = nil

-- QBA Target Lock (Middle Mouse) - Yuna-style
userInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton3 then return end
    if not enableQbAimbot or not enableQbAimbot.Value then return end
    -- toggle lock on current target under mouse / closest receiver
    if targetLocked and lockedTarget then
        targetLocked = false
        lockedTarget = nil
        return
    end
    local cam = workspace.CurrentCamera
    local mouse = player:GetMouse()
    local best, bestD = nil, 40
    for _, pl in ipairs(game:GetService('Players'):GetPlayers()) do
        if pl == player then continue end
        if player.Team and pl.Team and pl.Team == player.Team then continue end
        local ch = pl.Character
        local hrp = ch and ch:FindFirstChild('HumanoidRootPart')
        if not hrp then continue end
        local sp, on = cam:WorldToViewportPoint(hrp.Position)
        if not on then continue end
        local d = (Vector2.new(sp.X, sp.Y) - Vector2.new(mouse.X, mouse.Y)).Magnitude
        if d < bestD then bestD, best = d, pl end
    end
    if best then
        targetLocked = true
        lockedTarget = best
    end
end)



local RouteData = {}
local HUDCards = {}
local rusherHighlights = {}
local numCards = 0

local leadDime = 8.5
local leadMag = 8.6
local leadDive = 8.5
local leadJump = 8.4
local leadBullet = 2.5 

local yLeadDime = 1.2
local yLeadMag = 1.0
local yLeadDive = 1.5
local yLeadJump = 2.0
local yLeadBullet = -0.8

local ModeOrder = {'Bullet', 'Dime', 'Dive', 'Jump', 'Mag'}

-- QBA V2.0: SmartFit with coverage geometry + trajectory tuning
function applySmartFit(dist, basePower, baseAngle, nearestDB)
    if not smartFit or not smartFit.Value then
        return basePower, baseAngle
    end
    dist = tonumber(dist) or 30
    basePower = tonumber(basePower) or 60
    baseAngle = tonumber(baseAngle) or 22
    nearestDB = tonumber(nearestDB) or 99
    local ag = (smartFitAggression and tonumber(smartFitAggression.Value)) or 1

    -- route-distance curve (trajectory physics)
    local targetPow, targetAng
    if dist < 12 then
        targetPow = 36 + dist * 1.15
        targetAng = 32 - dist * 0.4
    elseif dist < 28 then
        targetPow = 50 + (dist - 12) * 0.9
        targetAng = 27 - (dist - 12) * 0.28
    elseif dist < 50 then
        targetPow = 65 + (dist - 28) * 0.5
        targetAng = 22 - (dist - 28) * 0.2
    else
        targetPow = 78 + math.min((dist - 50) * 0.28, 14)
        targetAng = 15 - math.min((dist - 50) * 0.05, 4)
    end

    -- coverage geometry: tight window -> higher arc / slightly less power (fit over DB)
    if nearestDB < 3.5 then
        targetAng = targetAng + 6
        targetPow = targetPow - 4
    elseif nearestDB < 6 then
        targetAng = targetAng + 3.5
        targetPow = targetPow - 2
    elseif nearestDB < 10 then
        targetAng = targetAng + 1.5
    elseif nearestDB > 18 then
        -- wide open: flatter, drive the ball
        targetAng = targetAng - 2
        targetPow = targetPow + 3
    end

    targetPow = math.clamp(targetPow, 34, 94)
    targetAng = math.clamp(targetAng, 9, 38)

    local blend = math.clamp(0.4 * ag, 0.18, 0.72)
    local p = basePower + (targetPow - basePower) * blend
    local a = baseAngle + (targetAng - baseAngle) * blend

    p = p + (math.random() - 0.5) * 1.8
    a = a + (math.random() - 0.5) * 0.9

    return math.clamp(p, 30, 96), math.clamp(a, 8, 40)
end

-- QBA V2: predictive lead from receiver velocity + ball flight time estimate
function yuriPredictLead(targetHrp, qbHrp, modeName, leadOffset)
    if not targetHrp or not qbHrp then
        return targetHrp and targetHrp.Position or Vector3.zero
    end
    local pos = targetHrp.Position
    local vel = targetHrp.AssemblyLinearVelocity
    local dist = (pos - qbHrp.Position).Magnitude
    -- rough flight time from distance (tuned for FF3 arcs)
    local flight = math.clamp(dist / 72, 0.12, 1.35)
    if modeName == 'Bullet' then
        flight = flight * 0.72
    elseif modeName == 'Jump' or modeName == 'Dive' then
        flight = flight * 1.08
    elseif modeName == 'Mag' then
        flight = flight * 0.95
    end
    local lead = pos + Vector3.new(vel.X, 0, vel.Z) * flight
    lead = lead + Vector3.new(vel.X, 0, vel.Z).Unit * (tonumber(leadOffset) or 0) * 0.35
    -- keep some height reference
    lead = Vector3.new(lead.X, pos.Y + (modeName == 'Jump' and 2.2 or 0.5), lead.Z)
    return lead
end

-- QBA V2: clamp predicted landing inside field (Anti-OOB)
function yuriClampInBounds(pos, margin)
    margin = tonumber(margin) or 5
    local halfW = 75 - margin
    local halfL = 170 - margin
    return Vector3.new(
        math.clamp(pos.X, -halfW, halfW),
        pos.Y,
        math.clamp(pos.Z, -halfL, halfL)
    )
end



local QBKeybinds = {
    [dimeKeybind.Value] = 'Dime',
    [magKeybind.Value] = 'Mag',
    [diveKeybind.Value] = 'Dive',
    [jumpKeybind.Value] = 'Jump',
    [bulletKeybind.Value] = 'Bullet'
}

local customHeight = { Value = 0 }

local target = nil
local lastCoverageDB = 99
local lastValidTarget = nil
local targetLeadPos = nil
local highlight = nil
local direction = Vector3.new(0, 1, 0)
local power = 60
local angle = 45
local airtime = 0
local isThrowing = false
local isThrowingAway = false
local firedRemote = false
local modeIndex = 1

-- cycle pass modes (BOLT-style, default Z)
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if not cycleModeKeybind or not cycleModeKeybind.Value then return end
    if input.KeyCode ~= cycleModeKeybind.Value then return end
    modeIndex = (modeIndex % #ModeOrder) + 1
end)

-- Controller / mobile: cycle pass mode (DPad + bumpers)
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    local k = input.KeyCode
    local cycleKeys = {
        [Enum.KeyCode.DPadLeft] = -1,
        [Enum.KeyCode.DPadRight] = 1,
        [Enum.KeyCode.ButtonL1] = -1,
        [Enum.KeyCode.ButtonR1] = 1,
        [Enum.KeyCode.ButtonL2] = -1,
        [Enum.KeyCode.ButtonR2] = 1,
    }
    local dir = cycleKeys[k]
    if not dir then return end
    if not enableQbAimbot or not enableQbAimbot.Value then return end
    modeIndex = modeIndex + dir
    if modeIndex < 1 then modeIndex = #ModeOrder end
    if modeIndex > #ModeOrder then modeIndex = 1 end
    if forcedPassMode then
        pcall(function() forcedPassMode.Value = ModeOrder[modeIndex] end)
    end
    print('[Yuri] Pass mode:', ModeOrder[modeIndex])
end)


local smoothedJukeDir = Vector3.zero

local lockedMousePos = nil

local LockToggleBtn = nil
local LockedLabel = nil

local attach0 = Instance.new('Attachment', workspace.Terrain)
local attach1 = Instance.new('Attachment', workspace.Terrain)

local beam = Instance.new('Beam')
beam.Attachment0 = attach0
beam.Attachment1 = attach1
beam.Segments = 7500
beam.Width0 = 1
beam.Width1 = 1
beam.FaceCamera = true
beam.Color = ColorSequence.new(Color3.fromRGB(255, 170, 40))
beam.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.01, 0),
    NumberSequenceKeypoint.new(1, 0)
})

-- T To Throw
userInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if not tToThrow or not tToThrow.Value then return end
    if input.KeyCode ~= Enum.KeyCode.T then return end
    if not enableQbAimbot or not enableQbAimbot.Value then return end
    local char = lp.Character
    if not char or not char:FindFirstChild('Football') then return end
    pcall(function()
        local vim = game:GetService('VirtualInputManager')
        -- fallback: click center
        if mouse and mouse.Click then
            -- no Click on mouse
        end
        -- fire common throw path via remote if present
        local rem = replicatedStorage:FindFirstChild('Remotes')
        if rem and rem:FindFirstChild('CharacterSoundEvent') then
            rem.CharacterSoundEvent:FireServer('Game', 'Throw')
        end
    end)
end)


-- Aikeo fix: beam never stays on when not aiming
beam.Enabled = false
beam.Parent = workspace.Terrain

local posPart = Instance.new('Part', workspace.Terrain)
posPart.Anchored = true
posPart.CanCollide = false
posPart.CastShadow = false
posPart.Size = Vector3.new(3, 3, 3)
posPart.Shape = Enum.PartType.Ball
posPart.Color = Color3.fromRGB(0, 0, 0)

local hudFolder = nil
pcall(function()
    hudFolder = (gethui and gethui()) or game:GetService('CoreGui')
end)
if not hudFolder or (hudFolder.Name == 'CoreGui' and not pcall(function() Instance.new('Folder', hudFolder):Destroy() end)) then
    hudFolder = lp:WaitForChild('PlayerGui', 10)
end

local sg = Instance.new('ScreenGui')
sg.ResetOnSpawn = false
sg.Parent = hudFolder
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local container = Instance.new('CanvasGroup')
container.Size = UDim2.new(1, 0, 0, 100)
container.Position = UDim2.new(0.5, 0, 0.05, 0)
container.AnchorPoint = Vector2.new(0.5, 0)
container.BackgroundTransparency = 1
container.GroupTransparency = 1
container.Visible = true
container.Parent = sg

local hudVisible = false
local updateHUDVisibility = function(show)
    if show and not hudVisible then
        hudVisible = true
        tweenService:Create(container, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {GroupTransparency = 0}):Play()
    elseif not show and hudVisible then
        hudVisible = false
        tweenService:Create(container, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {GroupTransparency = 1}):Play()
    end
end

local containerScale = Instance.new('UIScale', container)

local updateScale = function()
    local vp = camera.ViewportSize
    local scale = (vp.X / 1100)
    containerScale.Scale = math.clamp(scale, 0.5, 1.2)
end

camera:GetPropertyChangedSignal('ViewportSize'):Connect(updateScale)
updateScale()

local layout = Instance.new('UIListLayout')
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 10)
layout.Parent = container

local assignFont = function(instance, font)
    pcall(function()
        instance.Font = font
    end)
end

local createCard = function(titleTxt)
    -- Cons-style / live hub QBA cards: dark glass + amber value
    local card = Instance.new('Frame')
    card.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
    card.BackgroundTransparency = 0.12
    card.BorderSizePixel = 0
    
    local gradient = Instance.new('UIGradient')
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(36, 34, 32)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(22, 22, 26)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 14, 16))
    })
    gradient.Rotation = 90
    gradient.Parent = card
    
    if titleTxt == 'Throw Type' or titleTxt == 'Mode' or titleTxt == 'Route' then
        card.Size = UDim2.new(0, 108, 0, 72)
    else
        card.Size = UDim2.new(0, 92, 0, 72)
    end
    
    card.LayoutOrder = numCards
    card.Parent = container

    local corner = Instance.new('UICorner', card)
    corner.CornerRadius = UDim.new(0, 12)

    local stroke = Instance.new('UIStroke', card)
    stroke.Color = Color3.fromRGB(255, 150, 55)
    stroke.Thickness = 1
    stroke.Transparency = 0.55

    local padding = Instance.new('UIPadding', card)
    padding.PaddingTop = UDim.new(0, 6)
    padding.PaddingBottom = UDim.new(0, 4)

    local title = Instance.new('TextLabel')
    title.BackgroundTransparency = 1
    title.BorderSizePixel = 0
    title.Position = UDim2.new(0, 0, 0.68, 0)
    title.Size = UDim2.new(1, 0, 0, 16)
    assignFont(title, Enum.Font.GothamMedium)
    title.Text = titleTxt
    title.TextColor3 = Color3.fromRGB(160, 160, 168)
    title.TextScaled = true
    title.Parent = card

    local valBtn = Instance.new('TextButton')
    valBtn.BackgroundTransparency = 1
    valBtn.BorderSizePixel = 0
    valBtn.Position = UDim2.new(0, 0, 0.08, 0)
    valBtn.Size = UDim2.new(1, 0, 0.55, 0)
    assignFont(valBtn, Enum.Font.GothamBold)
    valBtn.Text = '-'
    valBtn.TextColor3 = Color3.fromRGB(255, 170, 70)
    valBtn.TextScaled = true
    valBtn.AutoButtonColor = false
    valBtn.Parent = card

    if titleTxt == 'Throw Type' then
        local uiScale = Instance.new('UIScale', card)
        valBtn.MouseButton1Down:Connect(function()
            local c = lp.Character
            if not c or not c:FindFirstChild('Football') then return end
            tweenService:Create(uiScale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.9}):Play()
        end)
        valBtn.MouseButton1Up:Connect(function()
            local c = lp.Character
            if not c or not c:FindFirstChild('Football') then return end
            tweenService:Create(uiScale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1}):Play()
            modeIndex = modeIndex + 1
            if modeIndex > #ModeOrder then modeIndex = 1 end
        end)
    end

    if titleTxt == 'Player' then
        local lockedLbl = Instance.new('TextLabel')
        lockedLbl.Size = UDim2.new(1, 0, 0.25, 0)
        lockedLbl.Position = UDim2.new(0, 0, 0.05, 0)
        lockedLbl.BackgroundTransparency = 1
        lockedLbl.Text = 'LOCKED'
        lockedLbl.TextColor3 = Color3.fromRGB(255, 50, 50)
        assignFont(lockedLbl, Enum.Font.GothamBold)
        lockedLbl.TextSize = 12
        lockedLbl.Visible = false
        lockedLbl.ZIndex = 2
        lockedLbl.Parent = card

        LockedLabel = lockedLbl

        local lockOverlay = Instance.new('TextButton')
        lockOverlay.Size = UDim2.new(1, 0, 1, 0)
        lockOverlay.BackgroundTransparency = 1
        lockOverlay.Text = ''
        lockOverlay.ZIndex = 5
        lockOverlay.Parent = card

        lockOverlay.MouseButton1Click:Connect(function()
            local c = lp.Character
            if not c or not c:FindFirstChild('Football') then return end
            if target or targetLocked then
                targetLocked = not targetLocked
                if targetLocked then
                    lockedTarget = target
                    if LockedLabel then LockedLabel.Visible = true end
                else
                    lockedTarget = nil
                    if LockedLabel then LockedLabel.Visible = false end
                end
            end
        end)
        
        LockToggleBtn = valBtn
    end

    HUDCards[titleTxt] = valBtn
    numCards = numCards + 1
end


createCard('Angle')
createCard('Throw Type')
createCard('Player')
createCard('Airtime')
createCard('Power')

-- Throw status % (Catchable / Interceptable / Incomplete / Assistable) - midfield style
local statusGui = Instance.new('ScreenGui')
statusGui.Name = 'ThrowStatus'
statusGui.ResetOnSpawn = false
statusGui.IgnoreGuiInset = true
statusGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
statusGui.Parent = hudFolder

local statusFrame = Instance.new('Frame')
statusFrame.Name = 'Status'
statusFrame.BackgroundTransparency = 1
statusFrame.Size = UDim2.new(0, 280, 0, 90)
statusFrame.AnchorPoint = Vector2.new(0.5, 0)
statusFrame.Position = UDim2.new(0.5, 0, 0.42, 0)
statusFrame.Visible = false
statusFrame.Parent = statusGui

local statusLayout = Instance.new('UIListLayout')
statusLayout.FillDirection = Enum.FillDirection.Vertical
statusLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
statusLayout.Padding = UDim.new(0, 2)
statusLayout.Parent = statusFrame

local function makeStatusLabel(name, color)
    local lbl = Instance.new('TextLabel')
    lbl.Name = name
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 0, 18)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 16
    lbl.TextColor3 = color
    lbl.TextStrokeTransparency = 0.4
    lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    lbl.Text = ''
    lbl.Parent = statusFrame
    return lbl
end

local lblCatch = makeStatusLabel('Catchable', Color3.fromRGB(230, 220, 200))
local lblAssist = makeStatusLabel('Assistable', Color3.fromRGB(200, 210, 230))
local lblInt = makeStatusLabel('Interceptable', Color3.fromRGB(230, 200, 160))
local lblSwat = makeStatusLabel('Swattable', Color3.fromRGB(255, 170, 80))
local lblInc = makeStatusLabel('Incomplete', Color3.fromRGB(220, 180, 120))

local function estimateThrowStatus(targ)
    local catchable, interceptable, incomplete = 55, 20, 25
    local assistName, assistPct = nil, 0

    local myChar = lp.Character
    local myHRP = myChar and myChar:FindFirstChild('HumanoidRootPart')
    if not myHRP then
        return 0, 0, 100, nil, 0
    end

    if not targ or not targ.Character then
        return 15, 10, 100, nil, 0
    end

    local tHRP = targ.Character:FindFirstChild('HumanoidRootPart')
    local tHead = targ.Character:FindFirstChild('Head')
    if not tHRP then
        return 20, 15, 100, nil, 0
    end

    local dist = (tHRP.Position - myHRP.Position).Magnitude
    local leadPos = targetLeadPos or tHRP.Position
    local openScore = 70

    -- distance soft falloff
    if dist < 25 then openScore = openScore + 15
    elseif dist > 70 then openScore = openScore - 25
    elseif dist > 50 then openScore = openScore - 10
    end

    -- LOS ray
    local origin = (myChar:FindFirstChild('Head') and myChar.Head.Position) or myHRP.Position
    local goal = (tHead and tHead.Position) or tHRP.Position
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { myChar, targ.Character }
    local hit = workspace:Raycast(origin, goal - origin, params)
    if hit then openScore = openScore - 20 end

    -- nearest DB pressure
    local closestDB = math.huge
    for _, plr in ipairs(players:GetPlayers()) do
        if plr ~= lp and plr.Team ~= lp.Team and plr.Character then
            local dhrp = plr.Character:FindFirstChild('HumanoidRootPart')
            if dhrp then
                local d = (dhrp.Position - leadPos).Magnitude
                if d < closestDB then closestDB = d end
            end
        end
    end
    if closestDB < 6 then
        openScore = openScore - 30
        interceptable = 55
    elseif closestDB < 12 then
        openScore = openScore - 15
        interceptable = 35
    elseif closestDB < 20 then
        interceptable = 22
    else
        interceptable = 12
    end

    catchable = math.clamp(openScore, 5, 97)
    incomplete = math.clamp(100 - catchable + (dist > 60 and 15 or 0), 0, 100)
    interceptable = math.clamp(interceptable, 0, 90)

    -- Assistable: best teammate nearer to lead than WR if WR is covered
    local bestAssist, bestA = nil, 0
    for _, plr in ipairs(players:GetPlayers()) do
        if plr ~= lp and plr ~= targ and plr.Team == lp.Team and plr.Character then
            local ahrp = plr.Character:FindFirstChild('HumanoidRootPart')
            if ahrp then
                local ad = (ahrp.Position - leadPos).Magnitude
                local score = math.clamp(100 - ad * 2, 0, 90)
                if closestDB < 10 then score = score + 10 end
                if score > bestA and ad < dist + 15 then
                    bestA = score
                    bestAssist = plr
                end
            end
        end
    end
    if bestAssist and bestA > 12 then
        assistName = bestAssist.Name
        assistPct = math.floor(bestA)
    end

    local swattable = math.clamp(math.floor((100 - catchable) * 0.7 + interceptable * 0.3), 5, 95)
    return math.floor(catchable), math.floor(interceptable), math.floor(incomplete), assistName, assistPct, swattable
end

local function updateThrowStatus(visible, targ)
    if not visible then
        statusFrame.Visible = false
        return
    end
    statusFrame.Visible = true
    local c, i, inc, an, ap, sw = estimateThrowStatus(targ)
    sw = sw or math.clamp(100 - c, 5, 95)
    lblCatch.Text = string.format('Catchable %d%%', c)
    if lblSwat then lblSwat.Text = string.format('Swattable %d%%', sw) end
    lblInt.Text = string.format('Interceptable %d%%', i)
    lblInc.Text = '' -- prefer Swattable
    lblInc.Visible = false
    if an then
        lblAssist.Text = string.format('Assistable: %s %d%%', an, ap)
        lblAssist.Visible = true
    else
        lblAssist.Text = ''
        lblAssist.Visible = false
    end
end


local getActiveBots = function()
    local bots = {}
    local npcwr = workspace:FindFirstChild('npcwr')
    if npcwr then
        local a = npcwr:FindFirstChild('a')
        if a then
            local bot1 = a:FindFirstChild('bot 1')
            if bot1 and bot1:IsA('Model') then table.insert(bots, bot1) end
        end
        local b = npcwr:FindFirstChild('b')
        if b then
            local bot3 = b:FindFirstChild('bot 3')
            if bot3 and bot3:IsA('Model') then table.insert(bots, bot3) end
        end
    end
    return bots
end

local performThrow = function()
    if not enableQbAimbot.Value then return end

    local character = lp.Character
    if not character then return end

    local football = character:FindFirstChildOfClass('Tool')
    if not football then return end

    local handle = football:FindFirstChild('Handle')
    if not handle then return end

    local remote = handle:FindFirstChild('RemoteEvent')
    if not remote then return end

    local head = character:FindFirstChild('Head')
    if not head then return end

    local root = character:FindFirstChild('HumanoidRootPart')
    if not root then return end

    local finalDirection = direction or Vector3.new(0, 1, 0)

    if isPractice then
        local arg = 'Clicked'
        local arg1 = head.Position
        local arg2 = head.Position + finalDirection * 10000
        local arg3 = tonumber(power) or 0
        remote:FireServer(arg, arg1, arg2, arg3)
    else
        local arg = 'Clicked'
        local arg1 = (root.CFrame * CFrame.new(0, 1.5, 0)).Position + Vector3.new(70000000)
        local arg2 = head.Position + finalDirection * 10000
        local arg3 = tonumber(power) or 0
        remote:FireServer(arg, arg1, arg2, arg3, 1)
    end
end

local findRoute = function(character)
    if not character then return 'stationary', Vector3.zero end
    local isPlayer = players:GetPlayerFromCharacter(character)
    local humanoid = character:FindFirstChild('Humanoid')
    local targetHRP = character:FindFirstChild('HumanoidRootPart')
    local qbChar = lp.Character
    local qbHRP = qbChar and qbChar:FindFirstChild('HumanoidRootPart')
    
    if not humanoid or not targetHRP or not qbHRP then 
        return 'stationary', Vector3.zero 
    end
    
    local moveDirection = Vector3.zero
    if isPlayer then
        moveDirection = humanoid.MoveDirection
    else
        local wtpDiff = humanoid.WalkToPoint - targetHRP.Position
        moveDirection = wtpDiff.Magnitude > 0.01 and wtpDiff.Unit or Vector3.zero
    end
    
    local toWR = targetHRP.Position - qbHRP.Position
    local distance = tonumber(toWR.Magnitude) or 0

    local toWRDir = Vector3.new(toWR.X, 0, toWR.Z)
    if toWRDir.Magnitude > 0.01 then
        toWRDir = toWRDir.Unit
    else
        toWRDir = Vector3.new(0, 0, 1)
    end

    local mdFlat = Vector3.new(moveDirection.X, 0, moveDirection.Z)
    if mdFlat.Magnitude < 0.01 then
        return 'stationary', moveDirection
    end
    mdFlat = mdFlat.Unit

    local dot = tonumber(mdFlat:Dot(toWRDir)) or 0

    if dot > 0.75 then
        return 'go/fade', moveDirection
    elseif dot >= 0.25 and dot <= 0.75 then
        if distance <= 120 then return 'slant', moveDirection
        elseif distance <= 160 then return 'seam', moveDirection
        else return 'post/corner', moveDirection end
    elseif dot > -0.25 and dot < 0.25 then
        if distance <= 60 then return 'drag', moveDirection
        elseif distance <= 130 then return 'in/out', moveDirection
        else return 'flat', moveDirection end
    else
        if distance <= 50 then return 'hitch', moveDirection
        else return 'curl/comeback', moveDirection end
    end
end

local isWROpen = function(wrChar)
    if not wrChar then return false end
    local hrp = wrChar:FindFirstChild('HumanoidRootPart')
    if not hrp then return false end

    local isCovered = false
    local _, moveDir = findRoute(wrChar)
    
    local teamCount = 0
    pcall(function() teamCount = tonumber(#game:GetService('Teams'):GetTeams()) or 0 end)
    
    local checkDB = function(dbHRP)
        local toDB = dbHRP.Position - hrp.Position
        local dist = tonumber(toDB.Magnitude) or 0
        if dist < 5 then
            local routeDirXZ = Vector3.new(moveDir.X, 0, moveDir.Z)
            if (tonumber(routeDirXZ.Magnitude) or 0) > 0.01 then
                routeDirXZ = routeDirXZ.Unit
                local dot = tonumber(toDB.Unit:Dot(routeDirXZ)) or 0
                if dot > -0.7 then 
                    return true
                end
            else
                return true
            end
        end
        return false
    end

    local checkPR = function(dbHRP)
        local qbChar = lp.Character
        if not qbChar then return false end
        local qbHRP = qbChar:FindFirstChild('HumanoidRootPart')
        if not qbHRP then return false end
        
        local toPR = dbHRP.Position - qbHRP.Position
        local toWR = hrp.Position - qbHRP.Position
        local wrDist = tonumber(toWR.Magnitude) or 0
        local wrDir = toWR.Unit
        
        local proj = tonumber(toPR:Dot(wrDir)) or 0
        if proj > 2 and proj < (wrDist * 0.6) then
            local distToLine = tonumber((toPR - (wrDir * proj)).Magnitude) or 0
            if distToLine < 5.5 then
                return true
            end
        end
        return false
    end

    local plrs = players:GetPlayers()
    for i = 1, #plrs do
        local plr = plrs[i]
        if plr ~= lp and plr.Character then
            local isEnemy = true
            if teamCount > 1 and lp.Team ~= nil and plr.Team ~= nil and lp.Team == plr.Team then
                isEnemy = false
            end
            if isEnemy then
                local dbHRP = plr.Character:FindFirstChild('HumanoidRootPart')
                if dbHRP and (checkDB(dbHRP) or checkPR(dbHRP)) then
                    isCovered = true
                    break
                end
            end
        end
    end

    if not isCovered then
        local bots = getActiveBots()
        for i = 1, #bots do
            local bot = bots[i]
            if bot ~= wrChar then
                local dbHRP = bot:FindFirstChild('HumanoidRootPart')
                if dbHRP and (checkDB(dbHRP) or checkPR(dbHRP)) then
                    isCovered = true
                    break
                end
            end
        end
    end

    return not isCovered
end

local getTarget = function()
    if isThrowing and target then return target end
    
    if targetLocked and lockedTarget and lockedTarget:FindFirstChild('HumanoidRootPart') then
        return lockedTarget
    elseif targetLocked then
        targetLocked = false
        lockedTarget = nil
    end

    local potentialTargets = {}
    local teamCount = 0
    pcall(function() teamCount = tonumber(#game:GetService('Teams'):GetTeams()) or 0 end)

    local plrs = players:GetPlayers()
    for i = 1, #plrs do
        local plr = plrs[i]
        if plr ~= lp and plr.Character and plr.Character:FindFirstChild('HumanoidRootPart') then
            local isTeammate = true
            if teamCount > 1 and lp.Team ~= nil and plr.Team ~= nil and lp.Team ~= plr.Team then
                isTeammate = false
            end
            
            if isTeammate then
                local eHum = plr.Character:FindFirstChildOfClass('Humanoid')
                if not eHum or not eHum.Sit then
                    table.insert(potentialTargets, plr.Character)
                end
            end
        end
    end

    local bots = getActiveBots()
    for i = 1, #bots do
        local bot = bots[i]
        if bot:FindFirstChild('HumanoidRootPart') then
            local eHum = bot:FindFirstChildOfClass('Humanoid')
            if not eHum or not eHum.Sit then
                table.insert(potentialTargets, bot)
            end
        end
    end

    if #potentialTargets == 0 then return nil end

    if smartFitLock and smartFitLock.Value and lockedTarget then
        local still = false
        for i = 1, #potentialTargets do
            if potentialTargets[i] == lockedTarget then still = true break end
        end
        if still and lockedTarget.Character and lockedTarget.Character:FindFirstChild('HumanoidRootPart') then
            return lockedTarget
        end
    end

    if autoChooseWr.Value then
        local bestAutoTarget = nil
        local bestScore = -math.huge
        local qbHRP = lp.Character and lp.Character:FindFirstChild('HumanoidRootPart')
        local qbPos = qbHRP and qbHRP.Position or Vector3.zero

        for i = 1, #potentialTargets do
            local char = potentialTargets[i]
            local hrp = char:FindFirstChild('HumanoidRootPart')
            if hrp then
                local _, onScreen = camera:WorldToViewportPoint(hrp.Position)
                if onScreen and isWROpen(char) then
                    local dist = tonumber((hrp.Position - qbPos).Magnitude) or 0
                    -- nearest DB separation
                    local nearestDB = 40
                    for _, pl in ipairs(players:GetPlayers()) do
                        if pl ~= lp and pl.Character then
                            local sameTeam = (lp.Team and pl.Team and lp.Team == pl.Team)
                            if not sameTeam then
                                local dhrp = pl.Character:FindFirstChild('HumanoidRootPart')
                                if dhrp then
                                    local d = (dhrp.Position - hrp.Position).Magnitude
                                    if d < nearestDB then nearestDB = d end
                                end
                            end
                        end
                    end
                    -- SmartFit: prefer open space; without it prefer closer WR
                    local score
                    if smartFit and smartFit.Value then
                        -- V2 coverage score: open space + catchable distance
                        score = nearestDB * 2.6 + math.min(dist, 55) * 0.12
                        if nearestDB < 3.5 then score = score - 28
                        elseif nearestDB < 6 then score = score - 12 end
                        -- real-time sideline / OOB geometry
                        local zx = math.abs(hrp.Position.X)
                        local zz = math.abs(hrp.Position.Z)
                        if zx > 55 or zz > 160 then
                            score = score - 30
                        elseif zx > 48 or zz > 145 then
                            score = score - 14
                        end
                        -- prefer receivers moving away from boundary
                        local v = hrp.AssemblyLinearVelocity
                        if zx > 40 and math.sign(v.X) == math.sign(hrp.Position.X) then
                            score = score - 8
                        end
                    else
                        score = 100 - dist
                    end
                    if score > bestScore then
                        bestScore = score
                        bestAutoTarget = char
                        lastCoverageDB = nearestDB
                    end
                end
            end
        end
        
        if bestAutoTarget then
            return bestAutoTarget
        end
    end

    local mousePos2D = userInputService:GetMouseLocation()
    local bestManualTarget = nil
    local bestMouseDist = math.huge

    for i = 1, #potentialTargets do
        local char = potentialTargets[i]
        local hrp = char:FindFirstChild('HumanoidRootPart')
        if hrp then
            local screenPos, onScreen = camera:WorldToViewportPoint(hrp.Position)
            if onScreen then
                local dist = tonumber((Vector2.new(screenPos.X, screenPos.Y) - mousePos2D).Magnitude) or 0
                if dist < bestMouseDist then
                    bestMouseDist = dist
                    bestManualTarget = char
                end
            end
        end
    end

    return bestManualTarget
end

local calculateRouteDirection = function(targetChar)
    if not targetChar then return 'Bullet' end
    local targetHRP = targetChar:FindFirstChild('HumanoidRootPart')
    if not targetHRP then return 'Bullet' end
    
    local lpChar = lp.Character
    local lpHRP = lpChar and lpChar:FindFirstChild('HumanoidRootPart')
    if not lpHRP then return 'Bullet' end

    local route, moveDir = findRoute(targetChar)
    local dist = tonumber((targetHRP.Position - lpHRP.Position).Magnitude) or 0
    local speed = Vector3.new(targetHRP.AssemblyLinearVelocity.X, 0, targetHRP.AssemblyLinearVelocity.Z).Magnitude

    -- stationary / nearly still: never force Dime/Jump — use Bullet (or Mag if very tight)
    if route == 'stationary' or speed < 2.5 then
        if dist < 55 then return 'Bullet' end
        return 'Mag'
    end

    if dist < 35 then return 'Bullet' end
    
    local dbDistance = math.huge
    local teamCount = 0
    pcall(function() teamCount = tonumber(#game:GetService('Teams'):GetTeams()) or 0 end)

    local plrs = players:GetPlayers()
    for i = 1, #plrs do
        local plr = plrs[i]
        if plr ~= lp and plr.Character then
            local eHRP = plr.Character:FindFirstChild('HumanoidRootPart')
            if eHRP and eHRP ~= targetHRP then
                local isEnemy = true
                if teamCount > 1 and lp.Team ~= nil and plr.Team ~= nil and lp.Team == plr.Team then
                    isEnemy = false
                end
                if isEnemy then
                    local d = tonumber((eHRP.Position - targetHRP.Position).Magnitude) or 0
                    if d < dbDistance then dbDistance = d end
                end
            end
        end
    end

    local bots = getActiveBots()
    for i = 1, #bots do
        local bot = bots[i]
        local bHRP = bot:FindFirstChild('HumanoidRootPart')
        if bHRP and bHRP ~= targetHRP then
            local d = tonumber((bHRP.Position - targetHRP.Position).Magnitude) or 0
            if d < dbDistance then dbDistance = d end
        end
    end

    local within = function(tbl, val)
        for i = 1, #tbl do
            if tbl[i] == val then return true end
        end
        return false
    end

    local forwardRoutes = {'go/fade', 'post/corner', 'seam', 'curl/comeback'}
    local sidewayRoutes = {'in/out', 'flat', 'wheel'}
    
    if route == 'slant' or route == 'hitch' or route == 'drag' or route == 'in/out' or route == 'flat' then
        return 'Bullet'
    elseif within(forwardRoutes, route) then
        if dbDistance > 6 then
            -- deep open: Dime (higher ball), not low Jump lasers for comps
            if dist > 45 then return 'Dime' end
            return 'Jump'
        elseif dbDistance > 2.5 then return 'Dive' end
        return 'Mag'
    elseif within(sidewayRoutes, route) then
        if dbDistance > 4 then return 'Dime' end
        return 'Jump'
    end
    return 'Bullet'
end

local getModeLead = function(modeName)
    local base = 8.6
    if modeName == 'Dime' then base = leadDime
    elseif modeName == 'Mag' then base = leadMag
    elseif modeName == 'Dive' then base = leadDive
    elseif modeName == 'Jump' then base = leadJump
    elseif modeName == 'Bullet' then base = leadBullet
    end
    local m = (leadMultiplier and tonumber(leadMultiplier.Value)) or 1
    local extra = 0
    if pingCompensation and pingCompensation.Value then
        pcall(function()
            local st = game:GetService('Stats')
            local n = st.Network.ServerStatsItem['Data Ping']:GetValue()
            extra = math.clamp((tonumber(n) or 50) / 1000, 0.02, 0.35) * 12
        end)
    end
    return base * m + extra
end

local getModeYLead = function(modeName)
    if modeName == 'Dime' then return yLeadDime
    elseif modeName == 'Mag' then return yLeadMag
    elseif modeName == 'Dive' then return yLeadDive
    elseif modeName == 'Jump' then return yLeadJump
    elseif modeName == 'Bullet' then return yLeadBullet
    end
    return 0
end

local getPing = function()
    local networkPing = 0
    pcall(function() networkPing = tonumber(lp:GetNetworkPing()) or 0 end)
    local dataPing = 0
    pcall(function() dataPing = (tonumber(stats.Network.ServerStatsItem['Data Ping']:GetValue()) or 0) / 1000 end)
    if dataPing == 0 then dataPing = networkPing end
    return networkPing + dataPing
end


local function sanitizeLeadPos(leadPos, targetChar, origin)
    if not leadPos then return leadPos end
    -- Nova fix: diving / flung receivers were sending beam to endzone
    local hrp = targetChar and targetChar:FindFirstChild('HumanoidRootPart')
    local hum = targetChar and targetChar:FindFirstChildOfClass('Humanoid')
    if hrp then
        local vel = hrp.AssemblyLinearVelocity or Vector3.zero
        local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
        -- if flung absurdly far from origin horizontally, pull back toward body
        local flat = Vector3.new(leadPos.X - origin.X, 0, leadPos.Z - origin.Z)
        if flat.Magnitude > 120 then
            leadPos = hrp.Position + Vector3.new(vel.X, 0, vel.Z) * 0.35
        end
        -- diving / ragdoll: prefer velocity prediction over raw lead Y spikes
        if hum then
            local st = hum:GetState()
            if st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll then
                leadPos = hrp.Position + Vector3.new(vel.X, math.clamp(vel.Y, -10, 20), vel.Z) * 0.4
            end
        end
        -- clamp lead Y relative to HRP
        leadPos = Vector3.new(leadPos.X, math.clamp(leadPos.Y, hrp.Position.Y - 5, hrp.Position.Y + 18), leadPos.Z)
    end
    return leadPos
end

local solveKinematics = function(origin, targetPos, gravityMag)
    local g = tonumber(gravityMag) or 28
    local displacement = targetPos - origin
    local x = tonumber(Vector3.new(displacement.X, 0, displacement.Z).Magnitude) or 0
    local y = tonumber(displacement.Y) or 0
    
    local inner = (x^2) + (y^2)
    local root = tonumber(math.sqrt(math.max(inner, 0))) or 0
    
    local baseAngleRad = math.rad(45)
    if x > 0.01 then
        local atanRes = tonumber(math.atan((y + root) / x)) or baseAngleRad
        if atanRes and atanRes == atanRes then
            baseAngleRad = atanRes
        end
    end
    
    local angleRad = tonumber(math.clamp(baseAngleRad * 0.85, math.rad(-15), math.rad(65))) or 0
    
    local cosA = tonumber(math.cos(angleRad)) or 1
    local tanA = tonumber(math.tan(angleRad)) or 0
    
    local v0 = 95
    local denom = 2 * (cosA^2) * (x * tanA - y)
    
    if denom > 0.001 then
        local num = g * (x^2)
        local res = tonumber(math.sqrt(num / denom)) or v0
        if res and res == res and res ~= math.huge then
            v0 = res
        end
    end
    
    local angleDeg = tonumber(math.deg(angleRad)) or 45
    return v0, angleDeg
end

local autoAim = function(targetHRP)
    local head = lp.Character:FindFirstChild('Head')
    local origin = head and head.Position or lp.Character.HumanoidRootPart.Position
    
    local targetChar = targetHRP.Parent
    local targetHeadObj = targetChar and targetChar:FindFirstChild('Head')
    local targetHead = targetHeadObj and targetHeadObj.Position or targetHRP.Position + Vector3.new(0, 1.5, 0)
    
    local moveDir = Vector3.zero
    local targetHum = targetChar and targetChar:FindFirstChildOfClass('Humanoid')
    if targetHum then
        local isBot = targetChar:FindFirstAncestor('npcwr') ~= nil
        if isBot then
            local wtpDiff = targetHum.WalkToPoint - targetHRP.Position
            local dir = Vector3.new(wtpDiff.X, 0, wtpDiff.Z)
            moveDir = dir.Magnitude > 0.1 and dir.Unit or Vector3.zero
        else
            local md = targetHum.MoveDirection
            local flatMd = Vector3.new(md.X, 0, md.Z)
            moveDir = flatMd.Magnitude > 0.01 and flatMd.Unit or Vector3.zero
        end
    end
    
    local ping = tonumber(getPing()) or 0
    local speed = 20
    
    local modeName = ModeOrder[modeIndex]
    -- manual / lock mode (fix: standing WR was forced Dime/Jump)
    if lockPassMode and lockPassMode.Value then
        modeName = tostring(forcedPassMode and forcedPassMode.Value or 'Bullet')
        if modeName == 'Angle' then modeName = 'Dime' end
    elseif forcedPassMode and (not autoSelectThrowMode or not autoSelectThrowMode.Value) then
        local forced = tostring(forcedPassMode.Value or '')
        if forced ~= '' and forced ~= 'nil' then
            modeName = forced
            if modeName == 'Angle' then modeName = 'Dime' end
        end
    end
    local isChestPass = (modeName == 'Bullet' or target and (findRoute(target) == 'slant' or findRoute(target) == 'drag' or findRoute(target) == 'in/out' or findRoute(target) == 'flat' or findRoute(target) == 'hitch' or findRoute(target) == 'curl/comeback'))
    local routeStr = target and findRoute(target) or 'go/fade'
    
    local activePower = tonumber(power) or 60
    if modeName == 'Bullet' or ((autoPower and autoPower.Value) and isChestPass) or (highPowerOnly and highPowerOnly.Value) then
        activePower = 95
    end
    
    local lDivisor = 60
    if activePower > 75 then
        lDivisor = 60 + ((activePower - 75) * 1.5)
    end
    
    local distToTarget = tonumber((targetHRP.Position - origin).Magnitude) or 0
    local estFlightTime = distToTarget / (tonumber(lDivisor) or 60)
    
    local currentHVel = activePower * (tonumber(math.cos(math.rad(tonumber(angle) or 45))) or 1)
    if currentHVel < 30 then currentHVel = 55 end
    
    local estHVel = (modeName == 'Bullet' or isChestPass) and 90 or currentHVel
    
    local modeLeadScale = (tonumber(getModeLead(modeName)) or 8.6) * 3.05
    local selectedModeYLead = tonumber(getModeYLead(modeName)) or 0
    
    local routeMultipliers = {
        ['slant'] = 0.45,
        ['drag'] = 0.6,
        ['in/out'] = 0.65,
        ['flat'] = 0.65,
        ['wheel'] = 0.9,
        ['go/fade'] = 1.0,
        ['post/corner'] = 0.85,
        ['seam'] = 0.85,
        ['hitch'] = 0.1,
        ['curl/comeback'] = 0.1,
        ['stationary'] = 0.0
    }
    local rMult = tonumber(routeMultipliers[routeStr]) or 1.0
    
    local dirUnit = moveDir.Magnitude > 0.01 and moveDir.Unit or Vector3.zero
    
    local targetBase = (isChestPass or modeName == 'Bullet') and targetHRP.Position or targetHead
    
    local standingStill = (routeStr == 'stationary')
    
    if standingStill then
        leadPos = targetHead
    else
        leadPos = targetBase + (moveDir * speed * estFlightTime * rMult) + (moveDir * speed * ping * rMult) + (dirUnit * modeLeadScale * rMult)
        leadPos = leadPos + (dirUnit * (tonumber(throwLeadOffset.Value) or 0))
        
        if isChestPass or modeName == 'Bullet' then
            -- slightly higher than pure chest so comps don't undercut as easily
            local yBoost = (speed and speed < 3) and 1.8 or 1.15
            leadPos = Vector3.new(leadPos.X, targetHead.Y + yBoost, leadPos.Z)
            selectedModeYLead = yBoost
        end
        
        leadPos = leadPos + Vector3.new(0, selectedModeYLead, 0)
        leadPos = leadPos + Vector3.new(0, tonumber(throwHeightOffset.Value) or 0, 0)
        
        if routeStr == 'curl/comeback' or routeStr == 'hitch' then
            leadPos = leadPos + Vector3.new(0, -5, 0)
        end
    end
    
    local forceAutoAngle = (modeName == 'Bullet' or isChestPass or (tonumber(power) or 60) == 95 or highPowerOnly.Value)
    if not autoAngle.Value and not forceAutoAngle then
        leadPos = leadPos + Vector3.new(0, tonumber(customHeight.Value) or 0, 0)
    end
    
    if antiDB.Value then
        local pushVec = Vector3.zero
        local plrs = players:GetPlayers()
        local teamCount = 0
        pcall(function() teamCount = tonumber(#game:GetService('Teams'):GetTeams()) or 0 end)

        for i = 1, #plrs do
            local plr = plrs[i]
            if plr ~= lp and plr.Character then
                local isEnemy = true
                if teamCount > 1 and lp.Team ~= nil and plr.Team ~= nil and lp.Team == plr.Team then
                    isEnemy = false
                end
                if isEnemy then
                    local eHRP = plr.Character:FindFirstChild('HumanoidRootPart')
                    if eHRP then
                        local dist = tonumber(Vector3.new(eHRP.Position.X - leadPos.X, 0, eHRP.Position.Z - leadPos.Z).Magnitude) or 0
                        if dist < (tonumber(antiDBThreshold.Value) or 15) then
                            local away = (leadPos - eHRP.Position)
                            away = Vector3.new(away.X, 0, away.Z)
                            if away.Magnitude > 0 then
                                pushVec = pushVec + (away.Unit * ((tonumber(antiDBThreshold.Value) or 15) - dist))
                            end
                        end
                    end
                end
            end
        end
        leadPos = pushVec + leadPos
    end

    local fPos = Vector3.zero
    local field = workspace:FindFirstChild('Models')
    if field then field = field:FindFirstChild('Field') end
    if field then field = field:FindFirstChild('Ground') end
    if field then fPos = field.Position end

    if antiOOB.Value and fPos ~= Vector3.zero then
        local margin = (tonumber(antiOOBThreshold.Value) or 5) + ((safetyMargin and tonumber(safetyMargin.Value)) or 0) + ((boundsTolerance and tonumber(boundsTolerance.Value)) or 0)
        local halfWidth = 75 - margin
        local halfLength = 175 - margin
        leadPos = Vector3.new(
            math.clamp(leadPos.X, fPos.X - halfWidth, fPos.X + halfWidth),
            leadPos.Y,
            math.clamp(leadPos.Z, fPos.Z - halfLength, fPos.Z + halfLength)
        )
    end
    
    -- reach / height / fade bias
    do
        local up = (catchHeightLead and tonumber(catchHeightLead.Value)) or 0
        local wrH = (wrHorizReach and tonumber(wrHorizReach.Value)) or 0
        local wrV = (wrVertReach and tonumber(wrVertReach.Value)) or 0
        leadPos = leadPos + Vector3.new(0, up + wrV * 0.35, 0)
        if target and target.Character then
            local thrp = target.Character:FindFirstChild('HumanoidRootPart')
            local thum = target.Character:FindFirstChildOfClass('Humanoid')
            if thrp and thum then
                local md = thum.MoveDirection
                if md.Magnitude > 0.1 then
                    local fade = (fadeLead and tonumber(fadeLead.Value)) or 0
                    local wrR = (wrReaction and tonumber(wrReaction.Value)) or 0
                    leadPos = leadPos + md.Unit * (wrH * 0.5 + fade * 0.25 + thum.WalkSpeed * wrR * 0.15)
                end
            end
        end
        if not (ignoreDefenders and ignoreDefenders.Value) then
            local dbH = (dbHorizReach and tonumber(dbHorizReach.Value)) or 0
            local dbR = (dbReaction and tonumber(dbReaction.Value)) or 0
            if dbH > 0 and target and target.Character then
                local thrp = target.Character:FindFirstChild('HumanoidRootPart')
                if thrp then
                    for _, plr in ipairs(players:GetPlayers()) do
                        if plr ~= player and plr ~= target and plr.Character then
                            if player.Team and plr.Team and plr.Team == player.Team then continue end
                            local ehrp = plr.Character:FindFirstChild('HumanoidRootPart')
                            if ehrp and (ehrp.Position - thrp.Position).Magnitude < 12 + dbH then
                                local away = (thrp.Position - ehrp.Position)
                                away = Vector3.new(away.X, 0, away.Z)
                                if away.Magnitude > 0.1 then
                                    leadPos = leadPos + away.Unit * (dbH * 0.35 + dbR * 2)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    targetLeadPos = sanitizeLeadPos(leadPos, target and target.Character, origin)
    leadPos = targetLeadPos
    
    local gMag = 28 
    local calcPower, calcAngle = solveKinematics(origin, leadPos, gMag)
    calcPower = tonumber(calcPower) or 95
    calcAngle = tonumber(calcAngle) or 45
    
    if standingStill and modeName ~= 'Bullet' and not (highPowerOnly and highPowerOnly.Value) then
        local dynamicThreshold = tonumber(math.clamp(4 + (distToTarget * 0.08), 5, 14)) or 10
        if calcAngle > dynamicThreshold then
            local displacement = leadPos - origin
            local x = tonumber(Vector3.new(displacement.X, 0, displacement.Z).Magnitude) or 0
            local y = tonumber(displacement.Y) or 0
            local aRad = tonumber(math.rad(dynamicThreshold)) or 0.1
            local denom = 2 * (math.cos(aRad)^2) * (x * math.tan(aRad) - y)
            
            if denom > 0.001 then
                local newPwr = tonumber(math.sqrt((gMag * x^2) / denom)) or calcPower
                if newPwr == newPwr and newPwr ~= math.huge then
                    calcAngle = dynamicThreshold
                    calcPower = newPwr
                end
            end
        end
    end
    
    if highPowerOnly and highPowerOnly.Value then
        power = 95
        local displacement = leadPos - origin
        local x = tonumber(Vector3.new(displacement.X, 0, displacement.Z).Magnitude) or 0
        local y = tonumber(displacement.Y) or 0
        
        local v2 = 95^2
        local v4 = 95^4
        local gx = gMag * x
        local discriminant = v4 - gMag * (gMag * x^2 + 2 * y * v2)
        
        if discriminant >= 0 then
            angle = tonumber(math.clamp(math.deg(math.atan((v2 - math.sqrt(discriminant)) / gx)) * 0.94, -15, 85)) or 45
        else
            angle = 45
        end
    elseif modeName == 'Bullet' or ((autoPower and autoPower.Value) and isChestPass) then
        power = 95
        local displacement = leadPos - origin
        local h = tonumber(Vector3.new(displacement.X, 0, displacement.Z).Magnitude) or 0
        local v = tonumber(displacement.Y) or 0
        local t_est = h / 95
        local drop = 0.5 * 28 * t_est * t_est
        angle = tonumber(math.clamp(math.deg(math.atan2(v + drop, h)), -15, 45)) or 15
    else
        if autoPower.Value then
            power = tonumber(math.clamp(calcPower, 0, 95)) or 60
        end
        if autoAngle.Value then
            angle = tonumber(math.clamp(calcAngle, -15, 90)) or 45
        end
    end
    
    if not autoAngle.Value and not forceAutoAngle then
        angle = tonumber(math.clamp(calcAngle, -15, 90)) or 45
    end
    
    local safePower = tonumber(power) or 60
    local safeAngle = tonumber(angle) or 45
    local angleRad = tonumber(math.rad(safeAngle)) or 0
    
    local hDirRaw = Vector3.new(leadPos.X - origin.X, 0, leadPos.Z - origin.Z)
    local hDir = hDirRaw.Magnitude > 0.01 and hDirRaw.Unit or head.CFrame.LookVector
    local dirVelocity = (hDir * (tonumber(math.cos(angleRad)) or 1) + Vector3.new(0, tonumber(math.sin(angleRad)) or 0, 0)) * safePower
    
    direction = dirVelocity.Unit * safePower
    
    local hVel = safePower * (tonumber(math.cos(angleRad)) or 1)
    if hVel > 0.1 then
        local xDist = tonumber(Vector3.new(leadPos.X - origin.X, 0, leadPos.Z - origin.Z).Magnitude) or 0
        airtime = xDist / hVel
    else
        airtime = 0
    end
    
    return safeAngle
end

local beamProjectile = function(g, v0, x0, t1)
    local c = 0.5 * 0.5 * 0.5
    local safeT1 = tonumber(t1) or 0.1
    local p3 = 0.5 * g * safeT1 * safeT1 + v0 * safeT1 + x0
    local p2 = p3 - (g * safeT1 * safeT1 + v0 * safeT1) / 3
    local p1 = (c * g * safeT1 * safeT1 + 0.5 * v0 * safeT1 + x0 - c * (x0 + p3)) / (3 * c) - p2

    local curve0 = tonumber((p1 - x0).Magnitude) or 0
    local curve1 = tonumber((p2 - p3).Magnitude) or 0

    local b = (x0 - p3).Unit
    local r1 = (p1 - x0).Unit
    local u1 = r1:Cross(b).Unit
    local r2 = (p2 - p3).Unit
    local u2 = r2:Cross(b).Unit
    b = u1:Cross(r1).Unit

    local cf1 = CFrame.new(
        x0.X, x0.Y, x0.Z,
        r1.X, u1.X, b.X,
        r1.Y, u1.Y, b.Y,
        r1.Z, u1.Z, b.Z
    )

    local cf2 = CFrame.new(
        p3.X, p3.Y, p3.Z,
        r2.X, u2.X, b.X,
        r2.Y, u2.Y, b.Y,
        r2.Z, u2.Z, b.Z
    )

    return curve0, -curve1, cf1, cf2
end

userInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    local char = lp.Character
    if not char or not char:FindFirstChild('Football') then return end
    
    if input.KeyCode == throwBallAwayKeybind.Value then
        local fPos = Vector3.zero
        local field = workspace:FindFirstChild('Models')
        if field then field = field:FindFirstChild('Field') end
        if field then field = field:FindFirstChild('Ground') end
        if field then fPos = field.Position end
        
        local side = math.random(1, 2) == 1 and -1 or 1
        local throwTarget = fPos + Vector3.new(side * 120, 0, math.random(-100, 100))
        
        local head = char:FindFirstChild('Head')
        local origin = head and head.Position or char.HumanoidRootPart.Position
        
        isThrowingAway = true
        power = 95
        angle = 25
        
        local angleRad = tonumber(math.rad(angle)) or 0
        local hDir = Vector3.new(throwTarget.X - origin.X, 0, throwTarget.Z - origin.Z).Unit
        local dirVelocity = (hDir * (tonumber(math.cos(angleRad)) or 1) + Vector3.new(0, tonumber(math.sin(angleRad)) or 0, 0)) * 95
        direction = dirVelocity.Unit * 95
        
        local hVel = 95 * (tonumber(math.cos(angleRad)) or 1)
        airtime = hVel > 0.1 and ((tonumber(Vector3.new(throwTarget.X - origin.X, 0, throwTarget.Z - origin.Z).Magnitude) or 0) / hVel) or 1
        
        local hum = char:FindFirstChildOfClass('Humanoid')
        local throwAnim = replicatedStorage:FindFirstChild('Animations') and replicatedStorage.Animations:FindFirstChild('Throw')
        if hum and throwAnim then
            local animator = hum:FindFirstChild('Animator')
            if animator then
                local track = animator:LoadAnimation(throwAnim)
                track:Play()
            end
        end
        return
    end

    if input.KeyCode == increaseAngleKeybind.Value then
        customHeight.Value = (tonumber(customHeight.Value) or 0) + 5
    elseif input.KeyCode == decreaseAngleKeybind.Value then
        customHeight.Value = (tonumber(customHeight.Value) or 0) - 5
    end
    
    if not autoSelectThrowMode.Value and QBKeybinds[input.KeyCode] then
        local desiredMode = QBKeybinds[input.KeyCode]
        for i = 1, #ModeOrder do
            if ModeOrder[i] == desiredMode then
                modeIndex = i
                break
            end
        end
    end

    if input.KeyCode == lockKeybind.Value then
        if target or targetLocked then
            targetLocked = not targetLocked
            if targetLocked then
                lockedTarget = target
                if LockToggleBtn then LockToggleBtn.TextColor3 = Color3.fromRGB(255, 50, 50) end
                if LockedLabel then LockedLabel.Visible = true end
            else
                lockedTarget = nil
                if LockToggleBtn then LockToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255) end
                if LockedLabel then LockedLabel.Visible = false end
            end
        end
    end
end)

local triggerThrowJump = function()
    if autoJumpWhenThrow.Value then
        task.delay(0.05, function()
            local char = lp.Character
            if char then
                local hum = char:FindFirstChildOfClass('Humanoid')
                if hum and hum:GetState() ~= Enum.HumanoidStateType.Jumping then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end)
    end
end

task.spawn(function()
    local bindAnimation = function(char)
        local humanoid = char:WaitForChild('Humanoid', 5)
        if not humanoid then return end
        local animator = humanoid:WaitForChild('Animator', 5)
        if not animator then return end
        
        animator.AnimationPlayed:Connect(function(track)
            local throwAnim = replicatedStorage:FindFirstChild('Animations') and replicatedStorage.Animations:FindFirstChild('Throw')
            if throwAnim and track.Animation and (track.Animation == throwAnim or track.Animation.AnimationId == throwAnim.AnimationId) then
                track:GetPropertyChangedSignal('IsPlaying'):Connect(function()
                    if track.IsPlaying then
                        if not isThrowing then
                            isThrowing = true
                            triggerThrowJump()
                            task.delay(0.12, function()
                                firedRemote = true
                                performThrow()
                            end)
                        end
                    else
                        isThrowing = false
                        firedRemote = false
                        isThrowingAway = false
                    end
                end)
                
                if track.IsPlaying and not isThrowing then
                    isThrowing = true
                    triggerThrowJump()
                    task.delay(0.12, function()
                        firedRemote = true
                        performThrow()
                    end)
                end
            end
        end)
    end

    if lp.Character then
        bindAnimation(lp.Character)
    end
    lp.CharacterAdded:Connect(function(char)
        bindAnimation(char)
    end)
end)

local setupSackHandler = function(character)
    character.ChildAdded:Connect(function(v)
        if not autoThrowAfterSack.Value then return end
        if not v:IsA('LocalScript') then return end
        if not v.Name:lower():find('tackle') then return end

        task.wait()

        local humanoid = character:FindFirstChildOfClass('Humanoid')
        if not humanoid then return end

        if autoChooseWr.Value then
            local openWR = nil
            local bestDist = math.huge
            local mousePos2D = userInputService:GetMouseLocation()
            
            local teamCount = 0
            pcall(function() teamCount = tonumber(#game:GetService('Teams'):GetTeams()) or 0 end)
            
            local plrs = players:GetPlayers()
            for i = 1, #plrs do
                local plr = plrs[i]
                if plr ~= lp and plr.Character then
                    local isTeammate = true
                    if teamCount > 1 and lp.Team ~= nil and plr.Team ~= nil and lp.Team ~= plr.Team then
                        isTeammate = false
                    end
                    
                    if isTeammate then
                        local eHrp = plr.Character:FindFirstChild('HumanoidRootPart')
                        local eHum = plr.Character:FindFirstChildOfClass('Humanoid')
                        if eHrp and (not eHum or not eHum.Sit) and isWROpen(plr.Character) then
                            local screenPos, onScreen = camera:WorldToViewportPoint(eHrp.Position)
                            if onScreen then
                                local dist = tonumber((Vector2.new(screenPos.X, screenPos.Y) - mousePos2D).Magnitude) or 0
                                if dist < bestDist then
                                    bestDist = dist
                                    openWR = plr.Character
                                end
                            end
                        end
                    end
                end
            end

            if openWR then
                target = openWR
                targetLocked = true
        if smartFitLock and smartFitLock.Value then lockedTarget = target end
                lockedTarget = openWR
            end
        end

        if target then
            local throwAnim = replicatedStorage:FindFirstChild('Animations') and replicatedStorage.Animations:FindFirstChild('Throw')
            if throwAnim then
                local animator = humanoid:FindFirstChild('Animator')
                if animator then
                    local track = animator:LoadAnimation(throwAnim)
                    track:Play()
                end
            end
        end
    end)
end

if lp.Character then
    setupSackHandler(lp.Character)
end
lp.CharacterAdded:Connect(setupSackHandler)

local updateHighlights = function(isActive)
    if not isActive then
        if highlight then highlight:Destroy(); highlight = nil end
        return
    end

    if target then
        if not highlight then
            highlight = Instance.new('Highlight')
        end
        highlight.Adornee = target
        highlight.Parent = target
        highlight.FillTransparency = 1
        highlight.OutlineColor = targetLocked and Color3.new(0, 0, 0) or Color3.fromRGB(255, 255, 255)
        highlight.OutlineTransparency = 0
    elseif highlight then
        highlight:Destroy()
        highlight = nil
    end
end

workspace.ChildAdded:Connect(function(v)
    if not enableQbAimbot.Value then return end
    if v:IsA('BasePart') and v.Name == 'Football' then
        task.wait()
        local lpChar = lp.Character
        local lpHead = lpChar and lpChar:FindFirstChild('Head')
        if not lpHead then return end
        
        if v:GetAttribute('LocalAimbotBall') or (v.Position - lpHead.Position).Magnitude < 15 then
            local tAttach0 = Instance.new('Attachment', workspace.Terrain)
            local tAttach1 = Instance.new('Attachment', workspace.Terrain)
            
            local tBeam = Instance.new('Beam')
            tBeam.Attachment0 = tAttach0
            tBeam.Attachment1 = tAttach1
            tBeam.Segments = 7500
            tBeam.Width0 = 1
            tBeam.Width1 = 1
            tBeam.FaceCamera = true
            tBeam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
            tBeam.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.01, 0),
                NumberSequenceKeypoint.new(1, 0)
            })
            tBeam.Parent = workspace.Terrain
            
            local tPosPart = Instance.new('Part', workspace.Terrain)
            tPosPart.Anchored = true
            tPosPart.CanCollide = false
            tPosPart.CastShadow = false
            tPosPart.Size = Vector3.new(3, 3, 3)
            tPosPart.Shape = Enum.PartType.Ball
            tPosPart.Color = Color3.fromRGB(0, 0, 0)
            
            local safeDirection = direction or Vector3.new(0, 1, 0)
            local safeAirtime = math.max(tonumber(airtime) or 0.1, 0.1)
            local curve0, curve1, cf1, cf2 = beamProjectile(Vector3.new(0, -28, 0), safeDirection, lpHead.Position + (safeDirection.Unit * 5), safeAirtime)
            
            tBeam.CurveSize0 = curve0
            tBeam.CurveSize1 = curve1
            
            tAttach0.WorldCFrame = cf1
            tAttach1.WorldCFrame = cf2
            
            tPosPart.Position = Vector3.new(cf2.X, cf2.Y, cf2.Z)
            
            task.delay(safeAirtime, function()
                tBeam:Destroy()
                tAttach0:Destroy()
                tAttach1:Destroy()
                tPosPart:Destroy()
            end)
        end
    end
end)

runService.RenderStepped:Connect(function()
    if not enableQbAimbot.Value then
        updateHUDVisibility(false)
        updateHighlights(false)
        if beam then pcall(function() beam.Enabled = false end) end
        if posPart then posPart.Position = Vector3.new(0, -9999, 0) end
        if attach0 then attach0.WorldPosition = Vector3.new(0, -9999, 0) end
        if attach1 then attach1.WorldPosition = Vector3.new(0, -9999, 0) end
        target = nil
        return
    end

    if not sg or not sg.Parent then return end

    local char = lp.Character
    if not char then return end
    
    local head = char:FindFirstChild('Head')
    local hrp = char:FindFirstChild('HumanoidRootPart')
    if not head or not hrp then return end

    local football = char:FindFirstChild('Football')
    local hasFootball = (football ~= nil)
    
    if hasFootball then
        football:SetAttribute('LocalAimbotBall', true)
        local fHandle = football:FindFirstChild('Handle')
        if fHandle then fHandle:SetAttribute('LocalAimbotBall', true) end
    end
    
    local playerGui = lp:WaitForChild('PlayerGui', 10)
    local ballGui = playerGui and playerGui:FindFirstChild('BallGui')
    
    if autoJuke.Value and hasFootball and ballGui then
        local fPos = Vector3.zero
        local field = workspace:FindFirstChild('Models')
        if field then field = field:FindFirstChild('Field') end
        if field then field = field:FindFirstChild('Ground') end
        if field then fPos = field.Position end
        
        local minX = fPos.X - (155 / 2)
        local maxX = fPos.X + (155 / 2)
        local minZ = fPos.Z - (355 / 2)
        local maxZ = fPos.Z + (355 / 2)

        local dodgeVec = Vector3.zero
        local threatCount = 0

        local plrs = players:GetPlayers()
        local teamCount = 0
        pcall(function() teamCount = tonumber(#game:GetService('Teams'):GetTeams()) or 0 end)
        
        for i = 1, #plrs do
            local plr = plrs[i]
            if plr ~= lp and plr.Character then
                local isEnemy = true
                if teamCount > 1 and lp.Team ~= nil and plr.Team ~= nil and lp.Team == plr.Team then
                    isEnemy = false
                end
                
                if isEnemy then
                    local eHrp = plr.Character:FindFirstChild('HumanoidRootPart')
                    if eHrp then
                        local distToMe = tonumber((eHrp.Position - hrp.Position).Magnitude) or 0
                        if distToMe < 45 then
                            local eVel = eHrp.AssemblyLinearVelocity or eHrp.Velocity or Vector3.zero
                            local eSpeed = tonumber(Vector3.new(eVel.X, 0, eVel.Z).Magnitude) or 0
                            local tta = distToMe / math.max(eSpeed, 1)
                            
                            local futureTime = math.min(tta, 1)
                            local eFuture = eHrp.Position + (eVel * futureTime)
                            local myVel = hrp.AssemblyLinearVelocity or hrp.Velocity or Vector3.zero
                            local myFuture = hrp.Position + (myVel * futureTime)
                            
                            local toThreat = eFuture - myFuture
                            local futureDist = tonumber(Vector3.new(toThreat.X, 0, toThreat.Z).Magnitude) or 0
                            
                            if futureDist < 20 or distToMe < 25 then
                                threatCount = threatCount + 1
                                local awayDir = myFuture - eFuture
                                awayDir = Vector3.new(awayDir.X, 0, awayDir.Z)
                                if awayDir.Magnitude < 0.1 then
                                    awayDir = hrp.CFrame.RightVector
                                end
                                awayDir = awayDir.Unit
                                
                                local weight = math.clamp(45 - distToMe, 0, 45)
                                dodgeVec = dodgeVec + (awayDir * weight)
                            end
                        end
                    end
                end
            end
        end

        local hum = char:FindFirstChildOfClass('Humanoid')
        if hum then
            local checkPos = hrp.Position
            local outOfBoundsPush = Vector3.zero
            
            if checkPos.X < minX + 5 then outOfBoundsPush = outOfBoundsPush + Vector3.new(1, 0, 0) end
            if checkPos.X > maxX - 5 then outOfBoundsPush = outOfBoundsPush + Vector3.new(-1, 0, 0) end
            if checkPos.Z < minZ + 5 then outOfBoundsPush = outOfBoundsPush + Vector3.new(0, 0, 1) end
            if checkPos.Z > maxZ - 5 then outOfBoundsPush = outOfBoundsPush + Vector3.new(0, 0, -1) end
            
            local targetJukeDir = Vector3.zero
            if threatCount > 0 then
                targetJukeDir = dodgeVec.Unit
                if outOfBoundsPush.Magnitude > 0 then
                    targetJukeDir = (targetJukeDir + outOfBoundsPush * 2).Unit
                end
            elseif outOfBoundsPush.Magnitude > 0 then
                targetJukeDir = outOfBoundsPush.Unit
            end
            
            if targetJukeDir.Magnitude > 0 then
                smoothedJukeDir = smoothedJukeDir:Lerp(targetJukeDir, 0.25)
                hum:Move(smoothedJukeDir, false)
            else
                smoothedJukeDir = Vector3.zero
            end
        end
    end

    local isTracking = hasFootball and (ballGui ~= nil)
    if hasFootball and character then
        head = character:FindFirstChild('Head') or head
        hrp = character:FindFirstChild('HumanoidRootPart') or hrp
    end

    if isTracking and head and hrp then
        if not hideCards.Value then
            updateHUDVisibility(true)
        else
            updateHUDVisibility(false)
        end
        
        if not isThrowingAway then
            local newTarget = getTarget()
            if newTarget then
                lastValidTarget = newTarget
            elseif lastValidTarget and not lastValidTarget:FindFirstChild('HumanoidRootPart') then
                lastValidTarget = nil
            end
            
            if throwAimbot.Value then
                target = lastValidTarget
                updateHighlights(false)
                
                -- Nova-style: actual throw lands at mouse world point
                local targetPos
                if isThrowing and lockedMousePos then
                    targetPos = lockedMousePos
                else
                    local hitOk, hitPos = pcall(function() return mouse.Hit.Position end)
                    targetPos = (hitOk and hitPos) or (head.Position + head.CFrame.LookVector * 40)
                    lockedMousePos = targetPos
                end
                
                local headPos = head.Position
                local gMag = 28
                local calcPower, calcAngle = solveKinematics(headPos, targetPos, gMag)
                calcPower = tonumber(calcPower) or 95
                calcAngle = tonumber(calcAngle) or 45
                
                -- Arc option (low / high)
                local arc = (mouseThrowArc and mouseThrowArc.Value) or 'Auto'
                if arc == 'Low' then
                    calcAngle = math.clamp(calcAngle * 0.55, 8, 28)
                    calcPower = math.clamp(calcPower * 1.08, 40, 95)
                elseif arc == 'High' then
                    calcAngle = math.clamp(math.max(calcAngle, 32) * 1.15, 30, 55)
                    calcPower = math.clamp(calcPower * 0.95, 35, 95)
                end
                
                -- Always drive power/angle for mouse aimbot so throw matches beam
                power = math.clamp(calcPower, 0, 95)
                if autoAngle.Value or true then
                    angle = math.clamp(calcAngle, -15, 90)
                end
                if not autoPower.Value and not (always95Power and always95Power.Value) then
                    power = math.clamp(calcPower, 0, 95)
                end
                
                local safePower = tonumber(power) or 60
                local safeAngle = tonumber(angle) or 45
                local angleRad = tonumber(math.rad(safeAngle)) or 0
                
                local hDirRaw = Vector3.new(targetPos.X - headPos.X, 0, targetPos.Z - headPos.Z)
                local hDir = hDirRaw.Magnitude > 0.01 and hDirRaw.Unit or hrp.CFrame.LookVector
                
                local dirVelocity = (hDir * (tonumber(math.cos(angleRad)) or 1) + Vector3.new(0, tonumber(math.sin(angleRad)) or 0, 0)) * safePower
                direction = dirVelocity.Unit * safePower
                
                local hVel = safePower * (tonumber(math.cos(angleRad)) or 1)
                if hVel > 0.1 then
                    local xDist = tonumber(Vector3.new(targetPos.X - headPos.X, 0, targetPos.Z - headPos.Z).Magnitude) or 0
                    airtime = xDist / hVel
                else
                    airtime = 0
                end
                
                targetLeadPos = targetPos
            else
                target = newTarget or lastValidTarget
                updateHighlights(true)
                if target and hrp then
                    local tHRP = target:FindFirstChild('HumanoidRootPart')
                    if tHRP then
                        if autoSelectThrowMode.Value then
                            local m = calculateRouteDirection(target)
                            for i = 1, #ModeOrder do
                                if ModeOrder[i] == m then
                                    modeIndex = i
                                    break
                                end
                            end
                            
                            local targetCurrentRoute = select(1, findRoute(target))
                            if ModeOrder[modeIndex] == 'Bullet' and (targetCurrentRoute == 'go/fade' or targetCurrentRoute == 'post/corner') then
                                for i = 1, #ModeOrder do
                                    if ModeOrder[i] == 'Mag' then
                                        modeIndex = i
                                        break
                                    end
                                end
                            end
                        end
                        
                        autoAim(tHRP)
                    end
                end
            end
        else
            target = nil
            updateHighlights(false)
        end
        
        if autoChangePowerUI.Value then
            if ballGui and ballGui:FindFirstChild('Frame0') then
                local frame0 = ballGui.Frame0
                local safePower = tonumber(power) or 60
                if safePower ~= safePower then safePower = 60 end
                
                local displayPower = math.round(safePower / 5) * 5
                
                local txt = frame0:FindFirstChildOfClass('TextLabel')
                if txt then txt.Text = tostring(math.floor(displayPower)) end
                
                local frames = frame0:GetChildren()
                for i = 1, #frames do
                    local frame = frames[i]
                    if frame.Name ~= 'Disp' then
                        local frameNum = tonumber(frame.Name) or 0
                        frame.BackgroundTransparency = ((tonumber(frameNum) or 0) <= (tonumber(displayPower) or 0)) and 0 or 0.9
                    end
                end
            end
        end
        
        -- SmartFit retouch
        do
            local d = 30
            if target and target.Character and target.Character:FindFirstChild('HumanoidRootPart') and lp.Character and lp.Character:FindFirstChild('HumanoidRootPart') then
                d = (target.Character.HumanoidRootPart.Position - lp.Character.HumanoidRootPart.Position).Magnitude
            end
            if smartFit and smartFit.Value then
                power, angle = applySmartFit(d, tonumber(power) or 60, tonumber(angle) or 30, lastCoverageDB)
            end
        end
        if manualPowerLock and manualPowerLock.Value then
            -- user locks power; do not force 95 / high power
        elseif (perfectThrow and perfectThrow.Value) or (always95Power and always95Power.Value) then
            power = 95
        elseif (forceThrow and forceThrow.Value) or (highPowerOnly and highPowerOnly.Value) then
            power = math.max(tonumber(power) or 60, 90)
        end
        -- Always 95 apply
        local safePowForCard = tonumber(power) or 60
        if safePowForCard ~= safePowForCard then safePowForCard = 60 end
        
        if HUDCards['Angle'] then 
            local forceAutoAngle = (ModeOrder[modeIndex] == 'Bullet' or (target and findRoute(target) == 'slant' or findRoute(target) == 'drag' or findRoute(target) == 'in/out' or findRoute(target) == 'flat' or findRoute(target) == 'hitch' or findRoute(target) == 'curl/comeback') or (tonumber(power) or 60) == 95 or highPowerOnly.Value)
            if not autoAngle.Value and not forceAutoAngle then
                HUDCards['Angle'].Text = tostring(math.floor(tonumber(customHeight.Value) or 0))
            else
                HUDCards['Angle'].Text = tostring(math.floor(tonumber(angle) or 45)) 
            end
        end
        
        if HUDCards['Power'] then HUDCards['Power'].Text = string.format('%.0f', safePowForCard) end
        if HUDCards['Airtime'] then HUDCards['Airtime'].Text = string.format('%.1fs', tonumber(airtime) or 0) end
        if HUDCards['Throw Type'] then HUDCards['Throw Type'].Text = tostring(ModeOrder[modeIndex] or 'N/A') end
        
        if HUDCards['Player'] then
            if throwAimbot.Value then
                HUDCards['Player'].Text = 'MOUSE'
            elseif target then
                local distStr = ''
                pcall(function()
                    local myHRP = lp.Character and lp.Character:FindFirstChild('HumanoidRootPart')
                    local tHRP = target.Character and target.Character:FindFirstChild('HumanoidRootPart')
                    if myHRP and tHRP then
                        distStr = string.format(' (%.0f)', (tHRP.Position - myHRP.Position).Magnitude)
                    end
                end)
                HUDCards['Player'].Text = tostring(target.Name) .. distStr
            else
                HUDCards['Player'].Text = 'NONE'
            end
        end

        if updateThrowStatus then
            local showStatus = enableQbAimbot.Value and (target ~= nil or throwAimbot.Value)
            pcall(updateThrowStatus, showStatus, target)
        end
    else
        updateHUDVisibility(false)
        updateHighlights(false)
        target = nil
        lastValidTarget = nil
    end

    -- Nova: beam clearer; mouse beam vs receiver beam
    local lineOn = (not throwLineViz) or throwLineViz.Value
    local showBeam = lineOn and isTracking and hasFootball and (
        (throwAimbot and throwAimbot.Value) or (enableQbAimbot and enableQbAimbot.Value and not (throwAimbot and throwAimbot.Value))
    )
    if beam and showBeam then
        beam.Enabled = true
        beam.Width0 = 1.35
        beam.Width1 = 1.0
        beam.Color = ColorSequence.new(Color3.fromRGB(255, 185, 70))
        local startOrigin = head.Position
        local safePowerForBeam = tonumber(power) or 60
        local drawDir = direction or Vector3.new(0, 1, 0)
        
        if throwAimbot.Value then
            if (tonumber(drawDir.Magnitude) or 0) < 0.1 then
                drawDir = Vector3.new(0, 1, 0) * safePowerForBeam
            end
        elseif not target or not targetLeadPos then
            local mouseRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
            drawDir = mouseRay.Direction.Unit * safePowerForBeam
            direction = drawDir
        else
            if (tonumber(drawDir.Magnitude) or 0) < 0.1 then
                drawDir = Vector3.new(0, 1, 0) * safePowerForBeam
            end
        end
        
        local safeAirtime = math.max(tonumber(airtime) or 0.1, 0.1)
        
        local curve0, curve1, cf1, cf2 = beamProjectile(Vector3.new(0,-28,0), drawDir, startOrigin + (drawDir.Unit * 5), safeAirtime)
        
        beam.CurveSize0 = curve0
        beam.CurveSize1 = curve1
        
        if attach0 and attach1 then
            attach0.WorldCFrame = cf1
            attach1.WorldCFrame = cf2
            
            attach0.WorldPosition = Vector3.new(cf1.X, cf1.Y, cf1.Z)
            attach1.WorldPosition = Vector3.new(cf2.X, cf2.Y, cf2.Z)
            
            if posPart then posPart.Position = Vector3.new(attach1.WorldPosition.X, attach1.WorldPosition.Y, attach1.WorldPosition.Z) end
        end
    else
        if beam then pcall(function() beam.Enabled = false end) end
        if posPart then posPart.Position = Vector3.new(0, -9999, 0) end
        if attach0 then attach0.WorldPosition = Vector3.new(0, -9999, 0) end
        if attach1 then attach1.WorldPosition = Vector3.new(0, -9999, 0) end
    end
end)

local CatchingTab = Window:CreateTab({ Name = 'Catching', Icon = 'rbxassetid://6034227067' })



ballResize = CatchingTab:CreateToggle({
    Name = 'Ball Resize',
    Default = false,
    Tip = 'Client resize of nearby footballs.',
})
ballResizeValue = CatchingTab:CreateSlider({
    Name = 'Ball Size',
    Min = 0.5,
    Max = 5,
    Default = 1,
    Increment = 0.1,
})

catchResize = CatchingTab:CreateToggle({
    Name = 'Hand Size',
    Default = false,
    Tip = 'Scales catch/hand parts for reach.',
})
catchResizeValue = CatchingTab:CreateSlider({
    Name = 'Hand Size Amount',
    Min = 1,
    Max = 15,
    Default = 2,
    Increment = 0.1,
})

physicsMag = CatchingTab:CreateToggle({
    Name = 'Physics Mag',
    Default = false,
    Tip = 'Pulls you with velocity toward airborne balls.',
})
physicsMagPower = CatchingTab:CreateSlider({
    Name = 'Physics Mag Power',
    Min = 1,
    Max = 40,
    Default = 18,
    Increment = 1,
})

autoTouch = CatchingTab:CreateToggle({
    Name = 'Auto Touch',
    Default = false,
    Tip = 'Touches nearby football with catch parts automatically.',
})

task.spawn(function()
    while true do
        task.wait(0.05)
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild('HumanoidRootPart')
        if not hrp then continue end

        if catchResize and catchResize.Value then
            local sc = tonumber(catchResizeValue.Value) or 2
            for _, p in ipairs(char:GetChildren()) do
                if p:IsA('BasePart') then
                    local n = p.Name:lower()
                    if n:find('catch') or n:find('hand') then
                        pcall(function()
                            p.Size = Vector3.new(sc, sc * 0.6, sc * 0.4)
                        end)
                    end
                end
            end
        end

        for _, ball in ipairs(workspace:GetChildren()) do
            if not ball:IsA('BasePart') or ball.Name ~= 'Football' then continue end
            if ballResize and ballResize.Value then
                pcall(function()
                    local sz = tonumber(ballResizeValue.Value) or 1
                    ball.Size = Vector3.new(1.2 * sz, 0.7 * sz, 0.7 * sz)
                end)
            end
            local dist = (ball.Position - hrp.Position).Magnitude
            if physicsMag and physicsMag.Value and dist < 25 and ball.AssemblyLinearVelocity.Magnitude > 2 then
                local dir = (ball.Position - hrp.Position)
                if dir.Magnitude > 0.1 then
                    local pow = tonumber(physicsMagPower.Value) or 18
                    local vy = hrp.AssemblyLinearVelocity.Y
                    hrp.AssemblyLinearVelocity = dir.Unit * pow + Vector3.new(0, vy * 0.3, 0)
                end
            end
            if autoTouch and autoTouch.Value and dist < 12 and firetouchinterest then
                for _, p in ipairs(char:GetChildren()) do
                    if p:IsA('BasePart') and (p.Name:lower():find('catch') or p.Name:lower():find('hand')) then
                        pcall(firetouchinterest, p, ball, 0)
                        pcall(firetouchinterest, p, ball, 1)
                    end
                end
            end
        end
    end
end)



desyncMagnet = CatchingTab:CreateToggle({
    Name = 'Desync Magnet',
    Default = false,
    Tip = 'Blatant: short CFrame snap toward ball in range (use carefully).',
})
desyncMagnetRange = CatchingTab:CreateSlider({
    Name = 'Desync Mag Range',
    Min = 2,
    Max = 20,
    Default = 8,
    Increment = 0.5,
})

task.spawn(function()
    while true do
        task.wait(0.06)
        if not desyncMagnet or not desyncMagnet.Value then continue end
        local char = player.Character
        local hrp = char and char:FindFirstChild('HumanoidRootPart')
        if not hrp then continue end
        local range = tonumber(desyncMagnetRange.Value) or 8
        for _, ball in ipairs(workspace:GetChildren()) do
            if not ball:IsA('BasePart') or ball.Name ~= 'Football' then continue end
            if ball:IsDescendantOf(char) then continue end
            local d = (ball.Position - hrp.Position).Magnitude
            if d < range and d > 0.5 then
                local to = (ball.Position - hrp.Position)
                hrp.CFrame = hrp.CFrame + to.Unit * math.min(d * 0.45, 4)
                if firetouchinterest then
                    for _, p in ipairs(char:GetChildren()) do
                        if p:IsA('BasePart') and (p.Name:lower():find('catch') or p.Name:lower():find('hand')) then
                            pcall(firetouchinterest, p, ball, 0)
                            pcall(firetouchinterest, p, ball, 1)
                        end
                    end
                end
                break
            end
        end
    end
end)


magAngleLock = CatchingTab:CreateToggle({
    Name = 'Mag Angle Lock',
    Default = false,
    Tip = 'Only magnet when looking roughly toward the ball.',
})
magAngleWindow = CatchingTab:CreateSlider({
    Name = 'Mag Angle Window',
    Min = 20,
    Max = 180,
    Default = 90,
    Increment = 5,
    Tip = 'Degrees of look cone for magnets.',
})

footballMagnets = CatchingTab:CreateToggle({
    Name = 'Enable Football Magnets',
    Default = false,
    Tip = 'Registers catches via touch on catch parts when the ball is in range. Does not move the ball in Legit/League.',
})

freeFallCheck = CatchingTab:CreateToggle({
    Name = 'Magnets Freefall Check',
    Default = false,
    Tip = 'Only activates football magnets while the ball is airborne.',
})

showCatchHitbox = CatchingTab:CreateToggle({
    Name = 'Show Magnets Radius',
    Default = false,
    Tip = 'Displays the football magnets catch radius.',
})

magnetsRadius = CatchingTab:CreateSlider({
    Name = 'Magnets Catch Distance',
    Min = 0,
    Max = 25,
    Default = 12,
    Increment = 0.1,
    Suffix = '',
    Tip = 'Sets the maximum distance footballs can be caught from.',
})

magnetsDelay = CatchingTab:CreateSlider({
    Name = 'Magnets Catch Delay',
    Min = 0,
    Max = 1,
    Default = 0.05,
    Increment = 0.1,
    Suffix = '',
    Tip = 'Sets the delay before football magnets activate.',
})

magsType = CatchingTab:CreateDropdown({
    Name = 'Magnets Type',
    Options = {'Custom', 'Blatant', 'League', 'Legit', 'Dynamic'},
    Default = 'Custom',
    Tip = 'Selects the football magnets behavior preset.',
})

magHitboxShape = CatchingTab:CreateDropdown({
    Name = 'Mag Hitbox Shape',
    Options = {'Sphere', 'Box'},
    Default = 'Sphere',
    Tip = 'Shape used when visualizing magnet range (Sphere / Box).',
})

player = lp -- already LocalPlayer

local part = Instance.new('Part')
part.Color = Color3.fromRGB(255, 255, 255)
part.Shape = Enum.PartType.Ball
part.Material = Enum.Material.ForceField
part.CastShadow = false
part.Anchored = true
part.CanCollide = false

local findClosestBall = function()
    local character = player.Character
    if not character then return end

    local humanoidRootPart = character:FindFirstChild('HumanoidRootPart')
    if not humanoidRootPart then return end

    local dist = math.huge
    local ball = nil

    for _, v in next, workspace:GetChildren() do
        if not v:IsA('BasePart') then continue end
        if v.Name ~= 'Football' then continue end

        local distance = (v.Position - humanoidRootPart.Position).Magnitude

        if distance < dist then
            dist = distance
            ball = v
        end
    end

    return ball
end


local function isPlayActive()
    local ok, active = pcall(function()
        local rs = game:GetService('ReplicatedStorage')
        local flags = rs:FindFirstChild('Flags')
        if not flags then return true end
        local st = flags:FindFirstChild('Status') or flags:FindFirstChild('StatusTag')
        if not st then return true end
        local v = tostring(st.Value or ''):lower()
        if v == '' or v == 'preplay' or v == 'pre play' or v == 'dead' or v == 'replay' or v == 'timeout' or v == 'halftime' then
            return false
        end
        return true
    end)
    if not ok then return true end
    return active
end

local selectedRange = function()
	local range = tonumber(magnetsRadius.Value) or 0
	if range <= 0 then range = 12 end
	local mode = tostring(magsType.Value or 'Custom'):lower()

	if mode == 'legit' then
		return range * 0.5
	elseif mode == 'league' then
		return range * 0.7
	elseif mode == 'blatant' then
		return range * 1.5
	elseif mode == 'dynamic' then
		local ball = findClosestBall and findClosestBall()
		local spd = 0
		pcall(function()
			if ball then spd = ball.AssemblyLinearVelocity.Magnitude end
		end)
		return range * (1 + math.clamp(spd / 80, 0, 0.5))
	end

	return range
end

-- Retouched magnets (Cons-style): touch assist only, throttled, no part tween (anti-freeze)
task.spawn(function()
    local lastTouch = 0
    local hb = game:GetService('RunService').Heartbeat
    while true do
        local active = footballMagnets.Value
        if active then
            hb:Wait() -- FPS-independent (Nova-style)
        else
            task.wait(0.12)
        end

        local character = player.Character
        if not character then continue end

        local humanoid = character:FindFirstChildOfClass('Humanoid')
        if not humanoid then continue end

        local ball = findClosestBall()
        if not ball then
            part.Parent = nil
            continue
        end

        local range = selectedRange()
        if range <= 0 then continue end

        pcall(function()
            part.Size = Vector3.new(range, range, range)
            part.CFrame = CFrame.new(ball.Position)
            part.Parent = (active and showCatchHitbox.Value) and workspace.Terrain or nil
        end)

        if not active then continue end
        -- Yuna-style: no magnets during pre/dead/replay
        if not isPlayActive() then
            part.Parent = nil
            continue
        end
        if freeFallCheck.Value then
            local st = humanoid:GetState()
            if st ~= Enum.HumanoidStateType.Freefall and st ~= Enum.HumanoidStateType.Jumping then
                continue
            end
        end

        -- skip held / own pass / grounded (Nova-style: ignore your throws)
        local skip = false
        pcall(function()
            if ball:GetAttribute('LocalAimbotBall') then skip = true end
            if ball:GetAttribute('YuriOwnPass') then skip = true end
            if ball:IsDescendantOf(character) then skip = true end
            for _, pl in ipairs(game:GetService('Players'):GetPlayers()) do
                if pl.Character and ball:IsDescendantOf(pl.Character) then skip = true break end
            end
            if ball.AssemblyLinearVelocity.Magnitude < 2 and ball.Position.Y < 4 then skip = true end
        end)
        if skip then
            part.Parent = nil
            continue
        end

        local now = os.clock()
        local delay = tonumber(magnetsDelay.Value) or 0
        if delay > 0 and (now - lastTouch) < delay then continue end

        for _, v in next, character:GetChildren() do
            if not v:IsA('BasePart') then continue end
            local n = v.Name:lower()
            if not (n:find('catch') or n:find('hand')) then continue end

            local distance = (ball.Position - v.Position).Magnitude
            if distance < range then
                -- no tween on catch parts (was freezing / desync)
                if firetouchinterest then
                    pcall(firetouchinterest, v, ball, 0)
                    pcall(firetouchinterest, v, ball, 1)
                end
                lastTouch = now
            end
        end
    end
end)

CatchingTab:CreateDivider()

magEnhancer = CatchingTab:CreateToggle({
    Name = 'Enable Mag Enhancer',
    Default = false,
    Tip = 'Widens the angle/distance window where catch touches still register.',
})

magEnhancerRadius = CatchingTab:CreateSlider({
    Name = 'Mag Catch Distance',
    Min = 0,
    Max = 25,
    Default = 10,
    Increment = 0.1,
    Suffix = '',
    Tip = 'Sets the maximum distance the enhancer can assist catches.',
})

magEnhancerMaxAngle = CatchingTab:CreateSlider({
    Name = 'Mag Max Angle',
    Min = 50,
    Max = 70,
    Default = 50,
    Increment = 0.1,
    Suffix = '',
    Tip = 'Sets the maximum catch angle the enhancer can assist.',
})

task.spawn(function()
    while true do
        task.wait()

        if not magEnhancer.Value then continue end

        local character = player.Character
        if not character then continue end

        local humanoidRootPart = character:FindFirstChild('HumanoidRootPart')
        if not humanoidRootPart then continue end

        local ball = findClosestBall()
        if not ball then continue end

        -- only assist freefalling / airborne balls (not stuck in hand)
        local ballStateOk = true
        pcall(function()
            if ball:GetAttribute('LocalAimbotBall') then ballStateOk = false end
        end)
        if not ballStateOk then continue end

        local verticalDistance = ball.Position.Y - humanoidRootPart.Position.Y
        if verticalDistance > magEnhancerMaxAngle.Value then
            continue
        end

        local toBall = ball.Position - humanoidRootPart.Position
        if toBall.Magnitude < 0.05 then continue end
        local direction = toBall.Unit
        local lookVector = humanoidRootPart.CFrame.LookVector
        local dot = lookVector:Dot(direction)

        for _, v in next, character:GetChildren() do
            if not v:IsA('BasePart') then continue end
            local n = v.Name:lower()
            if not (n:find('catch') or n:find('hand')) then continue end

            local distance = (ball.Position - v.Position).Magnitude
            if dot > 0.15 and distance <= math.max(magEnhancerRadius.Value, 0.5) then
                -- touch only (no zero-time tween yank - that was breaking mags)
                if firetouchinterest then
                    pcall(firetouchinterest, v, ball, 0)
                    pcall(firetouchinterest, v, ball, 1)
                end
            end
        end
    end
end)
    
CatchingTab:CreateDivider()

pullVector = CatchingTab:CreateToggle({
    Name = 'Enable Pull Vector',
    Default = false,
    Tip = 'Moves YOU toward the ball (or intercept point) for contested catches.',
})

pullVectorRadius = CatchingTab:CreateSlider({
    Name = 'Pull Vector Radius',
    Min = 0,
    Max = 45,
    Default = 20,
    Increment = 0.1,
    Suffix = '',
    Tip = 'Sets the maximum distance footballs can be pulled from.',
})

pullVectorPower = CatchingTab:CreateSlider({
    Name = 'Pull Vector Power',
    Min = 0,
    Max = 5,
    Default = 2,
    Increment = 0.1,
    Suffix = '',
    Tip = 'Controls how strongly footballs are pulled toward you.',
})

pullVectorCooldown = CatchingTab:CreateSlider({
    Name = 'Pull Vector Cooldown',
    Min = 0,
    Max = 1,
    Default = 0.05,
    Increment = 0.01,
    Tip = 'Delay between pull vector applications.',
})


pullVectorType = CatchingTab:CreateDropdown({
    Name = 'Pull Vector Type',
    Options = {'Velocity', 'Lerp', 'Teleport', 'Tween'},
    Default = 'Velocity',
    Tip = 'FF2-style: Velocity / Lerp / Teleport (desync-style).',
})

pullPredictionSpot = CatchingTab:CreateToggle({
    Name = 'Show Pull Prediction Spot',
    Default = false,
    Tip = 'Shows the point on/near the ball you are pulling toward.',
})

task.spawn(function()
    local marker
    while true do
        task.wait(0.05)
        if not pullPredictionSpot or not pullPredictionSpot.Value or not pullVector or not pullVector.Value then
            if marker then pcall(function() marker:Destroy() end) marker = nil end
            continue
        end
        local char = player.Character
        local hrp = char and char:FindFirstChild('HumanoidRootPart')
        if not hrp then continue end
        local ball = nil
        local bd = tonumber(pullVectorRadius and pullVectorRadius.Value) or 45
        for _, v in ipairs(workspace:GetChildren()) do
            if v:IsA('BasePart') and v.Name == 'Football' then
                local d = (v.Position - hrp.Position).Magnitude
                if d < bd then bd = d ball = v end
            end
        end
        if ball then
            if not marker then
                marker = Instance.new('Part')
                marker.Shape = Enum.PartType.Ball
                marker.Size = Vector3.new(1.2, 1.2, 1.2)
                marker.Anchored = true
                marker.CanCollide = false
                marker.Material = Enum.Material.Neon
                marker.Color = Color3.fromRGB(245, 230, 200)
                marker.Transparency = 0.35
                marker.Parent = workspace.Terrain
            end
            marker.Position = ball.Position + Vector3.new(0, 1.2, 0)
        elseif marker then
            pcall(function() marker:Destroy() end)
            marker = nil
        end
    end
end)


task.spawn(function()
    while true do
        task.wait(pullVector.Value and math.max(0.02, (pullVectorCooldown and tonumber(pullVectorCooldown.Value)) or 0.05) or 0.12)

        if not pullVector.Value then continue end

        local character = player.Character
        if not character then continue end

        local humanoidRootPart = character:FindFirstChild('HumanoidRootPart')
        if not humanoidRootPart then continue end

        local ball = findClosestBall()
        if not ball then continue end

        local distance = (ball.Position - humanoidRootPart.Position).Magnitude
        if distance > pullVectorRadius.Value then continue end

        -- target: live ball, or intercept prediction if enabled
        local targetPos = ball.Position + Vector3.new(0, 1.2, 0)
        if pullIntercept and pullIntercept.Value then
            local vel = ball.AssemblyLinearVelocity
            local ping = 0.05
            pcall(function()
                ping = game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue() / 1000
            end)
            local t = math.clamp(ping + 0.08, 0.05, 0.35)
            targetPos = ball.Position + vel * t + Vector3.new(0, 1.0, 0)
        end

        local direction = (targetPos - humanoidRootPart.Position)
        if direction.Magnitude < 0.05 then continue end
        direction = direction.Unit
        local typ = (pullVectorType and pullVectorType.Value) or 'Velocity'
        local pow = (tonumber(pullVectorPower.Value) or 1) * 25
        if typ == 'Teleport' then
            humanoidRootPart.CFrame = CFrame.new(targetPos)
        elseif typ == 'Lerp' then
            humanoidRootPart.CFrame = humanoidRootPart.CFrame:Lerp(
                CFrame.new(targetPos),
                math.clamp(0.08 * (tonumber(pullVectorPower.Value) or 1), 0.02, 0.35)
            )
        elseif typ == 'Tween' then
            pcall(function()
                game:GetService('TweenService'):Create(
                    humanoidRootPart,
                    TweenInfo.new(math.clamp(0.12 / math.max(tonumber(pullVectorPower.Value) or 1, 0.2), 0.04, 0.25), Enum.EasingStyle.Linear),
                    {CFrame = CFrame.new(targetPos)}
                ):Play()
            end)
        else
            humanoidRootPart.AssemblyLinearVelocity = direction * pow
        end
    end
end)

CatchingTab:CreateDivider()

increaseArmSize = CatchingTab:CreateToggle({
    Name = 'Increase Arm Size',
    Default = false,
    Tip = 'Increases arm size to improve catch reach.',
})

armSizeValue = CatchingTab:CreateSlider({
    Name = 'Arm Size Value',
    Min = 2,
    Max = 25,
    Default = 2,
    Increment = 0.1,
    Suffix = '',
    Tip = 'Sets the size applied to both arms.',
})

task.spawn(function()
    while true do
        task.wait()

        local character = player.Character
        if not character then continue end

        for _, v in next, character:GetChildren() do
            if not v:IsA('BasePart') then continue end
            local ln = v.Name:lower()
            if not (ln:find('arm') or ln:find('hand')) then continue end
            if ln:find('humanoid') then continue end
            local y = (increaseArmSize and increaseArmSize.Value and tonumber(armSizeValue and armSizeValue.Value)) or nil
            if y then
                pcall(function()
                    v.Size = Vector3.new(math.max(v.Size.X, 1), y, math.max(v.Size.Z, 1))
                end)
            end
        end
    end
end)
    
local PlayerTab = Window:CreateTab({ Name = 'Player', Icon = 'rbxassetid://103807548355126' })



antiAce = PlayerTab:CreateToggle({
    Name = 'Anti Ace',
    Default = false,
    Tip = 'Sidesteps away from nearby defenders when you have the ball.',
})
antiAceRadius = PlayerTab:CreateSlider({
    Name = 'Anti Ace Radius',
    Min = 5,
    Max = 80,
    Default = 20,
    Increment = 1,
})

task.spawn(function()
    while true do
        task.wait(0.07)
        if not antiAce or not antiAce.Value then continue end
        local char = player.Character
        local hrp = char and char:FindFirstChild('HumanoidRootPart')
        local hum = char and char:FindFirstChildOfClass('Humanoid')
        if not hrp or not hum or not char:FindFirstChild('Football') then continue end
        local rad = tonumber(antiAceRadius.Value) or 20
        local push = Vector3.zero
        local n = 0
        for _, plr in ipairs(players:GetPlayers()) do
            if plr == player then continue end
            if player.Team and plr.Team and plr.Team == player.Team then continue end
            local thrp = plr.Character and plr.Character:FindFirstChild('HumanoidRootPart')
            if not thrp then continue end
            local off = hrp.Position - thrp.Position
            local d = off.Magnitude
            if d < rad and d > 0.1 then
                push = push + off.Unit * ((rad - d) / rad)
                n = n + 1
            end
        end
        if n > 0 then
            push = Vector3.new(push.X, 0, push.Z)
            if push.Magnitude > 0.1 then
                hum:MoveTo(hrp.Position + push.Unit * 6)
            end
        end
    end
end)


flyToggle = PlayerTab:CreateToggle({
    Name = 'Fly',
    Default = false,
    Tip = 'WASD/camera fly while enabled (local).',
})
flySpeed = PlayerTab:CreateSlider({
    Name = 'Fly Speed',
    Min = 16,
    Max = 80,
    Default = 40,
    Increment = 1,
})

infiniteJump = PlayerTab:CreateToggle({
    Name = 'Infinite Jump',
    Default = false,
    Tip = 'Jump again while airborne.',
})

task.spawn(function()
    local bv
    while true do
        task.wait(0.03)
        local char = player.Character
        local hrp = char and char:FindFirstChild('HumanoidRootPart')
        local hum = char and char:FindFirstChildOfClass('Humanoid')
        if not hrp or not hum then
            if bv then pcall(function() bv:Destroy() end) bv = nil end
            continue
        end
        if flyToggle and flyToggle.Value then
            if not bv or bv.Parent ~= hrp then
                if bv then pcall(function() bv:Destroy() end) end
                bv = Instance.new('BodyVelocity')
                bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                bv.P = 1e4
                bv.Velocity = Vector3.zero
                bv.Parent = hrp
            end
            local cam = workspace.CurrentCamera
            local look = cam and cam.CFrame.LookVector or hrp.CFrame.LookVector
            local right = cam and cam.CFrame.RightVector or hrp.CFrame.RightVector
            local dir = Vector3.zero
            if userInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + look end
            if userInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - look end
            if userInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - right end
            if userInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + right end
            if userInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
            if userInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
            local spd = tonumber(flySpeed and flySpeed.Value) or 40
            if dir.Magnitude > 0 then
                bv.Velocity = dir.Unit * spd
            else
                bv.Velocity = Vector3.zero
            end
            hum.PlatformStand = true
        else
            if bv then pcall(function() bv:Destroy() end) bv = nil end
            if hum.PlatformStand then hum.PlatformStand = false end
        end
    end
end)

userInputService.JumpRequest:Connect(function()
    if not infiniteJump or not infiniteJump.Value then return end
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass('Humanoid')
    if hum then
        pcall(function()
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end
end)


hipHeight = PlayerTab:CreateToggle({
    Name = 'Custom Hip Height',
    Default = false,
})
hipHeightValue = PlayerTab:CreateSlider({
    Name = 'Hip Height Value',
    Min = 0,
    Max = 4,
    Default = 2,
    Increment = 0.05,
})
alwaysJump = PlayerTab:CreateToggle({
    Name = 'Always Jump',
    Default = false,
    Tip = 'Keeps jump state available.',
})
lookAtBall = PlayerTab:CreateToggle({
    Name = 'Look At Ball',
    Default = false,
    Tip = 'Yaw faces nearest airborne football.',
})

task.spawn(function()
    while true do
        task.wait(0.05)
        local char = player.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass('Humanoid')
        local hrp = char:FindFirstChild('HumanoidRootPart')
        if hipHeight and hipHeight.Value and hum then
            pcall(function() hum.HipHeight = tonumber(hipHeightValue.Value) or 2 end)
        end
        if alwaysJump and alwaysJump.Value and hum then
            pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) end)
        end
        if lookAtBall and lookAtBall.Value and hrp then
            local best, bd = nil, 80
            for _, ball in ipairs(workspace:GetChildren()) do
                if ball:IsA('BasePart') and ball.Name == 'Football' then
                    local d = (ball.Position - hrp.Position).Magnitude
                    if d < bd and ball.Position.Y > 2 then
                        bd = d
                        best = ball
                    end
                end
            end
            if best then
                local look = Vector3.new(best.Position.X - hrp.Position.X, 0, best.Position.Z - hrp.Position.Z)
                if look.Magnitude > 0.1 then
                    hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + look.Unit)
                end
            end
        end
    end
end)



customWalkSpeed = PlayerTab:CreateToggle({
    Name = 'Custom WalkSpeed',
    Default = false,
    Tip = 'Overrides your character movement speed.',
})

walkSpeedValue = PlayerTab:CreateSlider({
    Name = 'WalkSpeed Value',
    Min = 16,
    Max = 28,
    Default = 22,
    Increment = 0.1,
    Suffix = '',
    Tip = 'Sets the movement speed value. Values over 23 use smoother CFrame assist.',
})

walkspeedType = PlayerTab:CreateDropdown({
    Name = 'WalkSpeed Type',
    Options = {'Normal', 'CFrame'},
    Default = 'Normal',
    Tip = 'Selects how movement speed is applied.',
})

task.spawn(function()
    local last = tick()
    while true do
        task.wait()
        local now = tick()
        local dt = math.clamp(now - last, 0, 0.05)
        last = now

        if not customWalkSpeed.Value then continue end

        local character = player.Character
        if not character then continue end

        local humanoid = character:FindFirstChildOfClass('Humanoid')
        if not humanoid then continue end
        if humanoid.PlatformStand then continue end
        if humanoid.WalkSpeed == 0 then continue end

        local root = character:FindFirstChild('HumanoidRootPart')
        if not root then continue end

        local md = humanoid.MoveDirection
        local direction = Vector3.new(md.X, 0, md.Z)
        if direction.Magnitude <= 0.05 then continue end
        direction = direction.Unit

        local targetSpeed = walkSpeedValue.Value
        local useCF = (walkspeedType.Value == 'CFrame') or (targetSpeed > 23)

        if humanoid:GetState() == Enum.HumanoidStateType.Running then
            local scale = targetSpeed / math.max(humanoid.WalkSpeed, 1)
            local animator = humanoid:FindFirstChildOfClass('Animator')
            if animator then
                for _, track in next, animator:GetPlayingAnimationTracks() do
                    pcall(function() track:AdjustSpeed(scale) end)
                end
            end
        end

        -- Aikeo: fixed running backwards - align facing + velocity with MoveDirection only
        local flatLook = Vector3.new(direction.X, 0, direction.Z)
        if flatLook.Magnitude > 0.05 then
            local face = CFrame.new(root.Position, root.Position + flatLook)
            root.CFrame = face
        end
        local vy = root.AssemblyLinearVelocity.Y
        if useCF then
            local step = direction * targetSpeed * dt
            root.CFrame = root.CFrame + step
            -- keep horizontal velocity WITH move dir (never opposite)
            root.AssemblyLinearVelocity = Vector3.new(direction.X * targetSpeed * 0.5, vy, direction.Z * targetSpeed * 0.5)
        else
            root.AssemblyLinearVelocity = Vector3.new(direction.X * targetSpeed, vy, direction.Z * targetSpeed)
        end
    end
end)

PlayerTab:CreateDivider()

customJumpPower = PlayerTab:CreateToggle({
    Name = 'Custom JumpPower',
    Default = false,
    Tip = 'Overrides your character jump power.',
})

jumpPowerValue = PlayerTab:CreateSlider({
    Name = 'JumpPower Value',
    Min = 50,
    Max = 70,
    Default = 50,
    Increment = 0.1,
    Suffix = '',
    Tip = 'Sets the custom jump power.',
})

do
    local jumpConn
    local function bindJump(char)
        if jumpConn then jumpConn:Disconnect() jumpConn = nil end
        local humanoid = char and char:FindFirstChildOfClass('Humanoid')
        local root = char and char:FindFirstChild('HumanoidRootPart')
        if not humanoid or not root then return end
        jumpConn = humanoid.StateChanged:Connect(function(_, new)
            if not customJumpPower.Value then return end
            if new ~= Enum.HumanoidStateType.Jumping then return end
            task.defer(function()
                if not root.Parent then return end
                local v = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = Vector3.new(v.X, jumpPowerValue.Value, v.Z)
            end)
        end)
    end
    if player.Character then bindJump(player.Character) end
    player.CharacterAdded:Connect(bindJump)

    task.spawn(function()
        while true do
            task.wait(0.1)
            if not customJumpPower.Value then continue end
            local character = player.Character
            if not character then continue end
            local humanoid = character:FindFirstChildOfClass('Humanoid')
            if not humanoid then continue end
            pcall(function()
                humanoid.UseJumpPower = true
                humanoid.JumpPower = jumpPowerValue.Value
            end)
        end
    end)
end
    
PlayerTab:CreateDivider()

angleEnhancer = PlayerTab:CreateToggle({
    Name = 'Angle Enhancer',
    Default = false,
    Tip = 'Boosts jump height when directional look changes while jumping.',
})

angleEnhancerIndicator = PlayerTab:CreateToggle({
    Name = 'Angle Enhancer Indicator',
    Default = false,
    Tip = 'Showsa notification when an angle boost is triggered.',
})
    
    autoFlip = PlayerTab:CreateToggle({
    Name = 'Auto Flip Before Landing',
    Default = false,
    Tip = 'Automatically adjusts player orientation before landing.',
})

angleEnhanceBoost = PlayerTab:CreateSlider({
    Name = 'Angle Boost Value',
    Min = 45,
    Max = 62,
    Default = 52,
    Increment = 0.1,
    Suffix = '',
    Tip = 'Vertical boost on look-change (capped; less strong than before).',
})

angleEnhancerType = PlayerTab:CreateDropdown({
    Name = 'Angle Enhancer Type',
    Options = {'Velocity', 'CFrame', 'Blend'},
    Default = 'Blend',
    Tip = 'How the angle boost is applied (FF2-style Value + Type).',
})
    
local lastTick = 0
local oldLookVector = nil
-- keep angle enhancer stable across respawns (Yuna fix)
player.CharacterAdded:Connect(function()
    oldLookVector = nil
    lastTick = 0
end)

task.spawn(function()
    while true do
        task.wait()

        if not angleEnhancer.Value then continue end

        local character = player.Character
        if not character then oldLookVector = nil continue end

        local humanoid = character:FindFirstChildOfClass('Humanoid')
        local hrp = character:FindFirstChild('HumanoidRootPart')
        if not humanoid or not hrp then oldLookVector = nil continue end

        local st = humanoid:GetState()
        if st ~= Enum.HumanoidStateType.Jumping and st ~= Enum.HumanoidStateType.Freefall then
            oldLookVector = hrp.CFrame.LookVector
            continue
        end

        local currentTime = tick()
        local newLookVector = hrp.CFrame.LookVector

        if not oldLookVector then
            oldLookVector = newLookVector
            lastTick = currentTime
            continue
        end

        local angleChange = math.acos(math.clamp(oldLookVector:Dot(newLookVector), -1, 1))
        local shiftLockEnabled = userInputService.MouseBehavior == Enum.MouseBehavior.LockCenter

        if currentTime - lastTick >= 0.2 and angleChange > math.rad(5) then
            lastTick = currentTime
            oldLookVector = newLookVector
        end

        -- toned down: needs clearer look change + cooldown + clamped boost
        if angleChange > math.rad(35) and (currentTime - lastTick) >= 0.45 and (currentTime - lastTick) <= 2.0 then
            lastTick = currentTime
            oldLookVector = newLookVector

            local vel = hrp.AssemblyLinearVelocity
            if vel.Y < 5 then continue end -- only while actually going up / near apex

            local boost = math.clamp(angleEnhanceBoost.Value, 40, 62)
            local typ = (angleEnhancerType and angleEnhancerType.Value) or 'Blend'
            if typ == 'Velocity' then
                hrp.AssemblyLinearVelocity = Vector3.new(vel.X, boost, vel.Z)
            elseif typ == 'CFrame' then
                hrp.CFrame = hrp.CFrame + Vector3.new(0, 0.35, 0)
                hrp.AssemblyLinearVelocity = Vector3.new(vel.X, math.max(vel.Y, boost * 0.85), vel.Z)
            else
                local newY = math.min(vel.Y + (boost - 50) * 0.55, boost)
                if newY > vel.Y then
                    hrp.AssemblyLinearVelocity = Vector3.new(vel.X, newY, vel.Z)
                end
            end

            if angleEnhancerIndicator.Value then
                local hint = Instance.new('Hint')
                hint.Text = 'Angled!'
                hint.Parent = workspace.Terrain
                task.delay(1.2, function()
                    if hint then hint:Destroy() end
                end)
            end
        end
    end
end)
    
local runtime, jumptime, hittime = 0, 0, 0
local arm, vLine, used, prevPs = false, nil, false, false
local seq = 0
local pack = nil

local xz = function(v: Vector3)
	local f = Vector3.new(v.X, 0, v.Z)
	return f.Magnitude > 0.001 and f.Unit or nil
end

local reset = function()
	if not pack then return end
	for _, o in next, { pack.spin, pack.ra, pack.pivot, pack.ha } do
		if o then o:Destroy() end
	end
	pack = nil
end

local flip = function(root: BasePart, head: BasePart)
	reset()

	local m = math.max(root.AssemblyMass, 1)

	local ha = Instance.new("Attachment")
	ha.Parent = head

	local pivot = Instance.new("AlignPosition")
	pivot.Mode = Enum.PositionAlignmentMode.OneAttachment
	pivot.Attachment0 = ha
	pivot.Position = head.Position + Vector3.new(0, 0.15, 0)
	pivot.MaxForce = 180000
	pivot.Responsiveness = 120
	pivot.RigidityEnabled = false
	pivot.ApplyAtCenterOfMass = false
	pivot.Parent = head

	local ra = Instance.new("Attachment")
	ra.Parent = root

	local spin = Instance.new("AngularVelocity")
	spin.Attachment0 = ra
	spin.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
	spin.AngularVelocity = Vector3.new(-9, 0, 0)
	spin.MaxTorque = 50000
	spin.Parent = root

	root:ApplyAngularImpulse(root.CFrame.RightVector * (-16 * m))

	pack = { ha = ha, pivot = pivot, ra = ra, spin = spin }
end

task.spawn(function()
	while true do
		task.wait()
	    
	    if not autoFlip.Value then continue end
	    
		local char = player.Character
		if not char then
			reset()
			arm, vLine, used, prevPs = false, nil, false, false
			continue
		end

		local hum = char:FindFirstChildOfClass("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local head = char:FindFirstChild("Head")

		if not hum or not hrp or not head then continue end

		local now = tick()

		if hum:GetState() == Enum.HumanoidStateType.Running then runtime = now end
		if hum:GetState() == Enum.HumanoidStateType.Jumping then jumptime = now end

		local ps = hum.PlatformStand
		if ps ~= prevPs then
			if ps then
				arm = (now - runtime <= 0.5) and (now - jumptime <= 0.7)
				vLine = xz(hrp.AssemblyLinearVelocity) or xz(hrp.CFrame.LookVector)
				used = false
			else
				arm, vLine, used = false, nil, false
				seq += 1
				reset()
			end
			prevPs = ps
		end

		if not ps or not arm or pack then continue end

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }

		local result = workspace:Raycast(head.Position, Vector3.new(0, -3, 0), params)
		local ground = result and result.Instance ~= nil

		if used or not ground or now - hittime < 0.12 then continue end

		local dist = result and (head.Position - result.Position).Magnitude or math.huge
		if dist > 1.6 then continue end

		local move = xz(hrp.AssemblyLinearVelocity) or vLine
		local face = xz(hrp.CFrame.LookVector)

		if not move or not face or face:Dot(move) < 0.78 then continue end

		hittime = now
		used = true
		seq += 1
		local k = seq

		flip(hrp, head)

		task.delay(0.24, function()
			if k == seq then
				reset()
			end
		end)
	end
end)

PlayerTab:CreateDivider()

PlayerTab:CreateButton({
    Name = 'Unlock All Gamepass',
    Tip = 'Enables all gamepass-related checks locally.',
    Callback = function()
        local replicatedFirst = game:GetService('ReplicatedFirst')

        local module
        local success = pcall(function()
            module = nil; pcall(function() local m = replicatedFirst:FindFirstChild('LocalSave'); if m then module = require(m) end end)
        end)

        if not success or not module then
            return
        end

        module.PlayerOwnsPass = function(a, b)
            return true
        end
    end
})

local PhysicsTab = Window:CreateTab({ Name = 'Physics', Icon = 'rbxassetid://11537490966' })
    
local boundaries = {}

if not isPractice then
    pcall(function()
        local models = workspace:FindFirstChild('Models')
        local bounds = models and models:FindFirstChild('Boundaries')
        if bounds then
            for i, v in next, bounds:GetChildren() do
                boundaries[#boundaries + 1] = v
            end
        end
    end)
end

antiBoundaries = PhysicsTab:CreateToggle({
    Name = 'No OOB (Anti Boundaries)',
    Default = false,
    Tip = 'FF2-style No OOB - prevents triggering out-of-bounds zones.',
    Callback = function(v)
        for i, b in next, boundaries do
            if b then
                b.Parent = not v and workspace.Models.Boundaries or nil
            end
        end
    end
})
    
    antiBench = PhysicsTab:CreateToggle({
    Name = 'Anti Bench',
    Default = false,
    Tip = 'Prevents automatic benching.',
})

task.spawn(function()
    while true do
        task.wait()

        if not antiBench.Value then continue end

        local playerGui = player:FindFirstChild('PlayerGui')
        if not playerGui then continue end

        local benchButton = playerGui:FindFirstChild('Benched', true)
        if not benchButton then continue end

        if benchButton.BackgroundColor3 == Color3.fromRGB(120, 120, 120) then
            replicatedStorage.Remotes.CharacterSoundEvent:FireServer('Game', 'ToggleBench')
        end
    end
end)
--[[
local scrambleWall = workspace:FindFirstChild('ScrambleWall')

antiQbBoundaries = PhysicsTab:CreateToggle({
    Name = 'Anti QB Boundaries',
    Default = false,
    Tip = 'Disables invisible QB boundary walls.',
    Callback = function(v)
        if not scrambleWall then return end
        scrambleWall.Parent = v and nil or workspace
    end
})
    ]]
PhysicsTab:CreateDivider()

antiJam = PhysicsTab:CreateToggle({
    Name = 'Anti Jam',
    Default = false,
    Tip = 'Reduces player collision while moving.',
})

antiJumpCooldown = PhysicsTab:CreateToggle({
    Name = 'Anti Jump Cooldown',
    Default = false,
    Tip = 'Removes the delay between jumps.',
})


-- FF2 ports for FF3
playerGravity = PhysicsTab:CreateToggle({
    Name = 'Custom Gravity',
    Default = false,
    Tip = 'Client gravity scale on your character (workspace gravity assist).',
})

playerGravityValue = PhysicsTab:CreateSlider({
    Name = 'Gravity Value',
    Min = 50,
    Max = 196,
    Default = 196,
    Increment = 1,
    Tip = 'Lower = floatier. 196 is default Roblox gravity.',
})

autoGetUp = PhysicsTab:CreateToggle({
    Name = 'Auto Get Up',
    Default = false,
    Tip = 'Gets up faster after being tackled / ragdolled.',
})


blockLateral = PhysicsTab:CreateSlider({
    Name = 'Block Lateral Reach',
    Min = 0,
    Max = 15,
    Default = 4,
    Increment = 0.5,
})
blockForward = PhysicsTab:CreateSlider({
    Name = 'Block Forward Reach',
    Min = 0,
    Max = 15,
    Default = 6,
    Increment = 0.5,
})
blockVertical = PhysicsTab:CreateSlider({
    Name = 'Block Vertical Reach',
    Min = 0,
    Max = 10,
    Default = 3,
    Increment = 0.5,
})
blockModifier = PhysicsTab:CreateToggle({
    Name = 'Block Modifier',
    Default = false,
    Tip = 'Randomized push strength on block touches.',
})
blockPushMin = PhysicsTab:CreateSlider({
    Name = 'Block Push Min',
    Min = 0,
    Max = 50,
    Default = 10,
    Increment = 1,
})
blockPushMax = PhysicsTab:CreateSlider({
    Name = 'Block Push Max',
    Min = 0,
    Max = 80,
    Default = 30,
    Increment = 1,
})

blockExtender = PhysicsTab:CreateToggle({
    Name = 'Block Reach',
    Default = false,
    Tip = 'Extends block reach against rushers.',
})

blockExtenderRange = PhysicsTab:CreateSlider({
    Name = 'Block Reach Range',
    Min = 1,
    Max = 20,
    Default = 8,
    Increment = 0.5,
    Tip = 'Block touch assist range.',
})

noMoveRestrictions = PhysicsTab:CreateToggle({
    Name = 'No Move Restrictions',
    Default = false,
    Tip = 'Clears freeze / anchored locks when they should not apply.',
})

task.spawn(function()
    while true do
        task.wait(0.1)
        if not noMoveRestrictions.Value then continue end
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild('HumanoidRootPart')
        local hum = char:FindFirstChildOfClass('Humanoid')
        if hrp and hrp.Anchored then
            -- only unanchor if not intentional freeze-on-catch window
            if not (autoFreezeOnCatch and autoFreezeOnCatch.Value) then
                hrp.Anchored = false
            end
        end
        if hum then
            pcall(function()
                hum.WalkSpeed = math.max(hum.WalkSpeed, 16)
                hum.JumpPower = math.max(hum.JumpPower, 50)
                hum:SetStateEnabled(Enum.HumanoidStateType.Running, true)
            end)
        end
    end
end)

local function yuriTPEndzone(side)
    local char = player.Character
    local hrp = char and char:FindFirstChild('HumanoidRootPart')
    if not hrp then return end
    pcall(function()
        local models = workspace:FindFirstChild('Models')
        local field = models and models:FindFirstChild('Field')
        local ground = field and (field:FindFirstChild('Ground') or field:FindFirstChildWhichIsA('BasePart'))
        local origin = ground and ground.Position or Vector3.zero
        -- FF3 field is long on Z; home/away ends
        local zOff = (side == 'away') and 150 or -150
        local x = origin.X
        local z = origin.Z + zOff
        -- prefer named endzone parts if present
        if field then
            for _, p in ipairs(field:GetDescendants()) do
                if p:IsA('BasePart') then
                    local n = string.lower(p.Name)
                    if side == 'home' and (n:find('home') and n:find('end')) then
                        hrp.CFrame = CFrame.new(p.Position + Vector3.new(0, 3, 0)); return
                    end
                    if side == 'away' and (n:find('away') and n:find('end')) then
                        hrp.CFrame = CFrame.new(p.Position + Vector3.new(0, 3, 0)); return
                    end
                end
            end
        end
        hrp.CFrame = CFrame.new(x, hrp.Position.Y + 1, z)
    end)
end

PhysicsTab:CreateButton({
    Name = 'TP Endzone Home',
    Tip = 'Teleport to home endzone.',
    Callback = function() yuriTPEndzone('home') end
})

PhysicsTab:CreateButton({
    Name = 'TP Endzone Away',
    Tip = 'Teleport to away endzone.',
    Callback = function() yuriTPEndzone('away') end
})



task.spawn(function()
    local defaultG = workspace.Gravity
    while true do
        task.wait(0.05)
        local char = player.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass('Humanoid')
        local hrp = char:FindFirstChild('HumanoidRootPart')

        -- Custom gravity (local feel via velocity damp when falling)
        if playerGravity.Value and hrp then
            local gScale = (tonumber(playerGravityValue.Value) or 196) / 196
            local vel = hrp.AssemblyLinearVelocity
            if vel.Y < 0 then
                local targetFall = vel.Y * (0.5 + 0.5 * gScale)
                -- soft blend toward scaled fall
                hrp.AssemblyLinearVelocity = Vector3.new(vel.X, vel.Y + (targetFall - vel.Y) * 0.15, vel.Z)
            end
        end

        -- Auto Get Up
        if autoGetUp.Value and hum then
            local st = hum:GetState()
            if st == Enum.HumanoidStateType.FallingDown
                or st == Enum.HumanoidStateType.Ragdoll
                or st == Enum.HumanoidStateType.Physics then
                pcall(function()
                    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                end)
            end
            pcall(function()
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            end)
        end

        -- Block Extender
        if blockExtender and blockExtender.Value and hrp and firetouchinterest then
            local range = math.max(tonumber(blockExtenderRange.Value) or 8, 1)
            local lat = (blockLateral and tonumber(blockLateral.Value)) or range
            local fwd = (blockForward and tonumber(blockForward.Value)) or range
            local vert = (blockVertical and tonumber(blockVertical.Value)) or 3

            for _, plr in ipairs(players:GetPlayers()) do
                if plr == player then continue end
                if player.Team and plr.Team and plr.Team == player.Team then continue end
                local oc = plr.Character
                if not oc then continue end
                local thrp = oc:FindFirstChild('HumanoidRootPart')
                if not thrp then continue end
                if (thrp.Position - hrp.Position).Magnitude > range then continue end
                for _, part in ipairs(char:GetChildren()) do
                    if part:IsA('BasePart') and part.Name:lower():find('block') then
                        pcall(firetouchinterest, part, thrp, 0)
                        pcall(firetouchinterest, part, thrp, 1)
                    end
                end
            end
        end
    end
end)


antiFreeze = PhysicsTab:CreateToggle({
    Name = 'Anti Freeze',
    Default = false,
    Tip = 'Prevents movement speed from being reduced.',
})

task.spawn(function()
    while true do
        task.wait()
        
        if antiJumpCooldown.Value then
            local c = player.Character
            local h = c and c:FindFirstChildOfClass('Humanoid')
            if h then
                pcall(function()
                    h:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
                    h.UseJumpPower = true
                end)
            end
        end
        
        if antiFreeze.Value then
            local c = player.Character
            local h = c and c:FindFirstChildOfClass('Humanoid')
            if h and h.WalkSpeed > 0 and h.WalkSpeed < 16 then
                h.WalkSpeed = 20
            end
        end

        for _, v in next, players:GetPlayers() do
            if v == player then continue end

            local character = v.Character
            if not character then continue end

            local hum = character:FindFirstChildOfClass('Humanoid')
            if not hum then continue end

            for _, part in next, character:GetChildren() do
                if not part:IsA('BasePart') then continue end
                if part.Name == 'Head' or part.Name == 'Torso' then
                    if hum:GetState() == Enum.HumanoidStateType.Running then
                        part.CanCollide = not antiJam.Value
                    else
                        part.CanCollide = true
                    end
                end
            end
        end
    end
end)

antiBlock = PhysicsTab:CreateToggle({
    Name = 'Anti Block',
    Default = false,
    Tip = 'Reduces player collision while moving.',
})
    
task.spawn(function()
    while true do
        task.wait()

        if not antiBlock.Value then continue end

        local character = player.Character
        if not character then continue end

        local humanoid = character:FindFirstChildOfClass('Humanoid')
        if not humanoid then continue end

        for _, v in next, character:GetDescendants() do
            if not v:IsA('BodyVelocity') then continue end
            -- if not v.Name:lower():find('ffmover') then continue end

            v.Velocity = Vector3.zero
            v.MaxForce = Vector3.zero
            humanoid.WalkSpeed = 20

            pcall(function()
                v:Destroy()
            end)
        end
    end
end)

PhysicsTab:CreateDivider()

quickTP = PhysicsTab:CreateToggle({
    Name = 'Quick TP',
    Default = false,
    Tip = 'Teleports forward in the direction you are facing.',
})

quickTPPower = PhysicsTab:CreateSlider({
    Name = 'Quick TP Power',
    Min = 0.5,
    Max = 8,
    Default = 3,
    Increment = 0.1,
    Suffix = '',
    Tip = 'Sets the teleport distance.',
})

HideKeybind = PhysicsTab:CreateKeybind({
    Name = 'Quick TP Keybind',
    Default = Enum.KeyCode.Q,
    Tip = 'Keyboard key for Quick TP (mobile uses on-screen TP).',
})

local function doQuickTP()
    if not quickTP or not quickTP.Value then return end
    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild('HumanoidRootPart')
    if not hrp then return end
    local dist = tonumber(quickTPPower and quickTPPower.Value) or 3
    if dist < 0.5 then dist = 3 end
    hrp.CFrame = hrp.CFrame + hrp.CFrame.LookVector * dist
end

userInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if not quickTP or not quickTP.Value then return end
    local key = HideKeybind and HideKeybind.Value
    if input.KeyCode == key then
        doQuickTP()
    end
end)

-- mobile Quick TP button
task.spawn(function()
    local btn
    while true do
        task.wait(0.3)
        local mobile = userInputService.TouchEnabled and not userInputService.KeyboardEnabled
        if quickTP and quickTP.Value and (mobile or userInputService.TouchEnabled) then
            if not btn or not btn.Parent then
                local pg = player:FindFirstChild('PlayerGui') or player:WaitForChild('PlayerGui', 2)
                if not pg then continue end
                local g = pg:FindFirstChild('YuriMobileTP')
                if not g then
                    g = Instance.new('ScreenGui')
                    g.Name = 'YuriMobileTP'
                    g.ResetOnSpawn = false
                    g.Parent = pg
                end
                btn = Instance.new('TextButton')
                btn.Size = UDim2.fromOffset(72, 72)
                btn.Position = UDim2.new(1, -90, 0.7, 0)
                btn.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
                btn.Text = 'TP'
                btn.TextColor3 = Color3.fromRGB(99, 140, 255)
                btn.TextSize = 18
                btn.Font = Enum.Font.GothamBold
                btn.Parent = g
                Instance.new('UICorner', btn).CornerRadius = UDim.new(0, 16)
                btn.MouseButton1Click:Connect(doQuickTP)
            end
            if btn then btn.Visible = true end
        else
            if btn then btn.Visible = false end
        end
    end
end)
    
PhysicsTab:CreateDivider()

bigHead = PhysicsTab:CreateToggle({
    Name = 'Big Head Players',
    Default = false,
    Tip = 'Increases the size of other players heads.',
})

bigHeadSize = PhysicsTab:CreateSlider({
    Name = 'Big Head Size',
    Min = 1,
    Max = 6,
    Default = 1,
    Increment = 0.1,
    Suffix = '',
    Tip = 'Sets the size applied to player heads.',
})

task.spawn(function()
    while true do
        task.wait()

        for _, v in next, players:GetPlayers() do
            if v == player then continue end

            local character = v.Character
            if not character then continue end

            local head = character:FindFirstChild('Head')
            if not head then continue end

            head.Size = Vector3.new(bigHead.Value and bigHeadSize.Value or 1, bigHead.Value and bigHeadSize.Value or 1, bigHead.Value and bigHeadSize.Value or 1)
        end
    end
end)
    
local VisualTab = Window:CreateTab({ Name = 'Visual', Icon = 'rbxassetid://88610077537468' })



fieldRecolor = VisualTab:CreateToggle({
    Name = 'Field Recolor',
    Default = false,
    Tip = 'Tints the field turf on your client.',
})
fieldColor = VisualTab:CreateDropdown({
    Name = 'Field Color',
    Options = {'Green', 'Blue', 'Purple', 'Red', 'Black', 'White'},
    Default = 'Green',
})

motionBlur = VisualTab:CreateToggle({
    Name = 'Motion Blur',
    Default = false,
    Tip = 'Adds a light blur effect while moving the camera.',
})

task.spawn(function()
    local FIELD_COLS = {
        Green = Color3.fromRGB(40, 120, 50),
        Blue = Color3.fromRGB(40, 80, 160),
        Purple = Color3.fromRGB(90, 40, 140),
        Red = Color3.fromRGB(140, 40, 40),
        Black = Color3.fromRGB(25, 25, 28),
        White = Color3.fromRGB(220, 220, 225),
    }
    local blur
    local lastCam = nil
    while true do
        task.wait(0.2)
        if fieldRecolor and fieldRecolor.Value then
            local col = FIELD_COLS[tostring(fieldColor.Value)] or FIELD_COLS.Green
            pcall(function()
                local models = workspace:FindFirstChild('Models')
                local field = models and models:FindFirstChild('Field')
                if field then
                    for _, p in ipairs(field:GetDescendants()) do
                        if p:IsA('BasePart') and (p.Name:lower():find('grass') or p.Name:lower():find('ground') or p.Name:lower():find('turf') or p.Name == 'Ground') then
                            p.Color = col
                        end
                    end
                end
            end)
        end
        local lighting = game:GetService('Lighting')
        if motionBlur and motionBlur.Value then
            if not blur then
                blur = Instance.new('BlurEffect')
                blur.Name = 'YuriMotionBlur'
                blur.Size = 0
                blur.Parent = lighting
            end
            local cam = workspace.CurrentCamera
            if cam and lastCam then
                local delta = (cam.CFrame.Position - lastCam.Position).Magnitude
                    + (cam.CFrame.LookVector - lastCam.LookVector).Magnitude * 20
                blur.Size = math.clamp(delta * 2.5, 0, 12)
            end
            lastCam = cam and cam.CFrame or lastCam
        else
            if blur then pcall(function() blur:Destroy() end) blur = nil end
            lastCam = nil
        end
    end
end)


catchEffect = VisualTab:CreateToggle({
    Name = 'Catch Effect',
    Default = false,
    Tip = 'Burst effect when you gain the football.',
})

noTexture = VisualTab:CreateToggle({
    Name = 'No Texture',
    Default = false,
    Tip = 'Clears mesh textures on character for a clean look.',
})

streamerMode = VisualTab:CreateToggle({
    Name = 'Streamer Mode',
    Default = false,
    Tip = 'Hides your name/tag locally for streams.',
})
streamerName = VisualTab:CreateDropdown({
    Name = 'Streamer Name',
    Options = {'Hidden', 'Player', 'Yuri'},
    Default = 'Hidden',
})

weatherPreset = VisualTab:CreateDropdown({
    Name = 'Change Weather',
    Options = {'Default', 'Clear', 'Rain', 'Snow', 'Fog'},
    Default = 'Default',
    Tip = 'Client weather/atmosphere preset.',
})

task.spawn(function()
    local hadBall = false
    local rainParts = {}
    while true do
        task.wait(0.1)
        local char = player.Character
        if catchEffect and catchEffect.Value and char then
            local has = char:FindFirstChild('Football') ~= nil
            if has and not hadBall then
                local hrp = char:FindFirstChild('HumanoidRootPart')
                if hrp then
                    pcall(function()
                        local p = Instance.new('Part')
                        p.Anchored = true
                        p.CanCollide = false
                        p.Size = Vector3.new(0.2, 0.2, 0.2)
                        p.Transparency = 1
                        p.Position = hrp.Position
                        p.Parent = workspace.Terrain
                        local e = Instance.new('ParticleEmitter')
                        e.Texture = 'rbxasset://textures/particles/sparkles_main.dds'
                        e.Rate = 0
                        e.Lifetime = NumberRange.new(0.4)
                        e.Speed = NumberRange.new(4, 10)
                        e.Color = ColorSequence.new(Color3.fromRGB(245, 230, 200))
                        e.Parent = p
                        e:Emit(30)
                        task.delay(1, function() p:Destroy() end)
                    end)
                end
            end
            hadBall = has
        end

        if noTexture and noTexture.Value and char then
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA('MeshPart') then
                    pcall(function() d.TextureID = '' end)
                elseif d:IsA('SpecialMesh') then
                    pcall(function() d.TextureId = '' end)
                end
            end
        end

        if streamerMode and streamerMode.Value and char then
            local head = char:FindFirstChild('Head')
            if head then
                for _, g in ipairs(head:GetChildren()) do
                    if g:IsA('BillboardGui') or g:IsA('SurfaceGui') then
                        pcall(function() g.Enabled = false end)
                    end
                end
            end
            pcall(function()
                local hum = char:FindFirstChildOfClass('Humanoid')
                if hum then
                    hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                end
            end)
        end

        if weatherPreset then
            local w = tostring(weatherPreset.Value)
            local lighting = game:GetService('Lighting')
            if w == 'Rain' or w == 'Snow' then
                pcall(function()
                    lighting.Brightness = 1
                    lighting.FogEnd = 400
                end)
            elseif w == 'Fog' then
                pcall(function()
                    lighting.FogEnd = 120
                    lighting.FogColor = Color3.fromRGB(180, 180, 190)
                end)
            elseif w == 'Clear' then
                pcall(function()
                    lighting.FogEnd = 100000
                    lighting.Brightness = 2
                end)
            end
        end
    end
end)


coverMarker = VisualTab:CreateToggle({
    Name = 'Cover Marker',
    Default = false,
    Tip = 'Highlights nearest enemy receiver.',
})
rushMarker = VisualTab:CreateToggle({
    Name = 'Rush Marker',
    Default = false,
    Tip = 'Highlights enemy ball carrier.',
})
routeMarker = VisualTab:CreateToggle({
    Name = 'Route Marker',
    Default = false,
    Tip = 'Beam to current QBA target.',
})

colorCorrectionToggle = VisualTab:CreateToggle({
    Name = 'Color Correction',
    Default = false,
})

task.spawn(function()
    local fx
    while true do
        task.wait(0.4)
        local lighting = game:GetService('Lighting')
        if colorCorrectionToggle and colorCorrectionToggle.Value then
            if not fx then
                fx = lighting:FindFirstChild('YuriCC')
                if not fx then
                    fx = Instance.new('ColorCorrectionEffect')
                    fx.Name = 'YuriCC'
                    fx.Saturation = 0.15
                    fx.Contrast = 0.08
                    fx.Parent = lighting
                end
            end
            fx.Enabled = true
        elseif fx then
            fx.Enabled = false
        end
    end
end)

ambientToggle = VisualTab:CreateToggle({
    Name = 'Custom Ambient',
    Default = false,
})
sunRaysToggle = VisualTab:CreateToggle({
    Name = 'Sun Rays',
    Default = false,
})
cloudsToggle = VisualTab:CreateToggle({
    Name = 'Clouds',
    Default = false,
})

task.spawn(function()
    local hlCover, hlRush, routeBeam, ra0, ra1
    local function clearHL(h)
        if h then pcall(function() h:Destroy() end) end
        return nil
    end
    while true do
        task.wait(0.1)
        local char = player.Character
        local hrp = char and char:FindFirstChild('HumanoidRootPart')

        if coverMarker and coverMarker.Value and hrp then
            local best, bd = nil, 55
            for _, plr in ipairs(players:GetPlayers()) do
                if plr == player then continue end
                if player.Team and plr.Team and plr.Team == player.Team then continue end
                local oc = plr.Character
                if oc and not oc:FindFirstChild('Football') then
                    local thrp = oc:FindFirstChild('HumanoidRootPart')
                    if thrp then
                        local d = (thrp.Position - hrp.Position).Magnitude
                        if d < bd then bd = d best = oc end
                    end
                end
            end
            if best then
                if not hlCover or hlCover.Adornee ~= best then
                    hlCover = clearHL(hlCover)
                    local h = Instance.new('Highlight')
                    h.Adornee = best
                    h.FillColor = Color3.fromRGB(80, 160, 255)
                    h.OutlineColor = Color3.fromRGB(200, 230, 255)
                    h.FillTransparency = 0.6
                    h.Parent = best
                    hlCover = h
                end
            else
                hlCover = clearHL(hlCover)
            end
        else
            hlCover = clearHL(hlCover)
        end

        if rushMarker and rushMarker.Value then
            local best = nil
            for _, plr in ipairs(players:GetPlayers()) do
                if plr == player then continue end
                local oc = plr.Character
                if oc and oc:FindFirstChild('Football') then best = oc break end
            end
            if best then
                if not hlRush or hlRush.Adornee ~= best then
                    hlRush = clearHL(hlRush)
                    local h = Instance.new('Highlight')
                    h.Adornee = best
                    h.FillColor = Color3.fromRGB(255, 90, 60)
                    h.OutlineColor = Color3.fromRGB(255, 200, 150)
                    h.FillTransparency = 0.55
                    h.Parent = best
                    hlRush = h
                end
            else
                hlRush = clearHL(hlRush)
            end
        else
            hlRush = clearHL(hlRush)
        end

        local tgt = rawget(_G, 'YuriTarget') or (type(target) == 'userdata' and target) or nil
        if routeMarker and routeMarker.Value and type(target) == 'userdata' and target and target.Character and hrp then
            local thrp = target.Character:FindFirstChild('HumanoidRootPart')
            if thrp then
                if not routeBeam then
                    ra0 = Instance.new('Attachment')
                    ra0.Parent = hrp
                    ra1 = Instance.new('Attachment')
                    ra1.Parent = thrp
                    routeBeam = Instance.new('Beam')
                    routeBeam.Attachment0 = ra0
                    routeBeam.Attachment1 = ra1
                    routeBeam.Width0 = 0.2
                    routeBeam.Width1 = 0.2
                    routeBeam.Color = ColorSequence.new(Color3.fromRGB(245, 230, 200))
                    routeBeam.FaceCamera = true
                    routeBeam.Parent = workspace.Terrain
                else
                    ra0.Parent = hrp
                    ra1.Parent = thrp
                    routeBeam.Enabled = true
                end
            end
        else
            if routeBeam then pcall(function() routeBeam:Destroy() end) routeBeam = nil end
            if ra0 then pcall(function() ra0:Destroy() end) ra0 = nil end
            if ra1 then pcall(function() ra1:Destroy() end) ra1 = nil end
        end

        local lighting = game:GetService('Lighting')
        if ambientToggle and ambientToggle.Value then
            pcall(function()
                lighting.Ambient = Color3.fromRGB(120, 120, 130)
                lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 150)
            end)
        end
        if sunRaysToggle and sunRaysToggle.Value then
            pcall(function()
                if not lighting:FindFirstChild('YuriSunRays') then
                    local sr = Instance.new('SunRaysEffect')
                    sr.Name = 'YuriSunRays'
                    sr.Intensity = 0.15
                    sr.Parent = lighting
                end
            end)
        else
            pcall(function()
                local sr = lighting:FindFirstChild('YuriSunRays')
                if sr then sr:Destroy() end
            end)
        end
        if cloudsToggle and cloudsToggle.Value then
            pcall(function()
                local clouds = workspace.Terrain:FindFirstChildOfClass('Clouds')
                if not clouds then
                    clouds = Instance.new('Clouds')
                    clouds.Parent = workspace.Terrain
                end
                clouds.Cover = 0.55
                clouds.Density = 0.4
            end)
        end
    end
end)



-- Cons update: Shiny Helmet

uniformExtras = VisualTab:CreateToggle({
    Name = 'Uniform Parts Tint',
    Default = false,
})
uniformPartColor = VisualTab:CreateDropdown({
    Name = 'Part Color',
    Options = {'White', 'Black', 'Red', 'Blue', 'Green', 'Gold'},
    Default = 'White',
})
jerseyNameSpoof = VisualTab:CreateToggle({
    Name = 'Jersey Name (Client)',
    Default = false,
    Tip = 'Local nametag only - not server-side.',
})
celebrationSpoof = VisualTab:CreateToggle({
    Name = 'Celebration Effect',
    Default = false,
})

local PART_COLS = {
    White = Color3.fromRGB(240, 240, 245),
    Black = Color3.fromRGB(20, 20, 22),
    Red = Color3.fromRGB(200, 40, 40),
    Blue = Color3.fromRGB(40, 80, 200),
    Green = Color3.fromRGB(40, 160, 70),
    Gold = Color3.fromRGB(220, 180, 60),
}

task.spawn(function()
    while true do
        task.wait(0.25)
        local char = player.Character
        if not char then continue end
        if uniformExtras and uniformExtras.Value then
            local col = PART_COLS[tostring(uniformPartColor and uniformPartColor.Value)] or PART_COLS.White
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA('BasePart') then
                    local n = d.Name:lower()
                    if n:find('pant') or n:find('sleeve') or n:find('sock') or n:find('shoe') or n:find('boot') or n:find('jersey') or n:find('shirt') then
                        pcall(function() d.Color = col end)
                    end
                end
            end
        end
        if jerseyNameSpoof and jerseyNameSpoof.Value then
            pcall(function()
                local hum = char:FindFirstChildOfClass('Humanoid')
                if hum then
                    hum.DisplayName = 'Yuri'
                end
            end)
        end
        if celebrationSpoof and celebrationSpoof.Value and char:FindFirstChild('Football') then
            -- light local particle when scoring zone-ish near endzone Z
            local hrp = char:FindFirstChild('HumanoidRootPart')
            if hrp and math.abs(hrp.Position.Z) > 140 then
                -- no spam: handled by catch effect if on
            end
        end
    end
end)

shinyHelmet = VisualTab:CreateToggle({
    Name = 'Shiny Helmet',
    Default = false,
    Tip = 'Glass + full reflectance on helmet accessories.',
})

local function applyShinyHelmet()
    if not shinyHelmet.Value then return end
    local char = lp.Character
    if not char then return end
    for _, v in ipairs(char:GetDescendants()) do
        if not v:IsA('BasePart') then continue end
        local parent = v.Parent
        local isHelm = (parent and parent:IsA('Accessory')) or (tostring(v.Name):lower():find('helmet') ~= nil)
        if not isHelm then continue end
        pcall(function()
            v.Material = Enum.Material.Glass
            v.Reflectance = 1
            v.Color = Color3.fromRGB(180, 210, 255)
            if v:IsA('MeshPart') then v.TextureID = '' end
            local mesh = v:FindFirstChildOfClass('SpecialMesh')
            if mesh then mesh.TextureId = '' end
        end)
    end
end

task.spawn(function()
    local conn
    local function hook()
        if conn then conn:Disconnect() end
        conn = runService.Heartbeat:Connect(function()
            if shinyHelmet.Value then
                pcall(applyShinyHelmet)
            end
        end)
    end
    hook()
    lp.CharacterAdded:Connect(function()
        task.wait(0.15)
        if shinyHelmet.Value then pcall(applyShinyHelmet) end
    end)
end)




jumpSpot = VisualTab:CreateToggle({
    Name = 'Jump Spot',
    Default = false,
    Tip = 'Glowing ring where you should jump to catch (live).',
})

jumpSpotHeight = VisualTab:CreateSlider({
    Name = 'Jump Spot Height',
    Min = 0,
    Max = 8,
    Default = 1.5,
    Increment = 0.1,
    Tip = 'Vertical offset of the jump ring above the landing point.',
})

ballTrajectory = VisualTab:CreateToggle({
    Name = 'Ball Path',
    Default = false,
    Tip = 'Live every-frame ball path (multi-ball). Path fades behind the ball.',
})

ballTrajectoryColor = VisualTab:CreateDropdown({
    Name = 'Path Color',
    Options = {'Amber', 'Cyan', 'White', 'Green', 'Cream'},
    Default = 'Cream',
    Tip = 'Color of the live ball path.',
})

local PATH_COLORS = {
    Amber = Color3.fromRGB(255, 150, 55),
    Cyan = Color3.fromRGB(64, 220, 200),
    White = Color3.fromRGB(240, 240, 245),
    Green = Color3.fromRGB(80, 220, 120),
    Cream = Color3.fromRGB(245, 230, 200),
}

-- Live path state per ball
local livePaths = {} -- [ball] = { parts = {BasePart}, beads = {}, lastPos = Vector3, folder = Folder }
local jumpMarkers = {} -- [ball] = { ring, land, folder }

local function destroyPath(ball)
    local data = livePaths[ball]
    if not data then return end
    pcall(function()
        if data.folder then data.folder:Destroy() end
    end)
    livePaths[ball] = nil
end

local function destroyJump(ball)
    local data = jumpMarkers[ball]
    if not data then return end
    pcall(function()
        if data.folder then data.folder:Destroy() end
    end)
    jumpMarkers[ball] = nil
end

local function predictLanding(pos, vel)
    local gravity = Vector3.new(0, -28, 0)
    local dt = 1 / 60
    local p, v = pos, vel
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {lp.Character}
    for _ = 1, 400 do
        local nextP = p + v * dt + 0.5 * gravity * dt * dt
        v = v + gravity * dt
        if v.Y < 0 then
            local hit = workspace:Raycast(p, nextP - p + Vector3.new(0, -3, 0), params)
            if hit then
                return hit.Position
            end
        end
        if nextP.Y < 0 then
            return Vector3.new(nextP.X, 0, nextP.Z)
        end
        p = nextP
    end
    return p
end

local function ensureJumpMarker(ball, landPos)
    local h = (jumpSpotHeight and tonumber(jumpSpotHeight.Value)) or 1.5
    local data = jumpMarkers[ball]
    if not data then
        local folder = Instance.new('Folder')
        folder.Name = 'YuriJumpSpot'
        folder.Parent = workspace.Terrain

        local ring = Instance.new('Part')
        ring.Name = 'JumpRing'
        ring.Anchored = true
        ring.CanCollide = false
        ring.CanQuery = false
        ring.Material = Enum.Material.Neon
        ring.Color = Color3.fromRGB(245, 230, 200)
        ring.Transparency = 0.25
        ring.Size = Vector3.new(4.2, 0.12, 4.2)
        ring.Shape = Enum.PartType.Cylinder
        ring.CFrame = CFrame.new(landPos + Vector3.new(0, h, 0)) * CFrame.Angles(0, 0, math.rad(90))
        ring.Parent = folder

        local land = Instance.new('Part')
        land.Name = 'LandingRing'
        land.Anchored = true
        land.CanCollide = false
        land.CanQuery = false
        land.Material = Enum.Material.ForceField
        land.Color = Color3.fromRGB(255, 255, 255)
        land.Transparency = 0.4
        land.Size = Vector3.new(2.4, 0.08, 2.4)
        land.Shape = Enum.PartType.Cylinder
        land.CFrame = CFrame.new(landPos + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
        land.Parent = folder

        data = { folder = folder, ring = ring, land = land }
        jumpMarkers[ball] = data
    end
    local h = (jumpSpotHeight and tonumber(jumpSpotHeight.Value)) or 1.5
    data.ring.CFrame = CFrame.new(landPos + Vector3.new(0, h, 0)) * CFrame.Angles(0, 0, math.rad(90))
    data.land.CFrame = CFrame.new(landPos + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
end

local function ensurePath(ball)
    local data = livePaths[ball]
    if data then return data end
    local folder = Instance.new('Folder')
    folder.Name = 'YuriBallPath'
    folder.Parent = workspace.Terrain
    data = {
        folder = folder,
        segments = {},
        beads = {},
        history = {}, -- fixed world points for beads (do not slide)
        lastPos = ball.Position,
    }
    livePaths[ball] = data
    return data
end

local function addPathSegment(data, fromPos, toPos, col)
    local mid = (fromPos + toPos) * 0.5
    local dist = (toPos - fromPos).Magnitude
    if dist < 0.05 then return end
    local part = Instance.new('Part')
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.Material = Enum.Material.Neon
    part.Color = col
    part.Transparency = 0.35
    part.Size = Vector3.new(0.12, 0.12, dist)
    part.CFrame = CFrame.lookAt(mid, toPos)
    part.Parent = data.folder
    table.insert(data.segments, part)
    -- fade trail: destroy oldest segments so path "disappears behind the ball"
    while #data.segments > 48 do
        local old = table.remove(data.segments, 1)
        if old then pcall(function() old:Destroy() end) end
    end
end

-- Live every-frame path + multi-ball + jump spot
runService.RenderStepped:Connect(function()
    local pathOn = ballTrajectory and ballTrajectory.Value
    local jumpOn = jumpSpot and jumpSpot.Value
    if not pathOn and not jumpOn then
        for b in pairs(livePaths) do destroyPath(b) end
        for b in pairs(jumpMarkers) do destroyJump(b) end
        return
    end

    local col = PATH_COLORS[tostring(ballTrajectoryColor and ballTrajectoryColor.Value)] or PATH_COLORS.Cream
    local seen = {}

    for _, v in ipairs(workspace:GetChildren()) do
        if not v:IsA('BasePart') or v.Name ~= 'Football' then continue end
        local vel = v.AssemblyLinearVelocity
        local speed = vel.Magnitude
        -- track airborne or just-thrown (own throws path instantly)
        local mine = false
        pcall(function()
            if lp.Character and v:IsDescendantOf(lp.Character) then mine = true end
            if v:GetAttribute('LocalAimbotBall') then mine = true end
        end)
        if speed < 1.2 and not mine and v.Position.Y < 3 then continue end

        seen[v] = true

        if pathOn then
            local data = ensurePath(v)
            local pos = v.Position
            local last = data.lastPos or pos
            if (pos - last).Magnitude > 0.15 then
                addPathSegment(data, last, pos, col)
                data.lastPos = pos
                -- dotted beads stay put (fixed world positions)
                if #data.history == 0 or (pos - data.history[#data.history]).Magnitude > 2.5 then
                    table.insert(data.history, pos)
                    local bead = Instance.new('Part')
                    bead.Shape = Enum.PartType.Ball
                    bead.Size = Vector3.new(0.35, 0.35, 0.35)
                    bead.Anchored = true
                    bead.CanCollide = false
                    bead.CanQuery = false
                    bead.Material = Enum.Material.Neon
                    bead.Color = col
                    bead.Transparency = 0.2
                    bead.Position = pos -- fixed; does not parent to ball
                    bead.Parent = data.folder
                    table.insert(data.beads, bead)
                    while #data.beads > 20 do
                        local ob = table.remove(data.beads, 1)
                        if ob then pcall(function() ob:Destroy() end) end
                    end
                    while #data.history > 20 do
                        table.remove(data.history, 1)
                    end
                end
            end
            -- live prediction tip (ahead of ball)
            if speed > 2 then
                local pred = pos + vel * 0.55 + Vector3.new(0, -28 * 0.55 * 0.55 * 0.5, 0)
                addPathSegment(data, pos, pred, col)
            end
        end

        if jumpOn and speed > 2 then
            local land = predictLanding(v.Position, vel)
            ensureJumpMarker(v, land)
        elseif jumpOn and jumpMarkers[v] and speed <= 2 then
            destroyJump(v)
        end
    end

    for b in pairs(livePaths) do
        if not seen[b] or not b.Parent then destroyPath(b) end
    end
    for b in pairs(jumpMarkers) do
        if not seen[b] or not b.Parent then destroyJump(b) end
    end
end)

throwSpot = VisualTab:CreateToggle({
    Name = 'Throw Spot',
    Default = false,
    Tip = 'Predicted landing point of thrown footballs.',
})
    
    workspace.ChildAdded:Connect(function(v)
        if not throwSpot.Value then return end
    if not v:IsA('BasePart') or v.Name ~= 'Football' then return end

    task.wait()

    local pos = v.Position
    local vel = v.AssemblyLinearVelocity
    local gravity = Vector3.new(0, -28, 0)

    local positions = {}
    local parts = {}

    local dt = 0.05
    local maxTime = 8

    local lastPos = pos
    local spawnY = pos.Y

    for t = 0, maxTime, dt do
        local projectilePos = pos + (vel * t) + (0.5 * gravity * t * t)

        table.insert(positions, projectilePos)

        if projectilePos.Y < spawnY then
            break
        end

        local ray = workspace:Raycast(lastPos, projectilePos - lastPos)
        if ray then
            positions[#positions] = ray.Position
            break
        end

        lastPos = projectilePos
    end

    local endPos = positions[#positions]
    if not endPos then return end

    local posPart = Instance.new('Part', workspace.Terrain)
    posPart.Anchored = true
    posPart.CanCollide = false
    posPart.CastShadow = false
    posPart.Size = Vector3.new(3, 3, 3)
    posPart.Shape = Enum.PartType.Ball
    posPart.Color = Color3.fromRGB(0, 0, 0)
    posPart.Position = endPos

    for i = 1, #positions - 1 do
        local p0 = positions[i]
        local p1 = positions[i + 1]

        local beamPart = Instance.new('Part', workspace.Terrain)
        beamPart.Anchored = true
        beamPart.CanCollide = false
        beamPart.CastShadow = false
        beamPart.Material = Enum.Material.Neon
        beamPart.Color = Color3.fromRGB(255, 255, 255)

        local dist = (p1 - p0).Magnitude

        beamPart.Size = Vector3.new(0.4, 0.4, dist)
        beamPart.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)

        table.insert(parts, beamPart)
    end

    task.spawn(function()
        local speed = math.max(vel.Magnitude, 1)
        local delayTime = math.clamp(300 / speed, 0.01, 0.04)

        for _, part in next, parts do
            task.wait(delayTime)

            if part.Parent then
                part:Destroy()
            end
        end

        if posPart.Parent then
            posPart:Destroy()
        end
    end)
end)
    
VisualTab:CreateDivider()
    

customUniform = VisualTab:CreateToggle({
    Name = 'Custom Uniform',
    Default = false,
    Tip = 'Applies custom jersey colors / number visibility helpers.',
})

uniformColor = VisualTab:CreateDropdown({
    Name = 'Uniform Accent',
    Options = {'Default', 'Cyan', 'Amber', 'Red', 'Blue', 'White', 'Black'},
    Default = 'Default',
    Tip = 'Tint uniform base parts (client visual).',
})

local UNIFORM_COLORS = {
    Default = nil,
    Cyan = Color3.fromRGB(64, 220, 200),
    Amber = Color3.fromRGB(255, 150, 55),
    Red = Color3.fromRGB(220, 60, 60),
    Blue = Color3.fromRGB(50, 100, 220),
    White = Color3.fromRGB(240, 240, 245),
    Black = Color3.fromRGB(25, 25, 28),
}

task.spawn(function()
    while true do
        task.wait(0.35)
        if not customUniform or not customUniform.Value then continue end
        local character = player.Character
        if not character then continue end
        local uniform = character:FindFirstChild('Uniform')
        if not uniform then continue end
        local col = UNIFORM_COLORS[tostring(uniformColor.Value)] 
        if not col then continue end
        for _, v in ipairs(uniform:GetDescendants()) do
            if v:IsA('BasePart') then
                pcall(function()
                    v.Color = col
                end)
            end
        end
    end
end)


enableGloves = VisualTab:CreateToggle({
    Name = 'Enable Uniform Gloves',
    Default = true,
    Tip = 'Toggles visibility of uniform gloves.',
})

task.spawn(function()
    while true do
        task.wait()

        local character = player.Character
        if not character then continue end

        local uniform = character:FindFirstChild('Uniform')
        if not uniform then continue end

        local gloveVisible

        for _, v in next, uniform:GetDescendants() do
            if not v:IsA('BasePart') then continue end
            if not v.Name:lower():find('glove') then continue end

            gloveVisible = v.Transparency == 0
            break
        end

        if gloveVisible == nil then continue end

        if enableGloves.Value and not gloveVisible then
            replicatedStorage.Remotes.CharacterSoundEvent:FireServer('Game', 'Customization', 'Toggle', 'LeftGlove')
            replicatedStorage.Remotes.CharacterSoundEvent:FireServer('Game', 'Customization', 'Toggle', 'RightGlove')
        elseif not enableGloves.Value and gloveVisible then
            replicatedStorage.Remotes.CharacterSoundEvent:FireServer('Game', 'Customization', 'Toggle', 'LeftGlove')
            replicatedStorage.Remotes.CharacterSoundEvent:FireServer('Game', 'Customization', 'Toggle', 'RightGlove')
        end
    end
end)

VisualTab:CreateDivider()
    
noBallTrail = VisualTab:CreateToggle({
    Name = 'No Ball Trail',
    Default = false,
    Tip = 'Removes football trail effects.',
})

local function stripBallTrails(root)
    if not root then return end
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA('Trail') or d:IsA('Beam') and d.Name:lower():find('trail') then
            pcall(function() d:Destroy() end)
        end
    end
    if root:IsA('BasePart') then
        local t = root:FindFirstChildOfClass('Trail')
        if t then pcall(function() t:Destroy() end) end
    end
end

workspace.ChildAdded:Connect(function(v)
    if not noBallTrail or not noBallTrail.Value then return end
    if v.Name == 'Football' or (v:IsA('BasePart') and v.Name == 'Football') then
        task.defer(stripBallTrails, v)
    end
end)

task.spawn(function()
    while true do
        task.wait(0.35)
        if not noBallTrail or not noBallTrail.Value then continue end
        for _, v in ipairs(workspace:GetChildren()) do
            if v.Name == 'Football' then stripBallTrails(v) end
        end
        for _, plr in ipairs(players:GetPlayers()) do
            local c = plr.Character
            if c then
                local fb = c:FindFirstChild('Football')
                if fb then stripBallTrails(fb) end
            end
        end
    end
end)

local stadiumParts = {}

pcall(function()
    local stad = workspace:FindFirstChild('Models') and workspace.Models:FindFirstChild('Stadium')
    if not stad then return end
    for _, v in next, stad:GetDescendants() do
        if not v:IsA('BasePart') then continue end
        stadiumParts[#stadiumParts + 1] = {
            Part = v,
            Transparency = v.Transparency,
            CanCollide = v.CanCollide
        }
    end
end)

hideStadium = VisualTab:CreateToggle({
    Name = 'Hide Stadium',
    Default = false,
    Tip = 'Hides visible stadium structures.',
    Callback = function(v)
        for _, p in next, stadiumParts do
            pcall(function()
                p.Part.Transparency = v and 1 or p.Transparency
                p.Part.CanCollide = v and false or p.CanCollide
            end)
        end
    end
})
-- re-apply on map refresh / new play (Yuna fix)
task.spawn(function()
    while true do
        task.wait(2)
        if not hideStadium or not hideStadium.Value then continue end
        for _, p in next, stadiumParts do
            pcall(function()
                if p.Part and p.Part.Parent then
                    p.Part.Transparency = 1
                    p.Part.CanCollide = false
                end
            end)
        end
    end
end)


-- FF2 ports: FOV, Ball ESP, Camera Zoom unlock, Ball Path alias already as Ball Trajectory

jerseyChanger = VisualTab:CreateToggle({
    Name = 'Jersey Number Tint',
    Default = false,
    Tip = 'Client-side jersey/number accent (visual only).',
})

jerseyTint = VisualTab:CreateDropdown({
    Name = 'Jersey Tint',
    Options = {'Amber', 'Cyan', 'White', 'Red'},
    Default = 'Amber',
})

task.spawn(function()
    local cols = {
        Amber = Color3.fromRGB(255, 150, 55),
        Cyan = Color3.fromRGB(64, 220, 200),
        White = Color3.fromRGB(240, 240, 245),
        Red = Color3.fromRGB(220, 60, 60),
    }
    while true do
        task.wait(0.4)
        if not jerseyChanger.Value then continue end
        local char = player.Character
        if not char then continue end
        local uniform = char:FindFirstChild('Uniform')
        if not uniform then continue end
        local col = cols[tostring(jerseyTint.Value)] or cols.Amber
        for _, v in ipairs(uniform:GetDescendants()) do
            if v:IsA('BasePart') and (v.Name:lower():find('number') or v.Name:lower():find('digit') or v.Name:lower():find('jersey')) then
                pcall(function() v.Color = col end)
            end
        end
    end
end)


customFOV = VisualTab:CreateToggle({
    Name = 'Custom FOV',
    Default = false,
    Tip = 'Overrides camera field of view.',
})

fovValue = VisualTab:CreateSlider({
    Name = 'FOV Value',
    Min = 50,
    Max = 120,
    Default = 70,
    Increment = 1,
})

unlockCameraZoom = VisualTab:CreateToggle({
    Name = 'Unlock Camera Zoom',
    Default = false,
    Tip = 'Removes camera zoom limits.',
})


trajectoryType = VisualTab:CreateDropdown({
    Name = 'Trajectory Type',
    Options = {'Beam', 'Dots', 'Both'},
    Default = 'Beam',
})

trajectoryPartSpacing = VisualTab:CreateSlider({
    Name = 'Trajectory Part Spacing',
    Min = 0.05,
    Max = 1,
    Default = 0.15,
    Increment = 0.05,
    Tip = 'Seconds between path markers when Trajectory Type is Parts.',
})
trajectoryColor = VisualTab:CreateDropdown({
    Name = 'Trajectory Color',
    Options = {'Amber', 'Cyan', 'White', 'Red', 'Green'},
    Default = 'Amber',
})

ballESP = VisualTab:CreateToggle({
    Name = 'Highlight Ball',
    Default = false,
    Tip = 'Highlight on airborne / field footballs.',
})

task.spawn(function()
    local ballHighlights = {}
    -- fix zoom-on-execute: restore default once
    pcall(function()
        local cam = workspace.CurrentCamera
        if cam then cam.FieldOfView = 70 end
    end)
    while true do
        task.wait(0.1)
        local cam = workspace.CurrentCamera
        if customFOV.Value and cam then
            cam.FieldOfView = tonumber(fovValue.Value) or 70
        end
        if unlockCameraZoom.Value then
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass('Humanoid')
            if hum then
                pcall(function()
                    hum.CameraOffset = Vector3.zero
                end)
            end
            pcall(function()
                player.CameraMaxZoomDistance = 128
                player.CameraMinZoomDistance = 0.5
            end)
        end
        if ballESP.Value then
            local seen = {}
            for _, v in ipairs(workspace:GetChildren()) do
                if v:IsA('BasePart') and v.Name == 'Football' then
                    -- don't highlight ball while held in a character
                    local held = v.Parent and v.Parent:FindFirstChildOfClass('Humanoid')
                    if held then
                        if ballHighlights[v] then
                            pcall(function() ballHighlights[v]:Destroy() end)
                            ballHighlights[v] = nil
                        end
                    else
                        seen[v] = true
                        if not ballHighlights[v] then
                            local h = Instance.new('Highlight')
                            h.Adornee = v
                            h.FillColor = Color3.fromRGB(255, 170, 60)
                            h.OutlineColor = Color3.fromRGB(255, 220, 120)
                            h.FillTransparency = 0.5
                            h.Parent = v
                            ballHighlights[v] = h
                        end
                    end
                end
            end
            for b, h in pairs(ballHighlights) do
                if not seen[b] or not b.Parent then
                    pcall(function() h:Destroy() end)
                    ballHighlights[b] = nil
                end
            end
        else
            for b, h in pairs(ballHighlights) do
                pcall(function() h:Destroy() end)
                ballHighlights[b] = nil
            end
        end
    end
end)


VisualTab:CreateDivider()

local lighting = game:GetService('Lighting')

local function ApplySkyBox(name)
    for _, v in next, lighting:GetChildren() do
        if v:IsA("Sky") or v:IsA("PostEffect") or v:IsA("Atmosphere") then
            v:Destroy()
        end
    end

    if name == "Golden Twilight" then
        local Sky = Instance.new("Sky")
        Sky.Name = name
        Sky.Parent = lighting
        Sky.SkyboxBk = "rbxassetid://541743453"
        Sky.SkyboxDn = "rbxassetid://541743443"
        Sky.SkyboxFt = "rbxassetid://541743446"
        Sky.SkyboxLf = "rbxassetid://541743436"
        Sky.SkyboxRt = "rbxassetid://541743435"
        Sky.SkyboxUp = "rbxassetid://541743441"

    elseif name == "Infernal Horizon" then
        local Sky = Instance.new("Sky")
        Sky.Name = name
        Sky.Parent = lighting
        Sky.SkyboxBk = "http://www.roblox.com/asset/?id=169210090"
        Sky.SkyboxDn = "http://www.roblox.com/asset/?id=169210108"
        Sky.SkyboxFt = "http://www.roblox.com/asset/?id=169210121"
        Sky.SkyboxLf = "http://www.roblox.com/asset/?id=169210133"
        Sky.SkyboxRt = "http://www.roblox.com/asset/?id=169210143"
        Sky.SkyboxUp = "http://www.roblox.com/asset/?id=169210149"
        Sky.StarCount = 100
        Sky.SunTextureId = " "

        local BlurEffect = Instance.new("BlurEffect")
        BlurEffect.Parent = lighting
        BlurEffect.Size = 6

        local ColorCorrectionEffect = Instance.new("ColorCorrectionEffect")
        ColorCorrectionEffect.Parent = lighting
        ColorCorrectionEffect.Brightness = 0.01
        ColorCorrectionEffect.Contrast = 0.15
        ColorCorrectionEffect.Saturation = 0.4
        ColorCorrectionEffect.TintColor = Color3.new(0.815686, 0.776471, 0.690196)

    elseif name == "Nebula Peaks" then
        local Sky = Instance.new("Sky")
        Sky.Name = name
        Sky.Parent = lighting
        Sky.CelestialBodiesShown = false
        Sky.SkyboxBk = "http://www.roblox.com/asset/?id=17124357467"
        Sky.SkyboxDn = "http://www.roblox.com/asset/?id=17124359797"
        Sky.SkyboxFt = "http://www.roblox.com/asset/?id=17124362093"
        Sky.SkyboxLf = "http://www.roblox.com/asset/?id=17124365127"
        Sky.SkyboxRt = "http://www.roblox.com/asset/?id=17124367200"
        Sky.SkyboxUp = "http://www.roblox.com/asset/?id=17124369657"

        local cc = Instance.new("ColorCorrectionEffect")
        cc.Parent = lighting
        cc.Brightness = 0.1
        cc.Contrast = 0.3
        cc.Saturation = 0.2
        cc.TintColor = Color3.fromRGB(140, 190, 255)

        local bloom = Instance.new("BloomEffect")
        bloom.Parent = lighting
        bloom.Intensity = 1.2
        bloom.Threshold = 0.8
        bloom.Size = 56

        local atmosphere = Instance.new("Atmosphere")
        atmosphere.Parent = lighting
        atmosphere.Density = 0.25
        atmosphere.Offset = 0.2
        atmosphere.Glare = 0.3
        atmosphere.Haze = 1
        atmosphere.Color = Color3.fromRGB(80, 110, 150)
        atmosphere.Decay = Color3.fromRGB(25, 30, 35)

    elseif name == "Rose Glow" then
        local Sky = Instance.new("Sky")
        Sky.Name = name
        Sky.Parent = lighting
        Sky.CelestialBodiesShown = false
        Sky.SkyboxBk = "http://www.roblox.com/asset/?id=109305193"
        Sky.SkyboxDn = "http://www.roblox.com/asset?id=58372722"
        Sky.SkyboxFt = "http://www.roblox.com/asset/?id=109305200"
        Sky.SkyboxLf = "http://www.roblox.com/asset/?id=109305185"
        Sky.SkyboxRt = "http://www.roblox.com/asset/?id=109305189"
        Sky.SkyboxUp = "http://www.roblox.com/asset/?id=109305207"

    elseif name == "Night Sky" then
        local Sky = Instance.new("Sky")
        Sky.Name = name
        Sky.Parent = lighting
        Sky.CelestialBodiesShown = false
        Sky.SkyboxBk = "http://www.roblox.com/Asset/?ID=12064107"
        Sky.SkyboxDn = "http://www.roblox.com/Asset/?ID=12064152"
        Sky.SkyboxFt = "http://www.roblox.com/Asset/?ID=12064121"
        Sky.SkyboxLf = "http://www.roblox.com/Asset/?ID=12063984"
        Sky.SkyboxRt = "http://www.roblox.com/Asset/?ID=12064115"
        Sky.SkyboxUp = "http://www.roblox.com/Asset/?ID=12064131"
        Sky.StarCount = 0

    elseif name == "Northern Lights" then
        local Sky = Instance.new("Sky")
        Sky.Name = name
        Sky.Parent = lighting
        Sky.CelestialBodiesShown = false
        Sky.SkyboxBk = "http://www.roblox.com/asset/?id=16563478983"
        Sky.SkyboxDn = "http://www.roblox.com/asset/?id=16563481302"
        Sky.SkyboxFt = "http://www.roblox.com/asset/?id=16563484084"
        Sky.SkyboxLf = "http://www.roblox.com/asset/?id=16563485362"
        Sky.SkyboxRt = "http://www.roblox.com/asset/?id=16563487078"
        Sky.SkyboxUp = "http://www.roblox.com/asset/?id=16563489821"
    end
end

local skyNames = {'Golden Twilight', 'Infernal Horizon', 'Nebula Peaks', 'Rose Glow', 'Night Sky', 'Northern Lights'}

for _, skyName in next, skyNames do
    VisualTab:CreateButton({
        Name = skyName,
        Tip = 'Applies the ' .. skyName .. ' skybox.',
        Callback = function()
            ApplySkyBox(skyName)
        end
    })
end

local DefenseTab = Window:CreateTab({ Name = 'Defense', Icon = 'rbxassetid://14939023862' })


tpTackle = DefenseTab:CreateToggle({
    Name = 'TP Tackle',
    Default = false,
    Tip = 'Short blink toward ball carrier on tackle press (E / click).',
})
tpTackleRange = DefenseTab:CreateSlider({
    Name = 'TP Tackle Range',
    Min = 5,
    Max = 30,
    Default = 14,
    Increment = 0.5,
})



guardAutoJump = DefenseTab:CreateToggle({
    Name = 'Guard Auto Jump',
    Default = false,
    Tip = 'Jumps when ball is high near you while guarding.',
})

task.spawn(function()
    while true do
        task.wait(0.08)
        if not guardAutoJump or not guardAutoJump.Value then continue end
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass('Humanoid')
        local hrp = char and char:FindFirstChild('HumanoidRootPart')
        if not hum or not hrp then continue end
        for _, ball in ipairs(workspace:GetChildren()) do
            if ball:IsA('BasePart') and ball.Name == 'Football' then
                local d = (ball.Position - hrp.Position).Magnitude
                if d < 18 and ball.Position.Y > hrp.Position.Y + 3 then
                    pcall(function()
                        hum.Jump = true
                        hum:ChangeState(Enum.HumanoidStateType.Jumping)
                    end)
                    break
                end
            end
        end
    end
end)


coverCushion = DefenseTab:CreateSlider({
    Name = 'Coverage Cushion',
    Min = 0,
    Max = 12,
    Default = 3,
    Increment = 0.5,
    Tip = 'Extra space off the receiver in Auto Guard / Man Lock.',
})
coverPRDepth = DefenseTab:CreateSlider({
    Name = 'PR Depth',
    Min = 5,
    Max = 40,
    Default = 18,
    Increment = 1,
    Tip = 'How deep zone/PR style guard sits.',
})
coverReaction = DefenseTab:CreateSlider({
    Name = 'Coverage Reaction',
    Min = 0,
    Max = 0.6,
    Default = 0.1,
    Increment = 0.05,
})

autoGuardMode = DefenseTab:CreateDropdown({
    Name = 'Auto Guard Mode',
    Options = {'Man', 'Zone', 'Deep'},
    Default = 'Man',
    Tip = 'How Auto Guard picks who to face.',
})

userInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if not tpTackle or not tpTackle.Value then return end
    if input.KeyCode ~= Enum.KeyCode.E and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    local char = player.Character
    local hrp = char and char:FindFirstChild('HumanoidRootPart')
    if not hrp then return end
    local best, bd = nil, tonumber(tpTackleRange.Value) or 14
    for _, plr in ipairs(players:GetPlayers()) do
        if plr == player then continue end
        local oc = plr.Character
        if not oc or not oc:FindFirstChild('Football') then continue end
        local thrp = oc:FindFirstChild('HumanoidRootPart')
        if not thrp then continue end
        local d = (thrp.Position - hrp.Position).Magnitude
        if d < bd then bd = d best = thrp end
    end
    if best then
        local dir = (best.Position - hrp.Position)
        if dir.Magnitude > 0.1 then
            local step = math.min(dir.Magnitude * 0.55, 10)
            hrp.CFrame = hrp.CFrame + dir.Unit * step
            local look = Vector3.new(dir.X, 0, dir.Z)
            if look.Magnitude > 0.1 then
                hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + look.Unit)
            end
        end
    end
end)


blockAura = DefenseTab:CreateToggle({
    Name = 'Block Aura',
    Default = false,
    Tip = 'Touches nearby rushers with block parts in radius.',
})
blockAuraRadius = DefenseTab:CreateSlider({
    Name = 'Block Activation Radius',
    Min = 1,
    Max = 25,
    Default = 10,
    Increment = 0.5,
})
blockMultiplier = DefenseTab:CreateSlider({
    Name = 'Block Multiplier',
    Min = 1,
    Max = 5,
    Default = 1,
    Increment = 0.1,
    Tip = 'How many touch pulses per tick.',
})
glidePower = DefenseTab:CreateSlider({
    Name = 'Glide Power',
    Min = 0,
    Max = 40,
    Default = 2,
    Increment = 1,
    Tip = 'Forward glide assist while tackling.',
})
showBlockHitbox = DefenseTab:CreateToggle({
    Name = 'Show Block Hitbox',
    Default = false,
})

task.spawn(function()
    local box
    while true do
        task.wait(0.06)
        local char = player.Character
        local hrp = char and char:FindFirstChild('HumanoidRootPart')
        if not hrp then continue end

        local rad = (blockAuraRadius and tonumber(blockAuraRadius.Value)) or 10
        if showBlockHitbox and showBlockHitbox.Value then
            if not box then
                box = Instance.new('Part')
                box.Shape = Enum.PartType.Ball
                box.Anchored = true
                box.CanCollide = false
                box.Material = Enum.Material.ForceField
                box.Color = Color3.fromRGB(100, 180, 255)
                box.Transparency = 0.7
                box.Parent = workspace.Terrain
            end
            box.Size = Vector3.new(rad * 2, rad * 2, rad * 2)
            box.Position = hrp.Position
        elseif box then
            pcall(function() box:Destroy() end)
            box = nil
        end

        if blockAura and blockAura.Value and firetouchinterest then
            local mult = math.floor((blockMultiplier and tonumber(blockMultiplier.Value)) or 1)
            for _, plr in ipairs(players:GetPlayers()) do
                if plr == player then continue end
                if player.Team and plr.Team and plr.Team == player.Team then continue end
                local thrp = plr.Character and plr.Character:FindFirstChild('HumanoidRootPart')
                if not thrp then continue end
                if (thrp.Position - hrp.Position).Magnitude > rad then continue end
                for _, p in ipairs(char:GetChildren()) do
                    if p:IsA('BasePart') and p.Name:lower():find('block') then
                        for _ = 1, mult do
                            pcall(firetouchinterest, p, thrp, 0)
                            pcall(firetouchinterest, p, thrp, 1)
                        end
                    end
                end
            end
        end

        if glidePower and tonumber(glidePower.Value) and glidePower.Value > 0 then
            local hum = char:FindFirstChildOfClass('Humanoid')
            if hum and hum:GetState() == Enum.HumanoidStateType.Freefall then
                local look = hrp.CFrame.LookVector
                local v = hrp.AssemblyLinearVelocity
                local g = tonumber(glidePower.Value) or 0
                hrp.AssemblyLinearVelocity = Vector3.new(look.X * g + v.X * 0.2, v.Y, look.Z * g + v.Z * 0.2)
            end
        end
    end
end)



swatReach = DefenseTab:CreateToggle({
    Name = 'Swat Reach',
    Default = false,
    Tip = 'Extends swat range on nearby footballs.',
})

swatReachDistance = DefenseTab:CreateSlider({
    Name = 'Swat Reach Radius',
    Min = 0,
    Max = 25,
    Default = 8,
    Increment = 0.1,
    Suffix = '',
    Tip = 'Sets the maximum swat distance.',
})

task.spawn(function()
    while true do
        task.wait()

        if not swatReach.Value then continue end

        local character = player.Character
        if not character then continue end

        local ball = findClosestBall()
        if not ball then continue end

        for _, v in next, character:GetChildren() do
            if v:IsA('BasePart') and v.Name:lower():find('catch') then
                local distance = (ball.Position - v.Position).Magnitude
                if distance < swatReachDistance.Value then
                    if v.Size.X > 2 then
                        firetouchinterest(v, ball, 0)
                        firetouchinterest(v, ball, 1)
                    end
                end
            end
        end
    end
end)

DefenseTab:CreateDivider()

tackleReach = DefenseTab:CreateToggle({
    Name = 'Extend Tackle Reach',
    Default = false,
    Tip = 'Extends tackle range against ball carriers.',
})

tackleAimbot = DefenseTab:CreateToggle({
    Name = 'Tackle Aimbot',
    Default = false,
    Tip = 'Automatically targets nearby ball carriers.',
})

tackleAimbotRange = DefenseTab:CreateSlider({
    Name = 'Tackle Aimbot Distance',
    Min = 0,
    Max = 25,
    Default = 10,
    Increment = 0.1,
    Suffix = '',
    Tip = 'Sets the maximum targeting distance.',
})

task.spawn(function()
    while true do
        task.wait()

        local character = player.Character
        if not character then continue end

        if tackleReach.Value then
            for _, v in next, players:GetPlayers() do
                if v ~= player and v.Team ~= player.Team and v.Character and v.Character:FindFirstChild('Football') then
                    local bodyParts = {'Torso', 'Head', 'HumanoidRootPart', 'Left Arm', 'Left Leg', 'Right Arm', 'Right Leg'}
                    local randomPart = bodyParts[math.random(1, #bodyParts)]

                    replicatedStorage.Remotes.CharacterSoundEvent:FireServer('Game', 'TackleTouch', randomPart, randomPart)
                end
            end
        end

        if tackleAimbot.Value then
            local hrp = character:FindFirstChild('HumanoidRootPart')
            if hrp then
                for _, v in next, players:GetPlayers() do
                    if v == player then continue end
                    if player.Team and v.Team and v.Team == player.Team then continue end
                    local vc = v.Character
                    if not vc or not vc:FindFirstChild('Football') then continue end
                    local thrp = vc:FindFirstChild('HumanoidRootPart')
                    local hum = vc:FindFirstChildOfClass('Humanoid')
                    if not thrp or not hum or hum.WalkSpeed <= 0 then continue end
                    local distance = (thrp.Position - hrp.Position).Magnitude
                    if distance < (tonumber(tackleAimbotRange.Value) or 10) then
                        local look = Vector3.new(thrp.Position.X - hrp.Position.X, 0, thrp.Position.Z - hrp.Position.Z)
                        if look.Magnitude > 0.1 then
                            hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + look.Unit)
                        end
                        break
                    end
                end
            end
        end
    end
end)


clickTackle = DefenseTab:CreateToggle({
    Name = 'Click Tackle',
    Default = false,
    Tip = 'Click/tap to aim tackle at nearest ball carrier in range.',
})

clickTackleRange = DefenseTab:CreateSlider({
    Name = 'Click Tackle Range',
    Min = 1,
    Max = 30,
    Default = 12,
    Increment = 0.5,
    Tip = 'Max distance for click tackle target.',
})

task.spawn(function()
    local btn
    local function tryTackle()
        if not clickTackle or not clickTackle.Value then return end
        local carrier = nearestCarrier(tonumber(clickTackleRange.Value) or 12)
        if not carrier then return end
        local char = lp.Character
        if not char then return end
        local hrp = char:FindFirstChild('HumanoidRootPart')
        local thrp = carrier:FindFirstChild('HumanoidRootPart')
        if not hrp or not thrp then return end
        local look = Vector3.new(thrp.Position.X - hrp.Position.X, 0, thrp.Position.Z - hrp.Position.Z)
        if look.Magnitude > 0.1 then
            hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + look.Unit)
        end
        if firetouchinterest then
            for _, p in ipairs(char:GetChildren()) do
                if p:IsA('BasePart') and (p.Name:lower():find('hand') or p.Name:lower():find('arm') or p.Name:lower():find('tackle')) then
                    pcall(firetouchinterest, p, thrp, 0)
                    pcall(firetouchinterest, p, thrp, 1)
                end
            end
        end
        pcall(function()
            yuriFire('PlayerActions', 'tackle')
            yuriFire('Game', 'Tackle')
        end)
    end
    while true do
        task.wait(0.3)
        if clickTackle and clickTackle.Value and userInputService.TouchEnabled then
            if not btn or not btn.Parent then
                local pg = player:FindFirstChild('PlayerGui') or player:WaitForChild('PlayerGui', 2)
                if not pg then continue end
                local g = pg:FindFirstChild('YuriMobileTackle')
                if not g then
                    g = Instance.new('ScreenGui')
                    g.Name = 'YuriMobileTackle'
                    g.ResetOnSpawn = false
                    g.Parent = pg
                end
                btn = Instance.new('TextButton')
                btn.Size = UDim2.fromOffset(72, 72)
                btn.Position = UDim2.new(1, -90, 0.55, 0)
                btn.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
                btn.Text = 'TACK'
                btn.TextColor3 = Color3.fromRGB(255, 120, 100)
                btn.TextSize = 14
                btn.Font = Enum.Font.GothamBold
                btn.Parent = g
                Instance.new('UICorner', btn).CornerRadius = UDim.new(0, 16)
                btn.MouseButton1Click:Connect(tryTackle)
            end
            if btn then btn.Visible = true end
        else
            if btn then btn.Visible = false end
        end
    end
end)



local function nearestCarrier(maxDist)
    local char = lp.Character
    if not char then return nil end
    local hrp = char:FindFirstChild('HumanoidRootPart')
    if not hrp then return nil end
    local best, bestD = nil, maxDist
    for _, plr in ipairs(players:GetPlayers()) do
        if plr == lp then continue end
        if lp.Team and plr.Team and lp.Team == plr.Team then continue end
        local c = plr.Character
        if not c or not c:FindFirstChild('Football') then continue end
        local thrp = c:FindFirstChild('HumanoidRootPart')
        if not thrp then continue end
        local d = (thrp.Position - hrp.Position).Magnitude
        if d < bestD then
            bestD = d
            best = c
        end
    end
    return best
end

userInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if not clickTackle or not clickTackle.Value then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    local carrier = nearestCarrier(tonumber(clickTackleRange.Value) or 12)
    if not carrier then return end
    local char = lp.Character
    if not char then return end
    local hrp = char:FindFirstChild('HumanoidRootPart')
    local thrp = carrier:FindFirstChild('HumanoidRootPart')
    if not hrp or not thrp then return end
    -- yaw-only face + touch tackle parts (no full CFrame snap freeze)
    local look = Vector3.new(thrp.Position.X - hrp.Position.X, 0, thrp.Position.Z - hrp.Position.Z)
    if look.Magnitude > 0.1 then
        hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + look.Unit)
    end
    pcall(function()
        local randomPart = thrp
        replicatedStorage.Remotes.CharacterSoundEvent:FireServer('Game', 'TackleTouch', randomPart, randomPart)
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA('BasePart') and part.Name:lower():find('tackle') then
                if firetouchinterest then
                    firetouchinterest(part, thrp, 0)
                    firetouchinterest(part, thrp, 1)
                end
            end
        end
    end)
end)


local AutomaticsTab = Window:CreateTab({ Name = 'Automatics', Icon = 'rbxassetid://86084882582277' })

autoReset = AutomaticsTab:CreateToggle({
    Name = 'Auto Reset',
    Default = false,
    Tip = 'Resets after being downed too long.',
})
autoFairCatch = AutomaticsTab:CreateToggle({
    Name = 'Auto Fair Catch',
    Default = false,
    Tip = 'Touches high balls for fair-catch style grab.',
})
autoGuard = AutomaticsTab:CreateToggle({
    Name = 'Auto Guard',
    Default = false,
    Tip = 'Faces nearest rusher when you have the ball.',
})
autoIntercept = AutomaticsTab:CreateToggle({
    Name = 'Auto Intercept',
    Default = false,
    Tip = 'Moves toward predicted ball path on defense.',
})
diveAimbot = AutomaticsTab:CreateToggle({
    Name = 'Dive Aimbot',
    Default = false,
    Tip = 'Aims toward nearest ball when diving.',
})
manLock = AutomaticsTab:CreateToggle({
    Name = 'Man Lock',
    Default = false,
    Tip = 'Faces nearest enemy receiver.',
})

task.spawn(function()
    local downedAt = 0
    while true do
        task.wait(0.08)
        local char = player.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass('Humanoid')
        local hrp = char:FindFirstChild('HumanoidRootPart')
        if not hum or not hrp then continue end

        if autoReset and autoReset.Value then
            local st = hum:GetState()
            if st == Enum.HumanoidStateType.FallingDown or st == Enum.HumanoidStateType.Ragdoll then
                if downedAt == 0 then downedAt = tick() end
                if tick() - downedAt > 2.5 then
                    pcall(function() hum.Health = 0 end)
                    downedAt = 0
                end
            else
                downedAt = 0
            end
        end

        if autoFairCatch and autoFairCatch.Value and firetouchinterest then
            for _, b in ipairs(workspace:GetChildren()) do
                if b:IsA('BasePart') and b.Name == 'Football' and b.Position.Y > 8 then
                    if (b.Position - hrp.Position).Magnitude < 20 then
                        for _, p in ipairs(char:GetChildren()) do
                            if p:IsA('BasePart') and p.Name:lower():find('catch') then
                                pcall(firetouchinterest, p, b, 0)
                                pcall(firetouchinterest, p, b, 1)
                            end
                        end
                        break
                    end
                end
            end
        end

        if autoGuard and autoGuard.Value and char:FindFirstChild('Football') then
            local best, bd = nil, 25
            for _, plr in ipairs(players:GetPlayers()) do
                if plr == player then continue end
                if player.Team and plr.Team and plr.Team == player.Team then continue end
                local thrp = plr.Character and plr.Character:FindFirstChild('HumanoidRootPart')
                if thrp then
                    local d = (thrp.Position - hrp.Position).Magnitude
                    if d < bd then bd = d best = thrp end
                end
            end
            if best then
                local look = Vector3.new(best.Position.X - hrp.Position.X, 0, best.Position.Z - hrp.Position.Z)
                if look.Magnitude > 0.1 then
                    hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + look.Unit)
                end
            end
        end

        if (autoIntercept and autoIntercept.Value) or (diveAimbot and diveAimbot.Value) then
            local bestBall, bd = nil, 40
            for _, b in ipairs(workspace:GetChildren()) do
                if b:IsA('BasePart') and b.Name == 'Football' then
                    local d = (b.Position - hrp.Position).Magnitude
                    if d < bd and b.AssemblyLinearVelocity.Magnitude > 2 then
                        bd = d
                        bestBall = b
                    end
                end
            end
            if bestBall then
                local pred = bestBall.Position + bestBall.AssemblyLinearVelocity * 0.35
                local look = Vector3.new(pred.X - hrp.Position.X, 0, pred.Z - hrp.Position.Z)
                if look.Magnitude > 0.1 then
                    hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + look.Unit)
                end
                if autoIntercept and autoIntercept.Value then
                    hum:MoveTo(pred)
                end
            end
        end

        if manLock and manLock.Value then
            local best, bd = nil, 50
            for _, plr in ipairs(players:GetPlayers()) do
                if plr == player then continue end
                if player.Team and plr.Team and plr.Team == player.Team then continue end
                local thrp = plr.Character and plr.Character:FindFirstChild('HumanoidRootPart')
                if thrp then
                    local d = (thrp.Position - hrp.Position).Magnitude
                    if d < bd then bd = d best = thrp end
                end
            end
            if best then
                local look = Vector3.new(best.Position.X - hrp.Position.X, 0, best.Position.Z - hrp.Position.Z)
                if look.Magnitude > 0.1 then
                    hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + look.Unit)
                end
            end
        end
    end
end)




walkToLOS = AutomaticsTab:CreateToggle({
    Name = 'Walk to LOS',
    Default = false,
    Tip = 'Walks toward line of scrimmage before the snap.',
})

onlyBehindLOS = AutomaticsTab:CreateToggle({
    Name = 'Only Behind LOS',
    Default = false,
    Tip = 'Stops auto-rush once past the line of scrimmage.',
})

keepRushingAfterThrow = AutomaticsTab:CreateToggle({
    Name = 'Keep Rushing After Throw',
    Default = false,
    Tip = 'Continues rush briefly after QB releases.',
})





autoVoteQB = AutomaticsTab:CreateToggle({
    Name = 'Auto Vote Self QB',
    Default = false,
})
autoFullback = AutomaticsTab:CreateToggle({
    Name = 'Auto Fullback',
    Default = false,
})

task.spawn(function()
    while true do
        task.wait(0.4)
        if autoVoteQB and autoVoteQB.Value then
            pcall(function()
                yuriFire('Game', 'VoteQB')
                yuriFire('Game', 'Vote')
                yuriFire('PlayerActions', 'voteQB')
                local rem = replicatedStorage:FindFirstChild('Remotes')
                if rem then
                    for _, r in ipairs(rem:GetDescendants()) do
                        if r:IsA('RemoteEvent') and r.Name:lower():find('vote') then
                            pcall(function() r:FireServer('QB') end)
                            pcall(function() r:FireServer(player) end)
                        end
                    end
                end
            end)
        end
        if autoFullback and autoFullback.Value then
            pcall(function()
                yuriFire('Game', 'Fullback')
                yuriFire('PlayerActions', 'fullback')
            end)
        end
    end
end)

autoRoute = AutomaticsTab:CreateToggle({
    Name = 'Auto Route',
    Default = false,
    Tip = 'Runs a route after the snap (go / slant / curl / corner / dig).',
})
autoRouteType = AutomaticsTab:CreateDropdown({
    Name = 'Route Type',
    Options = {'Go', 'Slant', 'Curl', 'Corner', 'Dig', 'Out'},
    Default = 'Go',
})
autoRouteDepth = AutomaticsTab:CreateSlider({
    Name = 'Route Depth',
    Min = 5,
    Max = 40,
    Default = 18,
    Increment = 1,
    Tip = 'How far downfield before the break.',
})

autoKnee = AutomaticsTab:CreateToggle({
    Name = 'Auto Knee',
    Default = false,
    Tip = 'Kneels when a defender enters the radius while you have the ball.',
})
autoKneeRadius = AutomaticsTab:CreateSlider({
    Name = 'Knee Radius',
    Min = 3,
    Max = 25,
    Default = 8,
    Increment = 0.5,
})


rushReactMin = AutomaticsTab:CreateSlider({
    Name = 'Rush Reaction Min',
    Min = 0,
    Max = 0.5,
    Default = 0.05,
    Increment = 0.01,
})
rushReactMax = AutomaticsTab:CreateSlider({
    Name = 'Rush Reaction Max',
    Min = 0,
    Max = 0.8,
    Default = 0.2,
    Increment = 0.01,
})
rushRandomDelay = AutomaticsTab:CreateSlider({
    Name = 'Rush Random Delay',
    Min = 0,
    Max = 0.5,
    Default = 0.05,
    Increment = 0.01,
})
showInterceptPoint = AutomaticsTab:CreateToggle({
    Name = 'Show Intercept Point',
    Default = false,
    Tip = 'Marks predicted rush intercept point.',
})

rushLead = AutomaticsTab:CreateSlider({
    Name = 'Rush Lead',
    Min = 0,
    Max = 15,
    Default = 4,
    Increment = 0.5,
    Tip = 'Predicts carrier movement while auto-rushing.',
})
rushCutoff = AutomaticsTab:CreateSlider({
    Name = 'Rush Cutoff Angle',
    Min = 0,
    Max = 90,
    Default = 35,
    Increment = 1,
    Tip = 'Approach angle bias for auto rush.',
})
rushReaction = AutomaticsTab:CreateSlider({
    Name = 'Rush Reaction',
    Min = 0,
    Max = 0.8,
    Default = 0.1,
    Increment = 0.05,
    Tip = 'Higher = more human delay before rush adjusts.',
})

task.spawn(function()
    local routeActive = false
    local routeOrigin = nil
    local routeDir = nil
    local lastRushAdj = 0
    while true do
        task.wait(0.08)
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass('Humanoid')
        local hrp = char and char:FindFirstChild('HumanoidRootPart')
        if not hum or not hrp then continue end

        local flags = replicatedStorage:FindFirstChild('Flags')
        local status = flags and flags:FindFirstChild('Status')
        local statusVal = status and status.Value or ''

        -- Auto Route
        if autoRoute and autoRoute.Value then
            if statusVal == 'PrePlay' then
                routeActive = false
                routeOrigin = hrp.Position
                routeDir = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
                if routeDir.Magnitude < 0.1 then routeDir = Vector3.new(0, 0, -1) else routeDir = routeDir.Unit end
            elseif statusVal ~= 'PrePlay' and not char:FindFirstChild('Football') then
                if not routeActive then
                    routeActive = true
                    routeOrigin = routeOrigin or hrp.Position
                    routeDir = routeDir or Vector3.new(0, 0, -1)
                end
                local depth = tonumber(autoRouteDepth.Value) or 18
                local rtype = tostring(autoRouteType.Value or 'Go')
                local forward = routeDir * depth
                local right = Vector3.new(-routeDir.Z, 0, routeDir.X)
                local targetPos = routeOrigin + forward
                if rtype == 'Slant' then
                    targetPos = routeOrigin + routeDir * (depth * 0.7) + right * (depth * 0.35)
                elseif rtype == 'Curl' then
                    local along = (hrp.Position - routeOrigin):Dot(routeDir)
                    if along < depth * 0.85 then
                        targetPos = routeOrigin + routeDir * depth
                    else
                        targetPos = routeOrigin + routeDir * (depth * 0.7) -- sit
                    end
                elseif rtype == 'Corner' then
                    targetPos = routeOrigin + routeDir * depth + right * (depth * 0.55)
                elseif rtype == 'Dig' then
                    targetPos = routeOrigin + routeDir * (depth * 0.75) + right * (depth * 0.5)
                elseif rtype == 'Out' then
                    targetPos = routeOrigin + routeDir * (depth * 0.5) + right * depth
                end
                hum:MoveTo(targetPos)
            end
        else
            routeActive = false
        end

        -- Auto Knee
        if autoKnee and autoKnee.Value and char:FindFirstChild('Football') then
            local rad = tonumber(autoKneeRadius.Value) or 8
            for _, plr in ipairs(players:GetPlayers()) do
                if plr == player then continue end
                if player.Team and plr.Team and plr.Team == player.Team then continue end
                local thrp = plr.Character and plr.Character:FindFirstChild('HumanoidRootPart')
                if thrp and (thrp.Position - hrp.Position).Magnitude <= rad then
                    pcall(function()
                        local rem = replicatedStorage:FindFirstChild('Remotes')
                        if rem and rem:FindFirstChild('CharacterSoundEvent') then
                            rem.CharacterSoundEvent:FireServer('Game', 'Knee')
                            rem.CharacterSoundEvent:FireServer('PlayerActions', 'knee')
                        end
                    end)
                    break
                end
            end
        end
    end
end)


autoFollowQB = AutomaticsTab:CreateToggle({
    Name = 'Auto Follow QB',
    Default = false,
    Tip = 'Walk toward teammate who has the ball (receiver side).',
})
autoFollowDistance = AutomaticsTab:CreateSlider({
    Name = 'Follow Distance',
    Min = 5,
    Max = 40,
    Default = 12,
    Increment = 1,
})

task.spawn(function()
    while true do
        task.wait(0.1)
        if not autoFollowQB or not autoFollowQB.Value then continue end
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass('Humanoid')
        local hrp = char and char:FindFirstChild('HumanoidRootPart')
        if not hum or not hrp then continue end
        if char:FindFirstChild('Football') then continue end
        local best, bd = nil, 120
        for _, plr in ipairs(players:GetPlayers()) do
            if plr == player then continue end
            if player.Team and plr.Team and plr.Team ~= player.Team then continue end
            local oc = plr.Character
            if not oc or not oc:FindFirstChild('Football') then continue end
            local thrp = oc:FindFirstChild('HumanoidRootPart')
            if thrp then
                local d = (thrp.Position - hrp.Position).Magnitude
                if d < bd then bd = d best = thrp end
            end
        end
        if best then
            local hold = tonumber(autoFollowDistance.Value) or 12
            if bd > hold then
                hum:MoveTo(best.Position)
            end
        end
    end
end)


autoRush = AutomaticsTab:CreateToggle({
    Name = 'Auto Rush',
    Default = false,
    Tip = 'Automatically moves toward the opposing ball carrier in range.',
})

walkToLine = AutomaticsTab:CreateToggle({
    Name = 'Walk To Line',
    Default = false,
    Tip = 'Moves the player to the line before play starts.',
})

autoRushReactionTime = AutomaticsTab:CreateSlider({
    Name = 'Reaction Time',
    Min = 0,
    Max = 1,
    Default = 0.1,
    Increment = 0.01,
    Suffix = '',
    Tip = 'Adjusts how quickly the feature responds.',
})

task.spawn(function()
    while true do
        task.wait(autoRush.Value and 0.05 or 0.15)

        if not autoRush.Value then continue end
        -- RushLeadWire uses rushLead/rushReaction globals when set


        -- Aikeo: don't move to ball before play starts (WR mode)
        do
            local st = replicatedStorage:FindFirstChild('Flags')
            st = st and st:FindFirstChild('Status')
            local statusVal = st and st.Value
            if statusVal == 'PrePlay' then
                if walkToLOS and walkToLOS.Value then
                    local char = player.Character
                    local hum = char and char:FindFirstChildOfClass('Humanoid')
                    local hrp = char and char:FindFirstChild('HumanoidRootPart')
                    if hum and hrp then
                        pcall(function()
                            hum:MoveTo(hrp.Position + hrp.CFrame.LookVector * 12)
                        end)
                    end
                end
                continue
            end
        end

        local character = player.Character
        if not character then continue end

        local humanoid = character:FindFirstChildOfClass('Humanoid')
        if not humanoid then continue end

        local hrp = character:FindFirstChild('HumanoidRootPart')
        if not hrp then continue end

        if walkToLine.Value then
            if replicatedStorage:FindFirstChild('Flags')
                and replicatedStorage.Flags:FindFirstChild('PossessionTag')
                and replicatedStorage.Flags:FindFirstChild('Status')
                and player.Team and replicatedStorage.Flags.PossessionTag.Value ~= player.Team.Name
                and replicatedStorage.Flags.Status.Value == 'PrePlay' then

                local line = workspace:FindFirstChild('LineDown')
                if line then
                    humanoid:MoveTo(line.Position)
                end
            end
        end

        for _, v in next, players:GetPlayers() do
            if v == player then continue end
            if player.Team and v.Team and v.Team == player.Team then continue end
            if not v.Character then continue end

            local enemyChar = v.Character
            local enemyHumanoid = enemyChar:FindFirstChildOfClass('Humanoid')
            local enemyHrp = enemyChar:FindFirstChild('HumanoidRootPart')
            if not enemyHumanoid or not enemyHrp then continue end

            local football = enemyChar:FindFirstChild('Football')
            if not football then continue end

            local footballPart = football:FindFirstChildWhichIsA('BasePart')
            if not footballPart then continue end

            if enemyHumanoid.WalkSpeed <= 0 then continue end
            if enemyHumanoid.PlatformStand then continue end

            local ping = 0
            if stats and stats:FindFirstChild('Network') 
                and stats.Network:FindFirstChild('ServerStatsItem')
                and stats.Network.ServerStatsItem:FindFirstChild('Data Ping') then
                ping = stats.Network.ServerStatsItem['Data Ping']:GetValue() / 1000
            end

            local speed = enemyHumanoid.MoveDirection.Magnitude > 0 and enemyHumanoid.WalkSpeed or 0
            local react = (autoRushReactionTime and tonumber(autoRushReactionTime.Value)) or 0
            if rushReaction and tonumber(rushReaction.Value) then
                react = react + tonumber(rushReaction.Value)
            end
            local rmin = (rushReactMin and tonumber(rushReactMin.Value)) or 0
            local rmax = (rushReactMax and tonumber(rushReactMax.Value)) or rmin
            if rmax < rmin then rmax = rmin end
            react = react + rmin + (rmax - rmin) * math.random()
            local rdelay = (rushRandomDelay and tonumber(rushRandomDelay.Value)) or 0
            if rdelay > 0 then
                task.wait(math.random() * rdelay)
            end
            local predictionTime = ping + react

            local lead = (rushLead and tonumber(rushLead.Value)) or 0
            local moveDir = enemyHumanoid.MoveDirection
            if moveDir.Magnitude < 0.05 then
                moveDir = Vector3.new(enemyHrp.AssemblyLinearVelocity.X, 0, enemyHrp.AssemblyLinearVelocity.Z)
                if moveDir.Magnitude > 0.1 then moveDir = moveDir.Unit else moveDir = Vector3.zero end
            end
            -- improved lead: ping + reaction in seconds, speed in studs/s (no *20 inflation)
            local predT = math.clamp(predictionTime, 0, 0.55)
            local leadStuds = (tonumber(lead) or 0) * 0.35
            local velXZ = Vector3.new(enemyHrp.AssemblyLinearVelocity.X, 0, enemyHrp.AssemblyLinearVelocity.Z)
            local pos
            if moveDir.Magnitude > 0.05 then
                pos = footballPart.Position + moveDir.Unit * (speed * predT + leadStuds)
            elseif velXZ.Magnitude > 0.5 then
                pos = footballPart.Position + velXZ.Unit * (velXZ.Magnitude * predT + leadStuds)
            else
                pos = footballPart.Position
            end
            -- slight intercept bias toward our current approach
            local toMe = (hrp.Position - pos)
            if toMe.Magnitude > 4 then
                pos = pos + toMe.Unit * math.min(2.5, toMe.Magnitude * 0.08)
            end

            -- cutoff angle: bias approach from side
            if rushCutoff and tonumber(rushCutoff.Value) and rushCutoff.Value > 0 then
                local toCarrier = (enemyHrp.Position - hrp.Position)
                local flat = Vector3.new(toCarrier.X, 0, toCarrier.Z)
                if flat.Magnitude > 1 then
                    local side = Vector3.new(-flat.Unit.Z, 0, flat.Unit.X)
                    local ang = math.rad(tonumber(rushCutoff.Value) or 0)
                    pos = pos + side * (math.sin(ang) * 3)
                end
            end

            if showInterceptPoint and showInterceptPoint.Value then
                if not _G.YuriInterceptPart then
                    local p = Instance.new('Part')
                    p.Name = 'YuriIntercept'
                    p.Anchored = true
                    p.CanCollide = false
                    p.Size = Vector3.new(1.5, 0.2, 1.5)
                    p.Material = Enum.Material.Neon
                    p.Color = Color3.fromRGB(255, 100, 80)
                    p.Parent = workspace.Terrain
                    _G.YuriInterceptPart = p
                end
                _G.YuriInterceptPart.Position = pos
                _G.YuriInterceptPart.Transparency = 0.3
            elseif _G.YuriInterceptPart then
                _G.YuriInterceptPart.Transparency = 1
            end
            humanoid:MoveTo(pos)
        end
    end
end)

AutomaticsTab:CreateDivider()

ballOnGroundCheck = AutomaticsTab:CreateToggle({
    Name = 'Ball On Ground Check',
    Default = false,
    Tip = 'Auto Catch only when ball is low / grounded.',
})

autoCatch = AutomaticsTab:CreateToggle({
    Name = 'Auto Catch',
    Default = false,
    Tip = 'Fires the catch remote when a football is in range.',
})

autoCatchRadius = AutomaticsTab:CreateSlider({
    Name = 'Auto Catch Distance',
    Min = 0,
    Max = 25,
    Default = 12,
    Increment = 0.1,
    Suffix = '',
    Tip = 'Sets how far the auto catch detection can reach.',
})
    
AutomaticsTab:CreateDivider()

autoSwat = AutomaticsTab:CreateToggle({
    Name = 'Auto Swat',
    Default = false,
    Tip = 'Automatically reacts to nearby incoming balls.',
})

autoSwatRadius = AutomaticsTab:CreateSlider({
    Name = 'Auto Swat Distance',
    Min = 0,
    Max = 25,
    Default = 10,
    Increment = 0.1,
    Suffix = '',
    Tip = 'Sets how far the auto swat detection can reach.',
})

task.spawn(function()
    while true do
        task.wait((autoCatch and autoCatch.Value) or (autoSwat and autoSwat.Value) and 0.05 or 0.15)

        if not autoCatch.Value and not autoSwat.Value then continue end
        do
            local st = replicatedStorage:FindFirstChild('Flags')
            st = st and st:FindFirstChild('Status')
            if st and st.Value == 'PrePlay' then continue end
        end

        local character = player.Character
        if not character then continue end

        local humanoidRootPart = character:FindFirstChild('HumanoidRootPart')
        if not humanoidRootPart then continue end

        local ball = findClosestBall()
        if not ball then continue end

        local distance = (ball.Position - humanoidRootPart.Position).Magnitude

        if autoCatch.Value and distance <= autoCatchRadius.Value then
            -- Auto Catch = fire catch remote (that is the whole feature)
            local skip = false
            if ballOnGroundCheck and ballOnGroundCheck.Value and ball.Position.Y > 4 then
                skip = true
            end
            if not skip then
            pcall(function()
                local rem = replicatedStorage:FindFirstChild('Remotes')
                rem = rem and rem:FindFirstChild('CharacterSoundEvent')
                if rem then
                    rem:FireServer('PlayerActions', isPractice and 'catch ' or 'catch')
                end
            end)
            -- Auto Catch Click: touch catch parts instead of spam-only remote
            for _, partName in ipairs({'CatchRight', 'CatchLeft', 'RightHand', 'LeftHand', 'Right Arm', 'Left Arm'}) do
                local part = character:FindFirstChild(partName)
                if part and firetouchinterest then
                    pcall(firetouchinterest, part, ball, 0)
                    pcall(firetouchinterest, part, ball, 1)
                end
            end
            end -- ball on ground check else
        end

        if autoSwat.Value and distance <= autoSwatRadius.Value then
            pcall(function()
                replicatedStorage.Remotes.CharacterSoundEvent:FireServer('PlayerActions', 'swat')
            end)
        end
    end
end)
    
AutomaticsTab:CreateDivider()
    
autoCaptain = AutomaticsTab:CreateToggle({
    Name = 'Auto Win Captain',
    Default = false,
    Tip = 'Rewritten: snaps you to the captain finish line while no team is set.',
})

task.spawn(function()
    while true do
        task.wait(0.05)
        if not autoCaptain or not autoCaptain.Value then continue end
        if player.Team then continue end
        local character = player.Character
        local hrp = character and character:FindFirstChild('HumanoidRootPart')
        if not hrp then continue end
        local models = workspace:FindFirstChild('Models')
        if not models then continue end
        for _, roomName in ipairs({'LockerRoomA', 'LockerRoomB', 'LockerRoom'}) do
            local room = models:FindFirstChild(roomName)
            if not room then continue end
            for _, v in ipairs(room:GetChildren()) do
                local n = string.lower(v.Name)
                if n:find('finish') or n:find('finishline') then
                    local cf = v:IsA('BasePart') and v.CFrame or (v:IsA('Model') and v:GetPivot()) or nil
                    if cf then
                        hrp.CFrame = cf + Vector3.new(0, 2, 0)
                    end
                end
            end
        end
    end
end)
    
AutomaticsTab:CreateDivider()
    
autoFreeze = AutomaticsTab:CreateToggle({
    Name = 'Auto Freeze',
    Default = false,
    Tip = 'Temporarily anchors your character on input.',
})

freezeDuration = AutomaticsTab:CreateSlider({
    Name = 'Freeze Duration',
    Min = 0,
    Max = 3,
    Default = 0.8,
    Increment = 0.1,
    Suffix = '',
    Tip = 'Duration the freeze state lasts.',
})

freezeKeybind = AutomaticsTab:CreateKeybind({
    Name = 'Freeze Keybind',
    Default = nil,
    Tip = 'Key used to trigger freeze.',
})

userInputService.InputBegan:Connect(function(input)
    if not autoFreeze.Value then return end
    if freezeKeybind.Value and input.KeyCode ~= freezeKeybind.Value then return end

    local character = player.Character
    if not character then return end

    local hrp = character:FindFirstChild('HumanoidRootPart')
    if not hrp then return end

    hrp.Anchored = true

    task.delay(freezeDuration.Value, function()
        if hrp then
            hrp.Anchored = false
        end
    end)
end)

AutomaticsTab:CreateDivider()

autoGetQB = AutomaticsTab:CreateToggle({
    Name = 'Auto Get QB',
    Default = false,
    Tip = 'Move to the ball on offense (pickup).',
})
autoGetQBMethod = AutomaticsTab:CreateDropdown({
    Name = 'Get QB Method',
    Options = {'Walk', 'Teleport'},
    Default = 'Walk',
})

task.spawn(function()
    while true do
        task.wait(0.12)
        if not autoGetQB or not autoGetQB.Value then continue end
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass('Humanoid')
        local hrp = char and char:FindFirstChild('HumanoidRootPart')
        if not hum or not hrp or char:FindFirstChild('Football') then continue end
        local ball
        for _, v in ipairs(workspace:GetChildren()) do
            if v:IsA('BasePart') and v.Name == 'Football' then ball = v break end
        end
        if not ball then continue end
        local method = tostring(autoGetQBMethod and autoGetQBMethod.Value or 'Walk')
        if method == 'Teleport' and (ball.Position - hrp.Position).Magnitude < 40 then
            hrp.CFrame = CFrame.new(ball.Position + Vector3.new(0, 3, 0))
        else
            hum:MoveTo(ball.Position)
        end
    end
end)

autoQb = AutomaticsTab:CreateToggle({
    Name = 'Auto QB',
    Default = false,
    Tip = 'Automatically positions your character for quarterback play.',
})

autoQbMethod = AutomaticsTab:CreateDropdown({
    Name = 'Auto QB Method',
    Options = {'Walk', 'Teleport'},
    Default = 'Walk',
    Tip = 'Selects how automatic positioning is performed.',
})

task.spawn(function()
    while true do
        task.wait(0.1)
        if not autoQb.Value then continue end

        local character = player.Character
        if not character then continue end

        local humanoid = character:FindFirstChildOfClass('Humanoid')
        local humanoidRootPart = character:FindFirstChild('HumanoidRootPart')
        if not humanoid or not humanoidRootPart then continue end

        local flags = replicatedStorage:FindFirstChild('Flags')
        local status = flags and flags:FindFirstChild('Status')
        local statusVal = status and status.Value or ''
        local possession = flags and flags:FindFirstChild('PossessionTag')
        local hasBall = character:FindFirstChild('Football') ~= nil

        -- PrePlay: only move toward ball/spawn if WE have possession team - never mid-play chase
        if statusVal == 'PrePlay' then
            if possession and player.Team and possession.Value == player.Team.Name then
                local ball = findClosestBall()
                if ball then
                    if autoQbMethod.Value == 'Teleport' then
                        humanoidRootPart.CFrame = CFrame.new(ball.Position + Vector3.new(0, 3, 0))
                    else
                        humanoid:MoveTo(ball.Position)
                    end
                end
            end
            continue
        end

        -- In play with ball: let QBA handle throw; nudge power remote if possible
        if hasBall and (statusVal == 'InPlay' or statusVal == 'Play' or statusVal == '') then
            if enableQbAimbot and enableQbAimbot.Value then
                -- QBA active - do not teleport ball
            else
                -- light assist: face open field
                pcall(function()
                    local look = humanoidRootPart.CFrame.LookVector
                    humanoid:MoveTo(humanoidRootPart.Position + look * 8)
                end)
            end
        end
    end
end)
    
AutomaticsTab:CreateDivider()
    
    autoBoost = AutomaticsTab:CreateToggle({
    Name = 'Auto Boost',
    Default = false,
    Tip = 'Automatically assists aerial movement near incoming footballs.',
})

targetClosestPlayer = AutomaticsTab:CreateToggle({
    Name = 'Target Player Closer To The Ball',
    Default = false,
    Tip = 'Prioritizes players closest to the football.',
})

boostStrength = AutomaticsTab:CreateSlider({
    Name = 'Boost Strength',
    Min = 0,
    Max = 3,
    Default = 1.5,
    Increment = 0.1,
    Suffix = '',
    Tip = 'Adjusts the strength of the boost effect.',
})

boostRadius = AutomaticsTab:CreateSlider({
    Name = 'Boost Radius',
    Min = 0,
    Max = 15,
    Default = 6,
    Increment = 0.1,
    Suffix = '',
    Tip = 'Sets the activation distance for boosting.',
})

boostPower = AutomaticsTab:CreateSlider({
    Name = 'Auto Boost Power',
    Min = 50,
    Max = 70,
    Default = 50,
    Increment = 0.1,
    Suffix = '',
    Tip = 'Controls the upward force applied during a boost.',
})

task.spawn(function()
    local activeTween

    while true do
        task.wait()

        if not autoBoost.Value then
            if activeTween then
                activeTween:Cancel()
                activeTween = nil
            end

            continue
        end

        local char = player.Character
        if not char then continue end

        local hum = char:FindFirstChildOfClass('Humanoid')
        if not hum then continue end

        local hrp = char:FindFirstChild('HumanoidRootPart')
        if not hrp then continue end

        if hum:GetState() == Enum.HumanoidStateType.Landed then
            if activeTween then
                activeTween:Cancel()
                activeTween = nil
            end

            continue
        end

        local myHead = char:FindFirstChild('Head')
        if not myHead then continue end

        local targetPlayer

        if targetClosestPlayer.Value then
            local nearestBall
            local nearestBallDist = math.huge

            for _, ball in next, workspace:GetChildren() do
                if not ball:IsA('BasePart') then continue end
                if not ball.Name:lower():find('ball') then continue end

                local dist = (ball.Position - myHead.Position).Magnitude

                if dist < nearestBallDist then
                    nearestBallDist = dist
                    nearestBall = ball
                end
            end

            if not nearestBall then continue end

            local closestDist = math.huge

            for _, v in next, players:GetPlayers() do
                if v == player then continue end

                local character = v.Character
                if not character then continue end

                local head = character:FindFirstChild('Head')
                if not head then continue end

                local dist = (head.Position - nearestBall.Position).Magnitude

                if dist < closestDist then
                    closestDist = dist
                    targetPlayer = v
                end
            end
        else
            local closestDist = math.huge

            for _, v in next, players:GetPlayers() do
                if v == player then continue end

                local character = v.Character
                if not character then continue end

                local head = character:FindFirstChild('Head')
                if not head then continue end

                local dist = (head.Position - myHead.Position).Magnitude

                if dist < closestDist then
                    closestDist = dist
                    targetPlayer = v
                end
            end
        end

        if not targetPlayer then continue end

        local character = targetPlayer.Character
        if not character then continue end

        local head = character:FindFirstChild('Head')
        if not head then continue end

        local targetHumanoid = character:FindFirstChildOfClass('Humanoid')
        if not targetHumanoid then continue end

        local myState = hum:GetState()
        local targetState = targetHumanoid:GetState()

        local distance = (head.Position - myHead.Position).Magnitude

        if distance > boostRadius.Value then
            continue
        end

        if myState ~= Enum.HumanoidStateType.Jumping
            and myState ~= Enum.HumanoidStateType.Freefall then
            continue
        end

        if targetState ~= Enum.HumanoidStateType.Jumping
            and targetState ~= Enum.HumanoidStateType.Freefall then
            continue
        end

        local speed = math.max(hum.WalkSpeed * boostStrength.Value, 1)
        local targetPos = head.Position

        local duration = math.max((hrp.Position - targetPos).Magnitude / speed, 0.01)

        if activeTween then
            activeTween:Cancel()
        end

        activeTween = tweenService:Create(
            hrp,
            TweenInfo.new(duration, Enum.EasingStyle.Linear),
            {
                CFrame = CFrame.new(targetPos)
            }
        )

        activeTween:Play()

        activeTween.Completed:Once(function(state)
            if state ~= Enum.PlaybackState.Completed then
                return
            end

            hrp.AssemblyLinearVelocity = Vector3.new(
                hrp.AssemblyLinearVelocity.X,
                boostPower.Value,
                hrp.AssemblyLinearVelocity.Z
            )
        end)
    end
end)


local KickerTab = Window:CreateTab({ Name = 'Kicker', Icon = 'rbxassetid://6031225988' })

forceKick = KickerTab:CreateToggle({
    Name = 'Force Kick',
    Default = false,
    Tip = 'Holds kicker power/angle at your slider values.',
})



autoKick = KickerTab:CreateToggle({
    Name = 'Auto Kick',
    Default = false,
    Tip = 'Automatically kicks when you are the kicker with the ball.',
})

task.spawn(function()
    while true do
        task.wait(0.15)
        if not autoKick.Value then continue end
        local char = player.Character
        if not char then continue end
        local ball = char:FindFirstChild('Football')
        if not ball then continue end
        -- try common kick remotes / rely on kicker aimbot path
        pcall(function()
            if kickerAimbot and kickerAimbot.Value then
                -- aimbot loop handles trajectory; nudge kick input
                if replicatedStorage:FindFirstChild('Remotes') then
                    local r = replicatedStorage.Remotes:FindFirstChild('CharacterSoundEvent')
                    -- many FF builds use BallGui kick; virtual click not available - face uprights
                    local hrp = char:FindFirstChild('HumanoidRootPart')
                    if hrp and workspace:FindFirstChild('Models') then
                        local goal = workspace.Models:FindFirstChild('GoalPost') or workspace.Models:FindFirstChild('GoalPosts')
                        -- face field end
                        local look = hrp.CFrame.LookVector
                        hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + Vector3.new(look.X, 0, look.Z))
                    end
                end
            end
        end)
    end
end)


kickerAimbot = KickerTab:CreateToggle({
    Name = 'Kicker Aimbot',
    Default = false,
    Tip = 'Aims kicks toward the uprights.',
})

kickerAlwaysScore = KickerTab:CreateToggle({
    Name = 'Always Score (Randomize)',
    Default = true,
    Tip = 'Randomizes power/angle slightly within a scoring window.',
})

kickerPower = KickerTab:CreateSlider({
    Name = 'Kicker Power',
    Min = 40,
    Max = 96,
    Default = 72,
    Increment = 1,
    Tip = 'Base kick power.',
})

kickerAngle = KickerTab:CreateSlider({
    Name = 'Kicker Angle',
    Min = 25,
    Max = 49,
    Default = 36,
    Increment = 1,
    Tip = 'Base kick angle.',
})

task.spawn(function()
    local function findGoal()
        local best, bestDist = nil, math.huge
        local myChar = player.Character
        local hrp = myChar and myChar:FindFirstChild('HumanoidRootPart')
        if not hrp then return nil end
        for _, inst in ipairs(workspace:GetDescendants()) do
            local n = inst.Name:lower()
            if inst:IsA('BasePart') and (n:find('upright') or n:find('goalpost') or n:find('crossbar') or n == 'goal') then
                local d = (inst.Position - hrp.Position).Magnitude
                if d < bestDist then
                    bestDist = d
                    best = inst
                end
            end
        end
        return best
    end

    while true do
        task.wait(0.05)
        if forceKick and forceKick.Value then
            -- hold values; aimbot path still aims
        end
        if not kickerAimbot.Value and not (forceKick and forceKick.Value) then continue end

        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild('HumanoidRootPart')
        local hum = char:FindFirstChildOfClass('Humanoid')
        if not hrp or not hum then continue end

        local goal = findGoal()
        if not goal then continue end

        local flat = Vector3.new(goal.Position.X - hrp.Position.X, 0, goal.Position.Z - hrp.Position.Z)
        if flat.Magnitude < 1 then continue end

        -- yaw only - don't tip the body sideways
        local targetCF = CFrame.new(hrp.Position, hrp.Position + flat.Unit)
        hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, select(2, targetCF:ToOrientation()), 0)

        if kickerAlwaysScore.Value then
            -- keep power/angle in a scoring band with light jitter
            local p = kickerPower.Value + (math.random() * 4 - 2)
            local a = kickerAngle.Value + (math.random() * 2 - 1)
            p = math.clamp(p, 55, 90)
            a = math.clamp(a, 30, 42)
            -- expose for any UI/HUD that reads these
            kickerPower.Value = kickerPower.Value -- keep user base
            -- optional: write attributes some FF kick UIs read
            pcall(function()
                char:SetAttribute('KickPower', p)
                char:SetAttribute('KickAngle', a)
            end)
        end
    end
end)



local ExtraTab = Window:CreateTab({ Name = 'Extra', Icon = 'rbxassetid://6031280882' })

diveAssist = ExtraTab:CreateToggle({
    Name = 'Dive Assist',
    Default = false,
    Tip = 'Steers dive direction toward the ball.',
})

diveEnhancer = ExtraTab:CreateToggle({
    Name = 'Dive Enhancer',
    Default = false,
    Tip = 'Increases dive force.',
})

diveEnhancerPower = ExtraTab:CreateSlider({
    Name = 'Dive Force',
    Min = 20,
    Max = 80,
    Default = 45,
    Increment = 1,
})

autoJumpCatch = ExtraTab:CreateToggle({
    Name = 'Auto Jump (Catch)',
    Default = false,
    Tip = 'Jumps for short/slant/chest height balls.',
})

autoJumpMinHeight = ExtraTab:CreateSlider({
    Name = 'Auto Jump Min Height',
    Min = 2,
    Max = 12,
    Default = 4,
    Increment = 0.5,
})

autoPop = ExtraTab:CreateToggle({
    Name = 'Auto Pop',
    Default = false,
    Tip = 'About 50% chance to pop timing on contact window.',
})

autoFumble = ExtraTab:CreateToggle({
    Name = 'Auto Fumble',
    Default = false,
    Tip = '15% chance to TP toward airborne ball carrier.',
})

antiFumble = ExtraTab:CreateToggle({
    Name = 'Anti Fumble',
    Default = false,
    Tip = 'Moves you away from DBs trying to hitstick while you have the ball.',
})

antiFumbleRange = ExtraTab:CreateSlider({
    Name = 'Anti Fumble Range',
    Min = 4,
    Max = 20,
    Default = 10,
    Increment = 0.5,
})

hitstickAimbot = ExtraTab:CreateToggle({
    Name = 'Hitstick Aimbot',
    Default = false,
    Tip = 'Aims hitstick/tackle toward ball carrier.',
})

hitstickAssist = ExtraTab:CreateToggle({
    Name = 'Hitstick Assist',
    Default = false,
    Tip = 'Adds a short burst toward the carrier on tackle input window.',
})

hitstickRange = ExtraTab:CreateSlider({
    Name = 'Hitstick Range',
    Min = 5,
    Max = 25,
    Default = 12,
    Increment = 0.5,
})

blockKickReach = ExtraTab:CreateToggle({
    Name = 'Block Kick Reach',
    Default = false,
    Tip = 'Extends reach to block opponent kicks.',
})

blockKickDistance = ExtraTab:CreateSlider({
    Name = 'Block Kick Distance',
    Min = 5,
    Max = 30,
    Default = 14,
    Increment = 0.5,
})

autoFreezeOnCatch = ExtraTab:CreateToggle({
    Name = 'Auto Freeze (On Catch)',
    Default = false,
    Tip = 'Briefly anchors after securing the ball.',
})

freezeOnCatchTime = ExtraTab:CreateSlider({
    Name = 'Freeze On Catch Time',
    Min = 0.05,
    Max = 1.5,
    Default = 1,
    Increment = 0.05,
})

aerialMagnets = ExtraTab:CreateToggle({
    Name = 'Aerial Magnets',
    Default = false,
    Tip = 'Pulls you under a dropping ball for an easier catch.',
})

aerialMagRange = ExtraTab:CreateSlider({
    Name = 'Aerial Mag Range',
    Min = 5,
    Max = 30,
    Default = 14,
    Increment = 0.5,
})

autoShoulder = ExtraTab:CreateToggle({
    Name = 'Auto Shoulder',
    Default = false,
    Tip = 'Small boost toward ball on contested catch window.',
})

autoShoulderPower = ExtraTab:CreateSlider({
    Name = 'Shoulder Boost',
    Min = 10,
    Max = 60,
    Default = 28,
    Increment = 1,
})

autoReel = ExtraTab:CreateToggle({
    Name = 'Auto Reel',
    Default = false,
    Tip = 'Uses a safer reel-style lead when a DB is in front of the WR.',
})

autoReelPower = ExtraTab:CreateSlider({
    Name = 'Auto Reel Power',
    Min = 40,
    Max = 90,
    Default = 62,
    Increment = 1,
})

kickerAutoMove = ExtraTab:CreateToggle({
    Name = 'Kicker Auto Move',
    Default = false,
    Tip = 'Walks/positions toward kick spot while kicker aimbot is on.',
})

-- Dive assist + enhancer
task.spawn(function()
    while true do
        task.wait()
        if not diveAssist.Value and not diveEnhancer.Value then continue end
        local char = player.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass('Humanoid')
        local hrp = char:FindFirstChild('HumanoidRootPart')
        if not hum or not hrp then continue end
        local st = hum:GetState()
        if st ~= Enum.HumanoidStateType.Freefall and st ~= Enum.HumanoidStateType.Jumping and st ~= Enum.HumanoidStateType.Physics then
            continue
        end
        local ball = findClosestBall and findClosestBall()
        if not ball then continue end
        local toBall = ball.Position - hrp.Position
        if toBall.Magnitude < 1 or toBall.Magnitude > 40 then continue end
        if diveAssist.Value then
            local flat = Vector3.new(toBall.X, 0, toBall.Z)
            if flat.Magnitude > 0.2 then
                local v = hrp.AssemblyLinearVelocity
                local dir = flat.Unit
                hrp.AssemblyLinearVelocity = Vector3.new(dir.X * math.max(v.Magnitude, 18), v.Y, dir.Z * math.max(v.Magnitude, 18))
            end
        end
        if diveEnhancer.Value then
            local v = hrp.AssemblyLinearVelocity
            local boost = diveEnhancerPower.Value
            local flat = Vector3.new(v.X, 0, v.Z)
            if flat.Magnitude > 1 then
                local dir = flat.Unit
                hrp.AssemblyLinearVelocity = Vector3.new(dir.X * boost, v.Y, dir.Z * boost)
            end
        end
    end
end)

-- Auto jump for catch windows
task.spawn(function()
    while true do
        task.wait(0.05)
        if not autoJumpCatch.Value then continue end
        local char = player.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass('Humanoid')
        local hrp = char:FindFirstChild('HumanoidRootPart')
        if not hum or not hrp then continue end
        if hum:GetState() ~= Enum.HumanoidStateType.Running and hum:GetState() ~= Enum.HumanoidStateType.Landed then continue end
        local ball = findClosestBall and findClosestBall()
        if not ball then continue end
        local delta = ball.Position - hrp.Position
        local dist = Vector3.new(delta.X, 0, delta.Z).Magnitude
        local height = delta.Y
        if dist < 12 and height >= autoJumpMinHeight.Value and height < 14 and ball.AssemblyLinearVelocity.Y < 5 then
            hum.Jump = true
        end
    end
end)

-- Auto pop ~50%
task.spawn(function()
    local lastPop = 0
    while true do
        task.wait(0.1)
        if not autoPop.Value then continue end
        if tick() - lastPop < 1.2 then continue end
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild('HumanoidRootPart')
        if not hrp then continue end
        local ball = findClosestBall and findClosestBall()
        if not ball then continue end
        if (ball.Position - hrp.Position).Magnitude > 8 then continue end
        if math.random() > 0.5 then continue end
        lastPop = tick()
        pcall(function()
            replicatedStorage.Remotes.CharacterSoundEvent:FireServer('PlayerActions', 'swat')
        end)
    end
end)

-- Auto fumble 15% toward airborne carrier
task.spawn(function()
    local last = 0
    while true do
        task.wait(0.15)
        if not autoFumble.Value then continue end
        if tick() - last < 2 then continue end
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild('HumanoidRootPart')
        if not hrp then continue end
        for _, plr in ipairs(players:GetPlayers()) do
            if plr == player or plr.Team == player.Team then continue end
            local c = plr.Character
            if not c or not c:FindFirstChild('Football') then continue end
            local th = c:FindFirstChildOfClass('Humanoid')
            local tr = c:FindFirstChild('HumanoidRootPart')
            if not th or not tr then continue end
            local st = th:GetState()
            if st ~= Enum.HumanoidStateType.Freefall and st ~= Enum.HumanoidStateType.Jumping then continue end
            if (tr.Position - hrp.Position).Magnitude > 22 then continue end
            if math.random() > 0.15 then continue end
            last = tick()
            hrp.CFrame = CFrame.new(tr.Position + Vector3.new(0, 1, 0))
            break
        end
    end
end)

-- Anti fumble: nudge away from nearby enemy HRPs while holding ball
task.spawn(function()
    while true do
        task.wait()
        if not antiFumble.Value then continue end
        local char = player.Character
        if not char or not char:FindFirstChild('Football') then continue end
        local hrp = char:FindFirstChild('HumanoidRootPart')
        if not hrp then continue end
        local push = Vector3.zero
        for _, plr in ipairs(players:GetPlayers()) do
            if plr == player or plr.Team == player.Team then continue end
            local c = plr.Character
            local tr = c and c:FindFirstChild('HumanoidRootPart')
            if not tr then continue end
            local d = hrp.Position - tr.Position
            local m = d.Magnitude
            if m > 0.5 and m < antiFumbleRange.Value then
                push += Vector3.new(d.X, 0, d.Z).Unit / m
            end
        end
        if push.Magnitude > 0.05 then
            local v = hrp.AssemblyLinearVelocity
            local dir = push.Unit
            hrp.AssemblyLinearVelocity = Vector3.new(v.X + dir.X * 12, v.Y, v.Z + dir.Z * 12)
        end
    end
end)

-- Hitstick aimbot / assist
task.spawn(function()
    while true do
        task.wait()
        if not hitstickAimbot.Value and not hitstickAssist.Value then continue end
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild('HumanoidRootPart')
        local hum = char:FindFirstChildOfClass('Humanoid')
        if not hrp or not hum then continue end
        local best, bestDist = nil, hitstickRange.Value
        for _, plr in ipairs(players:GetPlayers()) do
            if plr == player or plr.Team == player.Team then continue end
            local c = plr.Character
            if not c or not c:FindFirstChild('Football') then continue end
            local tr = c:FindFirstChild('HumanoidRootPart')
            if not tr then continue end
            local d = (tr.Position - hrp.Position).Magnitude
            if d < bestDist then bestDist = d best = tr end
        end
        if not best then continue end
        if hitstickAimbot.Value then
            local flat = Vector3.new(best.Position.X - hrp.Position.X, 0, best.Position.Z - hrp.Position.Z)
            if flat.Magnitude > 0.2 then
                local cf = CFrame.new(hrp.Position, hrp.Position + flat.Unit)
                hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, select(2, cf:ToOrientation()), 0)
            end
        end
        if hitstickAssist.Value and bestDist < hitstickRange.Value then
            local flat = Vector3.new(best.Position.X - hrp.Position.X, 0, best.Position.Z - hrp.Position.Z)
            if flat.Magnitude > 0.2 then
                local dir = flat.Unit
                local v = hrp.AssemblyLinearVelocity
                hrp.AssemblyLinearVelocity = Vector3.new(dir.X * 28, v.Y, dir.Z * 28)
            end
        end
    end
end)

-- Block kick reach
task.spawn(function()
    while true do
        task.wait()
        if not blockKickReach.Value then continue end
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild('HumanoidRootPart')
        if not hrp then continue end
        local ball = findClosestBall and findClosestBall()
        if not ball then continue end
        if (ball.Position - hrp.Position).Magnitude > blockKickDistance.Value then continue end
        for _, name in ipairs({'CatchRight', 'CatchLeft', 'RightHand', 'LeftHand', 'Right Arm', 'Left Arm', 'Head'}) do
            local p = char:FindFirstChild(name)
            if p and firetouchinterest then
                pcall(firetouchinterest, p, ball, 0)
                pcall(firetouchinterest, p, ball, 1)
            end
        end
    end
end)

-- Auto freeze on catch
do
    local lastFreeze = 0
    local function onChar(char)
        char.ChildAdded:Connect(function(ch)
            if ch.Name ~= 'Football' then return end
            if not autoFreezeOnCatch.Value then return end
            if tick() - lastFreeze < 1 then return end
            lastFreeze = tick()
            local hrp = char:FindFirstChild('HumanoidRootPart')
            if not hrp then return end
            hrp.Anchored = true
            task.delay(freezeOnCatchTime.Value, function()
                if hrp then hrp.Anchored = false end
            end)
        end)
    end
    if player.Character then onChar(player.Character) end
    player.CharacterAdded:Connect(onChar)
end

-- Aerial magnets
task.spawn(function()
    while true do
        task.wait()
        if not aerialMagnets.Value then continue end
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild('HumanoidRootPart')
        if not hrp then continue end
        local ball = findClosestBall and findClosestBall()
        if not ball then continue end
        local delta = ball.Position - hrp.Position
        if delta.Magnitude > aerialMagRange.Value then continue end
        if delta.Y < 2 then continue end
        if ball.AssemblyLinearVelocity.Y > 2 then continue end -- dropping
        local target = Vector3.new(ball.Position.X, hrp.Position.Y, ball.Position.Z)
        local flat = target - hrp.Position
        if flat.Magnitude > 0.5 then
            hrp.CFrame = hrp.CFrame:Lerp(CFrame.new(target, target + hrp.CFrame.LookVector), 0.15)
        end
    end
end)

-- Auto shoulder boost
task.spawn(function()
    while true do
        task.wait(0.05)
        if not autoShoulder.Value then continue end
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild('HumanoidRootPart')
        if not hrp then continue end
        local ball = findClosestBall and findClosestBall()
        if not ball then continue end
        if (ball.Position - hrp.Position).Magnitude > 10 then continue end
        local dir = (ball.Position - hrp.Position)
        if dir.Magnitude < 0.2 then continue end
        dir = dir.Unit
        local v = hrp.AssemblyLinearVelocity
        hrp.AssemblyLinearVelocity = Vector3.new(
            v.X + dir.X * autoShoulderPower.Value * 0.15,
            v.Y + math.max(dir.Y, 0) * autoShoulderPower.Value * 0.1,
            v.Z + dir.Z * autoShoulderPower.Value * 0.15
        )
    end
end)

-- Kicker auto move toward goal
task.spawn(function()
    while true do
        task.wait(0.1)
        if not kickerAutoMove.Value or not kickerAimbot or not kickerAimbot.Value then continue end
        local char = player.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass('Humanoid')
        local hrp = char:FindFirstChild('HumanoidRootPart')
        if not hum or not hrp then continue end
        local goal
        for _, inst in ipairs(workspace:GetDescendants()) do
            local n = inst.Name:lower()
            if inst:IsA('BasePart') and (n:find('upright') or n:find('goalpost') or n:find('crossbar')) then
                goal = inst
                break
            end
        end
        if goal then
            hum:MoveTo(Vector3.new(goal.Position.X, hrp.Position.Y, goal.Position.Z))
        end
    end
end)



-- ===== Nova rewrite ports (Yuri) =====
autoSideTech = AutomaticsTab:CreateToggle({
    Name = 'Auto Side Tech',
    Default = false,
    Tip = 'Turns you sideways on a jump so an arm reaches the ball.',
})
autoEvade = AutomaticsTab:CreateToggle({
    Name = 'Auto Evade',
    Default = false,
    Tip = 'Slight lateral move when a defender closes while you have the ball.',
})
autoDiveCatch = AutomaticsTab:CreateToggle({
    Name = 'Auto Dive (Catch)',
    Default = false,
    Tip = 'Auto dives toward a catchable ball in range.',
})
antiAfk = AutomaticsTab:CreateToggle({
    Name = 'Anti AFK',
    Default = false,
    Tip = 'Small inputs so you do not get benched for idle.',
})
autoVoteSelf = AutomaticsTab:CreateToggle({
    Name = 'Auto Vote Self QB',
    Default = false,
    Tip = 'Attempts to vote yourself QB when the vote UI is up.',
})

task.spawn(function()
    while true do
        task.wait(0.08)
        local char = player.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass('Humanoid')
        local hrp = char:FindFirstChild('HumanoidRootPart')
        if not hum or not hrp then continue end

        if antiAfk.Value then
            pcall(function()
                hum:Move(Vector3.new(0.01, 0, 0), true)
                task.wait(0.05)
                hum:Move(Vector3.zero, true)
            end)
        end

        local ball = nil
        for _, v in ipairs(workspace:GetChildren()) do
            if v:IsA('BasePart') and v.Name == 'Football' then
                ball = v
                break
            end
        end

        if autoSideTech.Value and ball and (hum:GetState() == Enum.HumanoidStateType.Jumping or hum:GetState() == Enum.HumanoidStateType.Freefall) then
            local to = ball.Position - hrp.Position
            if to.Magnitude < 22 and to.Magnitude > 0.5 then
                local side = hrp.CFrame.RightVector
                if side:Dot(to.Unit) < 0 then side = -side end
                hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + side)
            end
        end

        if autoDiveCatch.Value and ball then
            local d = (ball.Position - hrp.Position).Magnitude
            if d < 14 and ball.AssemblyLinearVelocity.Magnitude > 8 then
                pcall(function()
                    local rs = game:GetService('ReplicatedStorage')
                    rs.Remotes.CharacterSoundEvent:FireServer('PlayerActions', 'dive')
                end)
            end
        end

        if autoEvade.Value then
            local hasBall = false
            pcall(function()
                for _, v in ipairs(char:GetDescendants()) do
                    if v:IsA('BasePart') and v.Name == 'Football' then hasBall = true break end
                end
            end)
            if hasBall then
                for _, pl in ipairs(game:GetService('Players'):GetPlayers()) do
                    if pl == player then continue end
                    local ohrp = pl.Character and pl.Character:FindFirstChild('HumanoidRootPart')
                    if ohrp and (ohrp.Position - hrp.Position).Magnitude < 8 then
                        local away = (hrp.Position - ohrp.Position)
                        if away.Magnitude > 0.1 then
                            hrp.CFrame = hrp.CFrame + away.Unit * 0.35
                        end
                        break
                    end
                end
            end
        end
    end
end)

-- Defense: Tackle Expander / Swat Expander / Bait Rush aliases
tackleExpander = DefenseTab:CreateToggle({
    Name = 'Tackle Expander',
    Default = false,
    Tip = 'Extends tackle reach (replaces plain Tackle Reach naming).',
})
tackleExpanderRange = DefenseTab:CreateSlider({
    Name = 'Tackle Expand Range',
    Min = 1,
    Max = 20,
    Default = 8,
    Increment = 0.5,
    Tip = 'How far tackle assist reaches.',
})
swatExpander = DefenseTab:CreateToggle({
    Name = 'Swat Expander',
    Default = false,
    Tip = 'Extends swat / bat-down reach on nearby balls.',
})
swatExpanderRange = DefenseTab:CreateSlider({
    Name = 'Swat Expand Range',
    Min = 1,
    Max = 20,
    Default = 10,
    Increment = 0.5,
    Tip = 'Swat assist distance.',
})
baitRush = DefenseTab:CreateToggle({
    Name = 'Bait Rush',
    Default = false,
    Tip = 'Holds a soft angle to bait rushers then recovers.',
})

task.spawn(function()
    while true do
        task.wait(0.05)
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild('HumanoidRootPart')
        if not hrp then continue end
        local ball = nil
        for _, v in ipairs(workspace:GetChildren()) do
            if v:IsA('BasePart') and v.Name == 'Football' then ball = v break end
        end
        if tackleExpander.Value and ball then
            local d = (ball.Position - hrp.Position).Magnitude
            if d <= tackleExpanderRange.Value then
                pcall(function()
                    game:GetService('ReplicatedStorage').Remotes.CharacterSoundEvent:FireServer('PlayerActions', 'tackle')
                end)
            end
        end
        if swatExpander.Value and ball then
            local d = (ball.Position - hrp.Position).Magnitude
            if d <= swatExpanderRange.Value then
                pcall(function()
                    game:GetService('ReplicatedStorage').Remotes.CharacterSoundEvent:FireServer('PlayerActions', 'swat')
                end)
            end
        end
    end
end)

-- Physics: Anti Stumble, Dive Anytime
antiStumble = PhysicsTab:CreateToggle({
    Name = 'Anti Stumble',
    Default = false,
    Tip = 'Reduces stumble / trip interruptions when moving.',
})
diveAnytime = PhysicsTab:CreateToggle({
    Name = 'Dive Anytime',
    Default = false,
    Tip = 'Allows dive input even when the game normally blocks it.',
})
diveAnytimeKey = PhysicsTab:CreateKeybind({
    Name = 'Dive Anytime Key',
    Default = Enum.KeyCode.Q,
    Tip = 'Key to force a dive.',
})

task.spawn(function()
    while true do
        task.wait(0.1)
        if not antiStumble.Value then continue end
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass('Humanoid')
        if not hum then continue end
        pcall(function()
            if hum:GetState() == Enum.HumanoidStateType.FallingDown or hum:GetState() == Enum.HumanoidStateType.Ragdoll then
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end)
    end
end)

userInputService.InputBegan:Connect(function(input, gpe)
    if gpe or not diveAnytime or not diveAnytime.Value then return end
    if diveAnytimeKey and diveAnytimeKey.Value and input.KeyCode == diveAnytimeKey.Value then
        pcall(function()
            game:GetService('ReplicatedStorage').Remotes.CharacterSoundEvent:FireServer('PlayerActions', 'dive')
        end)
    end
end)

-- Player: Dodge Landing, Panic Key
dodgeLanding = PlayerTab:CreateToggle({
    Name = 'Dodge Landing',
    Default = false,
    Tip = 'Nudges sideways just before landing to reduce clean hits.',
})
panicKey = PlayerTab:CreateKeybind({
    Name = 'Panic Key',
    Default = Enum.KeyCode.P,
    Tip = 'Quickly disables high-risk toggles (speed, mags, aimbot).',
})
panicOnAdmin = PlayerTab:CreateToggle({
    Name = 'Panic On Admin Join',
    Default = false,
    Tip = 'Runs panic if an admin-tagged player appears.',
})

task.spawn(function()
    while true do
        task.wait(0.05)
        if not dodgeLanding.Value then continue end
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass('Humanoid')
        local hrp = char and char:FindFirstChild('HumanoidRootPart')
        if not hum or not hrp then continue end
        if hum:GetState() == Enum.HumanoidStateType.Freefall and hrp.AssemblyLinearVelocity.Y < -20 then
            local ray = workspace:Raycast(hrp.Position, Vector3.new(0, -8, 0))
            if ray then
                hrp.CFrame = hrp.CFrame + hrp.CFrame.RightVector * 0.4
            end
        end
    end
end)

local function yuriPanic()
    for _, flag in ipairs({footballMagnets, enableQbAimbot, customWalkspeed, customJumpPower, desyncMagnet, physicsMag}) do
        pcall(function()
            if flag and flag.Set then flag:Set(false) elseif flag then flag.Value = false end
        end)
    end
end

userInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if panicKey and panicKey.Value and input.KeyCode == panicKey.Value then
        yuriPanic()
    end
end)

task.spawn(function()
    while true do
        task.wait(1.5)
        if not panicOnAdmin.Value then continue end
        for _, admin in ipairs(game:GetService('Players'):GetPlayers()) do
            if admin == player then continue end
            local swag = admin:FindFirstChild('SwagData')
            local tag = swag and swag:FindFirstChild('Admin')
            if tag and tostring(tag.Value) ~= '' then
                yuriPanic()
                break
            end
        end
    end
end)

-- Visuals: Jump Cue, Player ESP (simple), Ball Chams
jumpCue = VisualTab:CreateToggle({
    Name = 'Jump Cue',
    Default = false,
    Tip = 'Ring at predicted catch landing that tightens when it is time to jump.',
})
playerEsp = VisualTab:CreateToggle({
    Name = 'Player ESP',
    Default = false,
    Tip = 'Highlights other players through walls.',
})
ballChams = VisualTab:CreateToggle({
    Name = 'Ball Chams',
    Default = false,
    Tip = 'Always-visible highlight on the football.',
})

local jumpCuePart = Instance.new('Part')
jumpCuePart.Anchored = true
jumpCuePart.CanCollide = false
jumpCuePart.Shape = Enum.PartType.Cylinder
jumpCuePart.Material = Enum.Material.ForceField
jumpCuePart.Color = Color3.fromRGB(80, 180, 255)
jumpCuePart.Size = Vector3.new(0.2, 6, 6)
jumpCuePart.Transparency = 0.35
jumpCuePart.Name = 'YuriJumpCue'

local espFolder = Instance.new('Folder')
espFolder.Name = 'YuriPlayerESP'

task.spawn(function()
    while true do
        task.wait(0.1)
        -- Jump cue
        if jumpCue.Value then
            local ball = nil
            for _, v in ipairs(workspace:GetChildren()) do
                if v:IsA('BasePart') and v.Name == 'Football' then ball = v break end
            end
            if ball and ball.AssemblyLinearVelocity.Magnitude > 5 then
                local pos = ball.Position
                local vel = ball.AssemblyLinearVelocity
                local t = 0
                local p = pos
                local g = workspace.Gravity
                for _ = 1, 120 do
                    t = t + 0.05
                    p = pos + vel * t + Vector3.new(0, -0.5 * g * t * t, 0)
                    if p.Y <= 2.5 then break end
                end
                jumpCuePart.CFrame = CFrame.new(p.X, 2.6, p.Z) * CFrame.Angles(0, 0, math.rad(90))
                local scale = math.clamp((p - ball.Position).Magnitude / 40, 0.35, 1)
                jumpCuePart.Size = Vector3.new(0.2, 8 * scale, 8 * scale)
                jumpCuePart.Parent = workspace.Terrain
            else
                jumpCuePart.Parent = nil
            end
        else
            jumpCuePart.Parent = nil
        end

        -- Player ESP
        if playerEsp.Value then
            if not espFolder.Parent then
                espFolder.Parent = game:GetService('CoreGui')
            end
            for _, pl in ipairs(game:GetService('Players'):GetPlayers()) do
                if pl == player then continue end
                local ch = pl.Character
                local head = ch and ch:FindFirstChild('Head')
                if not head then continue end
                local hl = espFolder:FindFirstChild(pl.Name)
                if not hl then
                    hl = Instance.new('Highlight')
                    hl.Name = pl.Name
                    hl.FillTransparency = 0.7
                    hl.OutlineTransparency = 0.2
                    hl.FillColor = Color3.fromRGB(100, 160, 255)
                    hl.Parent = espFolder
                end
                hl.Adornee = ch
            end
        else
            espFolder:ClearAllChildren()
            espFolder.Parent = nil
        end

        -- Ball chams
        if ballChams.Value then
            for _, v in ipairs(workspace:GetChildren()) do
                if v:IsA('BasePart') and v.Name == 'Football' then
                    local hl = v:FindFirstChild('YuriBallChams')
                    if not hl then
                        hl = Instance.new('Highlight')
                        hl.Name = 'YuriBallChams'
                        hl.FillColor = Color3.fromRGB(255, 200, 60)
                        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                        hl.FillTransparency = 0.4
                        hl.Parent = v
                    end
                    hl.Adornee = v
                end
            end
        else
            for _, v in ipairs(workspace:GetChildren()) do
                if v:IsA('BasePart') and v.Name == 'Football' then
                    local hl = v:FindFirstChild('YuriBallChams')
                    if hl then hl:Destroy() end
                end
            end
        end
    end
end)

-- Mag Enhancer Facing (Catching)
magFacing = CatchingTab:CreateDropdown({
    Name = 'Mag Enhancer Facing',
    Options = {'Body', 'Ball'},
    Default = 'Body',
    Tip = 'Facing for mag enhancer: follow body or turn toward ball.',
})
magHitboxPos = CatchingTab:CreateDropdown({
    Name = 'Mag Hitbox Position',
    Options = {'Client', 'Server'},
    Default = 'Client',
    Tip = 'Where mag hitbox is drawn: where you see yourself, or server position.',
})

-- Pull Vector Intercept option if pull vector exists
pcall(function()
    if CatchingTab and not (pullMethod and tostring(pullMethod):find('Intercept')) then
        -- extend pull type dropdown options by creating companion toggle
    end
end)
pullIntercept = CatchingTab:CreateToggle({
    Name = 'Pull Vector Intercept',
    Default = false,
    Tip = 'Pull toward predicted intercept point instead of raw ball position.',
})

ballHawk = CatchingTab:CreateToggle({
    Name = 'Ball Hawk',
    Default = false,
    Tip = 'Aggressively tracks high balls for interception / tip drills.',
})

task.spawn(function()
    while true do
        task.wait(0.05)
        if not (ballHawk and ballHawk.Value) then continue end
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass('Humanoid')
        local hrp = char and char:FindFirstChild('HumanoidRootPart')
        if not hum or not hrp then continue end
        local ball = nil
        for _, v in ipairs(workspace:GetChildren()) do
            if v:IsA('BasePart') and v.Name == 'Football' then ball = v break end
        end
        if not ball then continue end
        if ball.Position.Y > hrp.Position.Y + 4 and ball.AssemblyLinearVelocity.Magnitude > 10 then
            hum:MoveTo(Vector3.new(ball.Position.X, hrp.Position.Y, ball.Position.Z))
        end
    end
end)

-- SmartFit mutual exclusion with QBA (Nova: can't be on together)
task.spawn(function()
    local lastQ, lastS = false, false
    while true do
        task.wait(0.15)
        local q = enableQbAimbot and enableQbAimbot.Value
        local sm = smartFit and smartFit.Value
        if q and sm then
            if q and not lastQ then
                pcall(function() if smartFit.Set then smartFit:Set(false) else smartFit.Value = false end end)
            elseif sm and not lastS then
                pcall(function() if enableQbAimbot.Set then enableQbAimbot:Set(false) else enableQbAimbot.Value = false end end)
            end
        end
        lastQ, lastS = q, sm
    end
end)



diveBoost = PlayerTab:CreateToggle({
    Name = 'Dive Boost',
    Default = false,
    Tip = 'Extra push when you dive (Wii-style boost on dive).',
})
diveBoostPower = PlayerTab:CreateSlider({
    Name = 'Dive Boost Power',
    Min = 0,
    Max = 20,
    Default = 8,
    Increment = 0.5,
    Tip = 'How hard the dive boost pushes you.',
})
task.spawn(function()
    local lastState
    while true do
        task.wait(0.05)
        if not diveBoost or not diveBoost.Value then continue end
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass('Humanoid')
        local hrp = char and char:FindFirstChild('HumanoidRootPart')
        if not hum or not hrp then continue end
        local st = hum:GetState()
        if st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Freefall then
            -- detect dive start via velocity / state change
            if lastState == Enum.HumanoidStateType.Running or lastState == Enum.HumanoidStateType.Jumping then
                local look = hrp.CFrame.LookVector
                local pow = tonumber(diveBoostPower.Value) or 8
                hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity + look * pow + Vector3.new(0, pow * 0.15, 0)
            end
        end
        lastState = st
    end
end)


showInterceptPoint = AutomaticsTab:CreateToggle({
    Name = 'Show Interception Point',
    Default = false,
    Tip = 'Marks predicted intercept point while Auto Rush is on.',
})
rushPredMult = AutomaticsTab:CreateSlider({
    Name = 'Rush Prediction Multiplier',
    Min = 1,
    Max = 15,
    Default = 5,
    Increment = 0.5,
    Tip = 'How far ahead Auto Rush leads the ball carrier.',
})
task.spawn(function()
    local mark
    while true do
        task.wait(0.08)
        if not (showInterceptPoint and showInterceptPoint.Value and autoRush and autoRush.Value) then
            if mark then pcall(function() mark:Destroy() end) mark=nil end
            continue
        end
        local carrier=nil
        for _,pl in ipairs(game:GetService('Players'):GetPlayers()) do
            if pl==player then continue end
            local ch=pl.Character
            if not ch then continue end
            for _,d in ipairs(ch:GetDescendants()) do
                if d:IsA('BasePart') and d.Name=='Football' then carrier=ch break end
            end
            if carrier then break end
        end
        if not carrier then
            if mark then pcall(function() mark:Destroy() end) mark=nil end
            continue
        end
        local hrp=carrier:FindFirstChild('HumanoidRootPart')
        if not hrp then continue end
        local mult=tonumber(rushPredMult and rushPredMult.Value) or 5
        local pred=hrp.Position + hrp.AssemblyLinearVelocity * (0.05 * mult)
        if not mark then
            mark=Instance.new('Part')
            mark.Shape=Enum.PartType.Ball
            mark.Size=Vector3.new(2,2,2)
            mark.Anchored=true
            mark.CanCollide=false
            mark.Material=Enum.Material.Neon
            mark.Color=Color3.fromRGB(255,80,80)
            mark.Transparency=0.3
            mark.Parent=workspace.Terrain
        end
        mark.Position=pred
    end
end)

local MiscTab = Window:CreateTab({ Name = 'Misc', Icon = 'rbxassetid://129082556946713' })


MiscTab:CreateButton({
    Name = 'Server Hop',
    Tip = 'Rejoins a different server of this place.',
    Callback = function()
        pcall(function()
            local TeleportService = game:GetService('TeleportService')
            local HttpService = game:GetService('HttpService')
            local placeId = game.PlaceId
            local servers = game:GetService('HttpService'):JSONDecode(
                game:HttpGet('https://games.roblox.com/v1/games/' .. placeId .. '/servers/Public?sortOrder=Asc&limit=25')
            )
            for _, server in ipairs(servers.data or {}) do
                if server.id ~= game.JobId and server.playing < server.maxPlayers then
                    TeleportService:TeleportToPlaceInstance(placeId, server.id, player)
                    return
                end
            end
            TeleportService:Teleport(placeId, player)
        end)
    end
})

timeOfDay = MiscTab:CreateDropdown({
    Name = 'Time Of Day',
    Options = {'Default', 'Day', 'Night', 'Noon', 'Morning'},
    Default = 'Default',
    Tip = 'Client lighting clock time.',
    Callback = function(v)
        pcall(function()
            local lighting = game:GetService('Lighting')
            if v == 'Day' then lighting.ClockTime = 14
            elseif v == 'Night' then lighting.ClockTime = 0
            elseif v == 'Noon' then lighting.ClockTime = 12
            elseif v == 'Morning' then lighting.ClockTime = 8
            end
        end)
    end
})



globalTag = MiscTab:CreateToggle({
    Name = 'Global Tag (Client)',
    Default = false,
    Tip = 'Client-only nametag style (not server global).',
})
voteSkip = MiscTab:CreateButton({
    Name = 'Vote Skip',
    Tip = 'Attempts a skip vote remote if present.',
    Callback = function()
        pcall(function()
            local rem = game:GetService('ReplicatedStorage'):FindFirstChild('Remotes')
            if rem and rem:FindFirstChild('CharacterSoundEvent') then
                rem.CharacterSoundEvent:FireServer('Game', 'VoteSkip')
            end
        end)
    end
})

animationSpeed = MiscTab:CreateSlider({
    Name = 'Animation Speed',
    Min = 0.5,
    Max = 3,
    Default = 1,
    Increment = 0.1,
})
reduceMotion = MiscTab:CreateToggle({
    Name = 'Reduce Motion',
    Default = false,
    Tip = 'Lowers camera bob / heavy effects where possible.',
})

underground = MiscTab:CreateToggle({
    Name = 'Underground',
    Default = false,
    Tip = 'Nudge character slightly under the field (troll).',
})

task.spawn(function()
    while true do
        task.wait(0.1)
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass('Humanoid')
        local hrp = char and char:FindFirstChild('HumanoidRootPart')
        if animationSpeed and hum then
            local sc = tonumber(animationSpeed.Value) or 1
            local animator = hum:FindFirstChildOfClass('Animator')
            if animator then
                for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
                    pcall(function() t:AdjustSpeed(sc) end)
                end
            end
        end
        if underground and underground.Value and hrp then
            hrp.CFrame = hrp.CFrame + Vector3.new(0, -0.15, 0)
        end
        if reduceMotion and reduceMotion.Value then
            pcall(function()
                local cam = workspace.CurrentCamera
                if cam then cam.FieldOfView = math.min(cam.FieldOfView, 70) end
            end)
        end
    end
end)


fpsCap = MiscTab:CreateSlider({
    Name = 'Uncap FPS Amount',
    Min = 30,
    Max = 240,
    Default = 240,
    Increment = 1,
    Suffix = '',
    Tip = 'Sets the maximum FPS limit.',
})

task.spawn(function()
    while true do
        task.wait()

        pcall(function() if setfpscap then setfpscap(fpsCap.Value) end end)
    end
end)



uiTheme = MiscTab:CreateDropdown({
    Name = 'UI Theme',
    Options = {'Cyan', 'Amber', 'Purple', 'Red', 'Green', 'White'},
    Default = 'Cyan',
    Tip = 'Accent color for the hub.',
})

rainbowAccent = MiscTab:CreateToggle({
    Name = 'Rainbow Accent',
    Default = false,
    Tip = 'Cycles the UI accent color.',
})

rainbowPlayers = MiscTab:CreateToggle({
    Name = 'Rainbow Players',
    Default = false,
    Tip = 'Cycles other players colors on your client.',
})

task.spawn(function()
    local THEME = {
        Cyan = Color3.fromRGB(64, 220, 200),
        Amber = Color3.fromRGB(255, 150, 55),
        Purple = Color3.fromRGB(170, 100, 255),
        Red = Color3.fromRGB(255, 80, 90),
        Green = Color3.fromRGB(80, 220, 120),
        White = Color3.fromRGB(240, 240, 245),
    }
    while true do
        task.wait(0.08)
        local col = THEME[tostring(uiTheme and uiTheme.Value)] or THEME.Cyan
        if rainbowAccent and rainbowAccent.Value then
            local t = tick() * 0.7
            col = Color3.fromHSV((t % 1), 0.75, 1)
        end
        pcall(function()
            local gui = (gethui and gethui()) or game:GetService('CoreGui')
            local hub = gui:FindFirstChild('YuriHub')
            if not hub then
                hub = player:FindFirstChild('PlayerGui') and player.PlayerGui:FindFirstChild('YuriHub')
            end
            if hub then
                for _, d in ipairs(hub:GetDescendants()) do
                    if d:IsA('UIStroke') and d.Thickness >= 1.2 then
                        d.Color = col
                    end
                end
            end
        end)
        if rainbowPlayers and rainbowPlayers.Value then
            local t = tick() * 0.5
            local c = Color3.fromHSV((t % 1), 0.8, 1)
            for _, plr in ipairs(players:GetPlayers()) do
                if plr == player then continue end
                local char = plr.Character
                if char then
                    for _, p in ipairs(char:GetDescendants()) do
                        if p:IsA('BasePart') and p.Name ~= 'HumanoidRootPart' then
                            pcall(function() p.Color = c end)
                        end
                    end
                end
            end
        end
    end
end)

-- Local configs (executor writefile)
local function yuriConfigPath(name)
    name = tostring(name or 'default'):gsub('[^%w_%-]', '')
    return 'yuri_ff3_' .. name .. '.json'
end

configName = MiscTab:CreateDropdown({
    Name = 'Config Slot',
    Options = {'default', 'legit', 'blatant', 'comp'},
    Default = 'default',
})

MiscTab:CreateButton({
    Name = 'Save Config',
    Tip = 'Saves key toggle/slider values locally (executor file).',
    Callback = function()
        pcall(function()
            if not writefile or not HttpService then return end
            local data = {}
            -- sample important flags
            local flags = {
                enableQbAimbot, throwAimbot, footballMagnets, pullVector, autoCatch, autoRush,
                customWalkSpeed, walkSpeedValue, angleEnhancer, kickerAimbot,
            }
            -- store by scanning YuriUI flags if present
            if YuriUI and YuriUI.Flags then
                for k, v in pairs(YuriUI.Flags) do
                    if type(v) == 'table' and v.Value ~= nil then
                        data[k] = v.Value
                    end
                end
            end
            writefile(yuriConfigPath(configName and configName.Value), HttpService:JSONEncode(data))
            if YuriLib and YuriLib.Notify then
                YuriLib.Notify('Config saved')
            end
        end)
    end,
})

MiscTab:CreateButton({
    Name = 'Load Config',
    Tip = 'Loads a saved config slot.',
    Callback = function()
        pcall(function()
            if not readfile or not isfile or not HttpService then return end
            local path = yuriConfigPath(configName and configName.Value)
            if not isfile(path) then return end
            local data = HttpService:JSONDecode(readfile(path))
            if YuriUI and YuriUI.Flags and type(data) == 'table' then
                for k, v in pairs(data) do
                    local flag = YuriUI.Flags[k]
                    if flag and flag.Value ~= nil then
                        flag.Value = v
                    end
                end
            end
        end)
    end,
})

liveChat = MiscTab:CreateToggle({
    Name = 'Live Chat Log',
    Default = false,
    Tip = 'Shows a small on-screen log of nearby chat messages.',
})

task.spawn(function()
    local gui, list
    local function ensure()
        if gui and gui.Parent then return end
        local pg = player:FindFirstChild('PlayerGui') or player:WaitForChild('PlayerGui', 5)
        if not pg then return end
        gui = Instance.new('ScreenGui')
        gui.Name = 'YuriLiveChat'
        gui.ResetOnSpawn = false
        gui.Parent = pg
        local frame = Instance.new('Frame')
        frame.Size = UDim2.fromOffset(280, 160)
        frame.Position = UDim2.new(0, 12, 1, -180)
        frame.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
        frame.BackgroundTransparency = 0.15
        frame.BorderSizePixel = 0
        frame.Parent = gui
        Instance.new('UICorner', frame).CornerRadius = UDim.new(0, 10)
        list = Instance.new('ScrollingFrame')
        list.Size = UDim2.new(1, -12, 1, -12)
        list.Position = UDim2.fromOffset(6, 6)
        list.BackgroundTransparency = 1
        list.ScrollBarThickness = 3
        list.CanvasSize = UDim2.new(0, 0, 0, 0)
        list.Parent = frame
        local lay = Instance.new('UIListLayout')
        lay.Padding = UDim.new(0, 2)
        lay.Parent = list
        lay:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
            list.CanvasSize = UDim2.new(0, 0, 0, lay.AbsoluteContentSize.Y + 8)
        end)
    end
    local function addLine(text)
        if not list then return end
        local t = Instance.new('TextLabel')
        t.Size = UDim2.new(1, -4, 0, 18)
        t.BackgroundTransparency = 1
        t.Font = Enum.Font.Gotham
        t.TextSize = 12
        t.TextColor3 = Color3.fromRGB(230, 230, 235)
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.Text = text
        t.Parent = list
        if #list:GetChildren() > 40 then
            for _, c in ipairs(list:GetChildren()) do
                if c:IsA('TextLabel') then c:Destroy() break end
            end
        end
    end
    pcall(function()
        local chat = game:GetService('TextChatService')
        if chat and chat.MessageReceived then
            chat.MessageReceived:Connect(function(msg)
                if not liveChat or not liveChat.Value then return end
                ensure()
                local name = 'Player'
                pcall(function()
                    name = msg.TextSource and msg.TextSource.Name or name
                end)
                addLine(name .. ': ' .. tostring(msg.Text or ''):sub(1, 80))
            end)
        end
    end)
    pcall(function()
        local scs = game:GetService('StarterGui')
        -- legacy
        local chat = player:FindFirstChild('PlayerGui')
    end)
    while true do
        task.wait(0.5)
        if liveChat and liveChat.Value then
            ensure()
            if gui then gui.Enabled = true end
        else
            if gui then gui.Enabled = false end
        end
    end
end)


fpsBoost = MiscTab:CreateToggle({
    Name = 'FPS Boost',
    Default = false,
    Tip = 'Lowers lighting/effects for more FPS.',
})

task.spawn(function()
    local applied = false
    while true do
        task.wait(0.5)
        if fpsBoost and fpsBoost.Value then
            if not applied then
                applied = true
                pcall(function()
                    settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
                    local lighting = game:GetService('Lighting')
                    lighting.GlobalShadows = false
                    lighting.FogEnd = 1e6
                    for _, v in ipairs(lighting:GetChildren()) do
                        if v:IsA('BlurEffect') or v:IsA('SunRaysEffect') or v:IsA('BloomEffect') then
                            v.Enabled = false
                        end
                    end
                end)
            end
        else
            applied = false
        end
    end
end)


antiAdmin = MiscTab:CreateToggle({
    Name = 'Anti Admin',
    Default = false,
    Tip = 'If an admin tag is detected on another player, leave the game (self-kick).',
})

task.spawn(function()
    local kicked = false
    while true do
        task.wait(0.35)
        if not antiAdmin or not antiAdmin.Value or kicked then continue end
        pcall(function()
            for _, pl in ipairs(players:GetPlayers()) do
                if pl == player then continue end
                local swag = pl:FindFirstChild('SwagData')
                local tag = swag and swag:FindFirstChild('Admin')
                if tag and tostring(tag.Value) ~= '' and tostring(tag.Value) ~= 'nil' then
                    kicked = true
                    warn('[Yuri] Admin detected:', pl.Name, tag.Value)
                    player:Kick('[Yuri Hub] Admin detected\n' .. pl.Name .. ' (' .. tostring(pl.UserId) .. ')')
                    return
                end
            end
        end)
    end
end)
smoothReplay = MiscTab:CreateToggle({
		Name = 'Smooth Replay',
		Default = false,
		Tip = 'Replay enhancer - smoother client replay (Cons-style).',
		Keybind = nil,
	})

	replayFPS = MiscTab:CreateSlider({
		Name = 'Replay Frame Per Second',
		Min = 9,
		Max = 120,
		Default = 9,
		Increment = 1,
		Tip = 'Sets the replay playback frame rate.',
	})
    
if not isPractice then

	local player = game:GetService('Players').LocalPlayer
	local replicatedStorage = game:GetService('ReplicatedStorage')
	local runService = game:GetService('RunService')

	local remoteFolder = replicatedStorage:FindFirstChild('Remotes') or replicatedStorage:WaitForChild('Remotes', 8)
	local remote = remoteFolder and (remoteFolder:FindFirstChild('CharacterSoundEvent') or remoteFolder:WaitForChild('CharacterSoundEvent', 5))
	local heartbeat = runService.Heartbeat

	local pg = player:FindFirstChild('PlayerGui') or player:WaitForChild('PlayerGui', 5)
	local mainGui = pg and (pg:FindFirstChild('MainGui') or pg:WaitForChild('MainGui', 5))
	local transition = mainGui and (mainGui:FindFirstChild('Transition') or mainGui:WaitForChild('Transition', 5))
	if not remote then
		warn('[Yuri] CharacterSoundEvent missing - some automatics may no-op')
	end

	local homeCamera = CFrame.Angles(-0.2617993877991494, 0, 0)
	local awayCamera = CFrame.Angles(0.2617993877991494, math.pi, 0)

	local cameraOffset = CFrame.new(0, 0, 19)

	local limbs = {
		'Torso',
		'Left Arm',
		'Right Arm',
		'Left Leg',
		'Right Leg',
		'Head'
	}

	task.spawn(function()
		while true do
			task.wait()

			local replayScript = player.PlayerScripts:FindFirstChild('ClientReplay')
			if replayScript then
				replayScript.Enabled = not smoothReplay.Value
			end
		end
	end)

	local replay = function(data, characters)
		local replayBall = workspace:FindFirstChild('ReplayBall') or workspace:WaitForChild('ReplayBall', 5)
		local camera = workspace.CurrentCamera

		camera.CameraType = Enum.CameraType.Scriptable
		camera.CameraSubject = replayBall

		local cameraRotation = data.changes[1].poss == 'h' and homeCamera or awayCamera

		local currentChange = 1
		local highestY = 18
		local cameraTilt = true

		local playback = 1
		local recordedFPS = data.fps

		local accumulator = 0
		local last = tick()

		local getFrame = function(index)
			local maxFrames = #data.ball
			if index < 1 then return 1 end
			if index > maxFrames then return maxFrames end
			return index
		end

		local interpolate = function(a, b, alpha)
			return a:Lerp(b, alpha)
		end

		while playback < #data.ball do
			if replicatedStorage.Flags.StatusTag.Value ~= 'REPLAY' then
				break
			end

			if camera.CameraType ~= Enum.CameraType.Scriptable then
				break
			end

			local replayFPSValue = replayFPS.Value
			local replayDelta = 1 / replayFPSValue

			local now = tick()
			accumulator += now - last
			last = now

			while accumulator >= replayDelta do
				playback += recordedFPS / replayFPSValue
				accumulator -= replayDelta
			end

			local frame1 = getFrame(math.floor(playback))
			local frame2 = getFrame(math.ceil(playback))
			local alpha = playback - frame1

			for _, character in next, characters do
				local characterData = data.limbs[character.Name]
				if not characterData then character.Parent = nil continue end

				local limbData = characterData[1]
				local accessoryData = characterData[2]

				if not limbData[1] then
					character.Parent = nil
					continue
				end

				local torso1 = limbData[1][2][frame1]
				local torso2 = limbData[1][2][frame2]

				if not torso1 or not torso2 then
					character.Parent = nil
					continue
				end

				local torso = interpolate(torso1, torso2, alpha)

				for i = 1, #limbs do
					local limbName = limbs[i]
					local limb = character:FindFirstChild(limbName)
					if not limb then continue end

					local replayLimb = limbData[i]
					if not replayLimb then continue end

					local cf1 = replayLimb[2][frame1]
					local cf2 = replayLimb[2][frame2]

					if i == 4 then
						if cf1 and cf2 then
							local angle = cf1 + ((cf2 - cf1) * alpha)

							limb.CFrame =
								torso *
								CFrame.new(-0.5, -1, 0) *
								CFrame.fromOrientation(angle, 0, 0) *
								CFrame.new(0, -1, 0)
						end
					elseif i == 5 then
						if cf1 and cf2 then
							local angle = cf1 + ((cf2 - cf1) * alpha)

							limb.CFrame =
								torso *
								CFrame.new(0.5, -1, 0) *
								CFrame.fromOrientation(angle, 0, 0) *
								CFrame.new(0, -1, 0)
						end
					else
						if cf1 and cf2 then
							limb.CFrame = interpolate(cf1, cf2, alpha)
						elseif i == 6 then
							limb.CFrame = torso * CFrame.new(0, 1.5, 0)
						end
					end
				end

				local uniform = character:FindFirstChild('Uniform')
				if accessoryData and uniform then
					for name, info in next, accessoryData do
						if uniform:FindFirstChild(name) and character:FindFirstChild(info[1]) then
							uniform[name].CFrame =
								character[info[1]].CFrame * info[2]
						end
					end
				end
			end

			local ball1 = data.ball[frame1]
			local ball2 = data.ball[frame2]

			if ball1 and ball2 then
				replayBall.CFrame = interpolate(ball1, ball2, alpha)
			end

			if highestY < replayBall.Position.Y then
				highestY = replayBall.Position.Y
			elseif highestY > 49 and cameraTilt then
				local x = select(1, cameraRotation:ToOrientation())

				cameraRotation *= CFrame.Angles(
					x * 3 * math.clamp((highestY - 50) / 99, 0, 1),
					0,
					0
				)

				cameraTilt = false
			end

			local targetCamera

			if highestY > 49 and cameraTilt then
				local x = select(1, cameraRotation:ToOrientation())

				targetCamera =
					CFrame.new(replayBall.Position) *
					cameraRotation *
					CFrame.Angles(
						x * 3 * math.clamp((highestY - 50) / 99, 0, 1),
						0,
						0
					) *
					cameraOffset
			else
				targetCamera =
					CFrame.new(replayBall.Position) *
					cameraRotation *
					cameraOffset
			end

			camera.CFrame = targetCamera

			local change = data.changes[currentChange]

			if change and change.frame <= frame1 then
				currentChange += 1

				if change.frame == frame1 then
					if change.poss and (frame1 > 9 and (change.turnover or highestY > 49)) then
						local nextRotation =
							change.poss == 'h' and homeCamera or awayCamera

						local duration =
							(change.turnover == true or replayBall.Position.Y >= 13)
							and 0.5
							or (highestY / 500)

						local elapsed = 0
						local startRotation = cameraRotation

						while elapsed < duration do
							elapsed += heartbeat:Wait()

							cameraRotation = startRotation:Lerp(
								nextRotation,
								math.clamp(elapsed / duration, 0, 1)
							)

							camera.CFrame =
								CFrame.new(replayBall.Position) *
								cameraRotation *
								cameraOffset
						end

						cameraRotation = nextRotation

					elseif change.freeze then
						task.wait(change.freeze)
					end
				end
			end

			heartbeat:Wait()
		end

		remote:FireServer('ReplayFinished')

		if replicatedStorage.Flags.StatusTag.Value == 'REPLAY' then
			replicatedStorage.Flags.StatusTag.Value = ''
		end

		task.wait(0.2)

		replayBall:Destroy()

		for _, character in next, characters do
			character:Destroy()
		end

		data.t = nil
		data.limbs = nil
		data.ball = nil

		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = player.Character.Humanoid
	end

	remote.OnClientEvent:Connect(function(action, ...)
		if action == 'ClientReplay' then
			while transition.Position.X.Scale > -2 and transition.Position.X.Scale < -0.5 do
				task.wait()
			end

			replay(...)
		end
	end)

end



-- Load banner
pcall(function()
    game:GetService('StarterGui'):SetCore('SendNotification', {
        Title = 'Yuri FF3',
        Text = 'Ready - tap the floating button to open',
        Duration = 6,
    })
end)

-- Welcome toast (Zen-style, bottom-right, auto 10s)
task.spawn(function()
    local gui = (YuriUI and rawget(YuriUI, '_lastGui')) or (player.PlayerGui:FindFirstChild('YuriHub') or (game:GetService('CoreGui'):FindFirstChild('YuriHub')))
    if not gui then
        pcall(function()
            gui = player.PlayerGui:WaitForChild('YuriHub', 3)
        end)
    end
    if not gui then return end

    local toast = Instance.new('Frame')
    toast.Name = 'YuriWelcome'
    toast.AnchorPoint = Vector2.new(1, 1)
    toast.Position = UDim2.new(1, -18, 1, -90)
    toast.Size = UDim2.fromOffset(280, 58)
    toast.BackgroundColor3 = Color3.fromRGB(245, 242, 236)
    toast.BorderSizePixel = 0
    toast.ZIndex = 200
    toast.Parent = gui
    local tc = Instance.new('UICorner')
    tc.CornerRadius = UDim.new(0, 14)
    tc.Parent = toast
    local ts = Instance.new('UIStroke')
    ts.Color = Color3.fromRGB(220, 215, 205)
    ts.Thickness = 1
    ts.Transparency = 0.3
    ts.Parent = toast

    local icon = Instance.new('TextLabel')
    icon.BackgroundColor3 = Color3.fromRGB(255, 236, 220)
    icon.Size = UDim2.fromOffset(22, 22)
    icon.Position = UDim2.new(0, 12, 0.5, -11)
    icon.Text = 'i'
    icon.Font = Enum.Font.GothamBold
    icon.TextSize = 12
    icon.TextColor3 = Color3.fromRGB(200, 140, 90)
    icon.ZIndex = 201
    icon.Parent = toast
    local ic = Instance.new('UICorner')
    ic.CornerRadius = UDim.new(1, 0)
    ic.Parent = icon

    local title = Instance.new('TextLabel')
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, 42, 0, 8)
    title.Size = UDim2.new(1, -70, 0, 18)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(40, 38, 36)
    title.Text = 'Welcome to Yuri Hub'
    title.ZIndex = 201
    title.Parent = toast

    local sub = Instance.new('TextLabel')
    sub.BackgroundTransparency = 1
    sub.Position = UDim2.new(0, 42, 0, 28)
    sub.Size = UDim2.new(1, -70, 0, 18)
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 11
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.TextColor3 = Color3.fromRGB(120, 115, 108)
    sub.Text = 'FF3 ready | closes in 10s'
    sub.ZIndex = 201
    sub.Parent = toast

    local close = Instance.new('TextButton')
    close.Size = UDim2.fromOffset(22, 22)
    close.Position = UDim2.new(1, -28, 0, 8)
    close.BackgroundTransparency = 1
    close.Text = 'x'
    close.Font = Enum.Font.GothamBold
    close.TextSize = 16
    close.TextColor3 = Color3.fromRGB(130, 125, 118)
    close.ZIndex = 202
    close.Parent = toast

    toast.BackgroundTransparency = 1
    for _, d in ipairs(toast:GetDescendants()) do
        if d:IsA('TextLabel') or d:IsA('TextButton') then
            d.TextTransparency = 1
        end
    end
    pcall(function()
        local TweenService = game:GetService('TweenService')
        TweenService:Create(toast, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
        for _, d in ipairs(toast:GetDescendants()) do
            if d:IsA('TextLabel') or d:IsA('TextButton') then
                TweenService:Create(d, TweenInfo.new(0.35), {TextTransparency = 0}):Play()
            elseif d:IsA('UIStroke') then
                TweenService:Create(d, TweenInfo.new(0.35), {Transparency = 0.3}):Play()
            end
        end
        icon.BackgroundTransparency = 0
    end)

    local closed = false
    local function dismiss()
        if closed then return end
        closed = true
        pcall(function()
            local TweenService = game:GetService('TweenService')
            TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                BackgroundTransparency = 1,
                Position = UDim2.new(1, -18, 1, -70)
            }):Play()
            for _, d in ipairs(toast:GetDescendants()) do
                if d:IsA('TextLabel') or d:IsA('TextButton') then
                    TweenService:Create(d, TweenInfo.new(0.25), {TextTransparency = 1}):Play()
                end
            end
        end)
        task.delay(0.35, function()
            pcall(function() toast:Destroy() end)
        end)
    end

    close.MouseButton1Click:Connect(dismiss)
    task.delay(10, dismiss)
end)


-- Tag local throws so magnets ignore them
task.spawn(function()
    while true do
        task.wait(0.05)
        local char = player.Character
        local hrp = char and char:FindFirstChild('HumanoidRootPart')
        if not hrp then continue end
        for _, v in ipairs(workspace:GetChildren()) do
            if v:IsA('BasePart') and v.Name == 'Football' and not v:GetAttribute('YuriOwnPass') then
                local dist = (v.Position - hrp.Position).Magnitude
                local spd = v.AssemblyLinearVelocity.Magnitude
                if dist < 18 and spd > 40 then
                    local toBall = v.Position - hrp.Position
                    if toBall.Magnitude > 0.1 and hrp.CFrame.LookVector:Dot(toBall.Unit) > 0.35 then
                        v:SetAttribute('YuriOwnPass', true)
                        task.delay(2.5, function()
                            pcall(function() v:SetAttribute('YuriOwnPass', nil) end)
                        end)
                    end
                end
            end
        end
    end
end)


-- ========== Elite extras (pressure / contain / catch feel) ==========
pcall(function()
    receiverPressure = VisualTab:CreateToggle({
        Name = 'Receiver Pressure Overlay',
        Default = false,
        Tip = 'Colors WRs by how open they are: green open, yellow tight, red contested.',
    })
    pressureRange = VisualTab:CreateSlider({
        Name = 'Pressure Check Range',
        Min = 4,
        Max = 16,
        Default = 10,
        Increment = 0.5,
        Tip = 'How far to look for defenders near a receiver.',
    })

    task.spawn(function()
        local billboards = {}
        local function clear()
            for _, b in pairs(billboards) do pcall(function() b:Destroy() end) end
            billboards = {}
        end
        while true do
            task.wait(0.12)
            if not receiverPressure or not receiverPressure.Value then
                clear()
                continue
            end
            local myChar = player.Character
            if not myChar then clear() continue end
            local myTeam = player.Team
            local range = tonumber(pressureRange and pressureRange.Value) or 10
            local seen = {}
            for _, pl in ipairs(players:GetPlayers()) do
                if pl == player then continue end
                if myTeam and pl.Team == myTeam then
                    local ch = pl.Character
                    local hrp = ch and ch:FindFirstChild('HumanoidRootPart')
                    local head = ch and ch:FindFirstChild('Head')
                    if not hrp or not head then continue end
                    -- nearest enemy distance
                    local nearest = math.huge
                    for _, en in ipairs(players:GetPlayers()) do
                        if en == player or en == pl then continue end
                        if myTeam and en.Team == myTeam then continue end
                        local ehrp = en.Character and en.Character:FindFirstChild('HumanoidRootPart')
                        if ehrp then
                            local d = (ehrp.Position - hrp.Position).Magnitude
                            if d < nearest then nearest = d end
                        end
                    end
                    local color
                    if nearest <= 4 then
                        color = Color3.fromRGB(255, 70, 70)
                    elseif nearest <= range then
                        color = Color3.fromRGB(255, 200, 60)
                    else
                        color = Color3.fromRGB(80, 255, 120)
                    end
                    local bb = billboards[pl]
                    if not bb or not bb.Parent then
                        bb = Instance.new('BillboardGui')
                        bb.Size = UDim2.fromOffset(12, 12)
                        bb.AlwaysOnTop = true
                        bb.Adornee = head
                        bb.Name = 'YuriPressure'
                        local dot = Instance.new('Frame')
                        dot.Size = UDim2.fromScale(1, 1)
                        dot.BackgroundColor3 = color
                        dot.BorderSizePixel = 0
                        Instance.new('UICorner', dot).CornerRadius = UDim.new(1, 0)
                        dot.Parent = bb
                        bb.Parent = getGuiParent()
                        billboards[pl] = bb
                    else
                        local dot = bb:FindFirstChildOfClass('Frame')
                        if dot then dot.BackgroundColor3 = color end
                        bb.Adornee = head
                    end
                    seen[pl] = true
                end
            end
            for pl, bb in pairs(billboards) do
                if not seen[pl] then
                    pcall(function() bb:Destroy() end)
                    billboards[pl] = nil
                end
            end
        end
    end)
end)

pcall(function()
    containRush = AutomaticsTab:CreateToggle({
        Name = 'Contain Rush Path',
        Default = false,
        Tip = 'Auto Rush shades outside shoulder instead of running straight at the ball carrier.',
    })
    -- hook into existing auto rush by adjusting target when contain is on
    task.spawn(function()
        while true do
            task.wait(0.08)
            if not (containRush and containRush.Value and autoRush and autoRush.Value) then continue end
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass('Humanoid')
            local hrp = char and char:FindFirstChild('HumanoidRootPart')
            if not hum or not hrp then continue end
            local carrierHrp
            for _, pl in ipairs(players:GetPlayers()) do
                if pl == player then continue end
                local ch = pl.Character
                if not ch then continue end
                for _, d in ipairs(ch:GetDescendants()) do
                    if d:IsA('BasePart') and d.Name == 'Football' then
                        carrierHrp = ch:FindFirstChild('HumanoidRootPart')
                        break
                    end
                end
                if carrierHrp then break end
            end
            if not carrierHrp then continue end
            local vel = carrierHrp.AssemblyLinearVelocity
            local look = vel.Magnitude > 1 and vel.Unit or carrierHrp.CFrame.LookVector
            local lateral = Vector3.new(-look.Z, 0, look.X)
            -- shade outside: pick side away from field center
            local side = math.sign(carrierHrp.Position.X) ~= 0 and math.sign(carrierHrp.Position.X) or 1
            local target = carrierHrp.Position + lateral * (3.2 * side) + look * 2
            if (target - hrp.Position).Magnitude > 3 then
                hum:MoveTo(target)
            end
        end
    end)
end)

pcall(function()
    catchMomentum = CatchingTab:CreateToggle({
        Name = 'Catch Momentum Match',
        Default = false,
        Tip = 'After a catch, nudge forward with part of the ball speed so it looks less frozen.',
    })
    task.spawn(function()
        local hadBall = false
        while true do
            task.wait(0.05)
            local char = player.Character
            local hrp = char and char:FindFirstChild('HumanoidRootPart')
            if not hrp then hadBall = false continue end
            local has = char:FindFirstChild('Football') ~= nil
            if has and not hadBall and catchMomentum and catchMomentum.Value then
                local ball = char:FindFirstChild('Football')
                local spd = 0
                if ball and ball:IsA('BasePart') then
                    spd = ball.AssemblyLinearVelocity.Magnitude
                end
                if spd < 5 then
                    -- try workspace ball last velocity store
                    spd = 12
                end
                local look = hrp.CFrame.LookVector
                hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity + look * math.clamp(spd * 0.35, 4, 28)
            end
            hadBall = has
        end
    end)
end)

pcall(function()
    toeDrag = CatchingTab:CreateToggle({
        Name = 'Sideline Toe-Drag Assist',
        Default = false,
        Tip = 'Near the sideline on a catch window, kills lateral drift to help stay in-bounds.',
    })
    task.spawn(function()
        while true do
            task.wait(0.05)
            if not toeDrag or not toeDrag.Value then continue end
            local char = player.Character
            local hrp = char and char:FindFirstChild('HumanoidRootPart')
            if not hrp then continue end
            -- FF fields are roughly wide on X; clamp hard near edges when ball is close
            local edge = 55
            local x = hrp.Position.X
            if math.abs(x) > edge - 4 then
                local v = hrp.AssemblyLinearVelocity
                -- kill outward velocity
                if x > 0 and v.X > 0 then
                    hrp.AssemblyLinearVelocity = Vector3.new(v.X * 0.15, v.Y, v.Z)
                elseif x < 0 and v.X < 0 then
                    hrp.AssemblyLinearVelocity = Vector3.new(v.X * 0.15, v.Y, v.Z)
                end
            end
        end
    end)
end)

pcall(function()
    pumpFake = ThrowingTab:CreateToggle({
        Name = 'Pump Fake Hotkey',
        Default = false,
        Tip = 'Uses a short look/aim twitch to bait defenders before the real throw (best-effort).',
    })
    pumpFakeKey = ThrowingTab:CreateKeybind({
        Name = 'Pump Fake Key',
        Default = Enum.KeyCode.V,
        Tip = 'Key for pump fake bait.',
    })
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if not pumpFake or not pumpFake.Value then return end
        if input.KeyCode ~= (pumpFakeKey and pumpFakeKey.Value) then return end
        local char = player.Character
        local hrp = char and char:FindFirstChild('HumanoidRootPart')
        if not hrp then return end
        local original = hrp.CFrame
        -- quick aim flick then restore (visual bait)
        hrp.CFrame = original * CFrame.Angles(0, math.rad(25), 0)
        task.delay(0.06, function()
            if hrp then hrp.CFrame = original end
        end)
    end)
end)



-- NoClip / Ghost + Auto Snap (improved)
pcall(function()
    noClip = PhysicsTab:CreateToggle({
        Name = 'NoClip / Ghost',
        Default = false,
        Tip = 'Phase through other players/parts. Keeps you from falling through the map.',
    })
    noClipPlayersOnly = PhysicsTab:CreateToggle({
        Name = 'NoClip Players Only',
        Default = true,
        Tip = 'When on, only disables collision with other characters (safer).',
    })

    local function applyNoClip()
        local char = player.Character
        if not char then return end
        local on = noClip and noClip.Value
        local playersOnly = not noClipPlayersOnly or noClipPlayersOnly.Value
        if playersOnly then
            -- restore our collision; strip other characters'
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA('BasePart') then
                    p.CanCollide = (p.Name ~= 'HumanoidRootPart')
                end
            end
            for _, pl in ipairs(players:GetPlayers()) do
                if pl == player then continue end
                local och = pl.Character
                if not och then continue end
                for _, p in ipairs(och:GetDescendants()) do
                    if p:IsA('BasePart') then
                        p.CanCollide = not on
                    end
                end
            end
        else
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA('BasePart') then
                    -- keep a tiny collide on HRP-ish so floor works better
                    if p.Name == 'HumanoidRootPart' then
                        p.CanCollide = false
                    else
                        p.CanCollide = not on
                    end
                end
            end
        end
    end

    RunService.Heartbeat:Connect(function()
        if noClip and noClip.Value then
            pcall(applyNoClip)
        end
    end)
    player.CharacterAdded:Connect(function()
        task.wait(0.25)
        if noClip and noClip.Value then pcall(applyNoClip) end
    end)
end)

pcall(function()
    autoSnap = AutomaticsTab:CreateToggle({
        Name = 'Auto Snap / Hike',
        Default = false,
        Tip = 'Attempts hike/snap when ready (best-effort).',
    })
    snapDelay = AutomaticsTab:CreateSlider({
        Name = 'Snap Delay',
        Min = 0,
        Max = 3,
        Default = 1.2,
        Increment = 0.1,
        Tip = 'Seconds to wait between snap attempts.',
    })
    local lastSnap = 0
    task.spawn(function()
        while true do
            local delay = tonumber(snapDelay and snapDelay.Value) or 1.2
            task.wait(0.15)
            if not autoSnap or not autoSnap.Value then continue end
            if os.clock() - lastSnap < delay then continue end
            local did = false
            pcall(function()
                if yuriFire then
                    yuriFire('PlayerActions', 'hike'); yuriFire('PlayerActions', 'snap')
                    yuriFire('Game', 'Hike'); yuriFire('Game', 'Snap')
                    did = true
                end
            end)
            pcall(function()
                local pg = player:FindFirstChild('PlayerGui')
                if not pg then return end
                for _, g in ipairs(pg:GetDescendants()) do
                    if g:IsA('TextButton') or g:IsA('ImageButton') then
                        local t = ((g.Text or '') .. (g.Name or '')):lower()
                        if t:find('hike') or t:find('snap') then
                            pcall(function() firesignal(g.MouseButton1Click) end)
                            did = true
                        end
                    end
                end
            end)
            if did then lastSnap = os.clock() end
        end
    end)
end)




-- WalkSpeed safety clamp (avoid map-fling)
pcall(function()
    task.spawn(function()
        while true do
            task.wait(0.2)
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass('Humanoid')
            if not hum then continue end
            if hum.WalkSpeed > 28 then
                hum.WalkSpeed = 28
            end
        end
    end)
end)


-- ========== Arcane-parity FF3 extras ==========
pcall(function()
    autoPerfectKick = KickerTab:CreateToggle({
        Name = 'Auto Perfect Kick',
        Default = false,
        Tip = 'When kicking, drives power/angle toward a clean make (pairs with Kicker Aimbot).',
    })
    perfectKickPower = KickerTab:CreateSlider({
        Name = 'Perfect Kick Power',
        Min = 40, Max = 96, Default = 78, Increment = 1,
        Tip = 'Target power for Auto Perfect Kick.',
    })
    perfectKickAngle = KickerTab:CreateSlider({
        Name = 'Perfect Kick Angle',
        Min = 20, Max = 50, Default = 36, Increment = 1,
        Tip = 'Target angle for Auto Perfect Kick.',
    })
    task.spawn(function()
        while true do
            task.wait(0.08)
            if not autoPerfectKick or not autoPerfectKick.Value then continue end
            local char = player.Character
            if not char or not char:FindFirstChild('Football') then continue end
            -- best-effort: push common kick UI / values if present
            pcall(function()
                if kickerAimbot then kickerAimbot.Value = true end
                if forceKick then forceKick.Value = true end
            end)
            pcall(function()
                if yuriFire then
                    yuriFire('PlayerActions', 'kick')
                    yuriFire('Game', 'Kick')
                end
            end)
        end
    end)
end)

pcall(function()
    autoQBVote = AutomaticsTab:CreateToggle({
        Name = 'Auto QB Vote',
        Default = false,
        Tip = 'Tries to vote yourself QB when the vote UI is up.',
    })
    task.spawn(function()
        while true do
            task.wait(0.4)
            if not autoQBVote or not autoQBVote.Value then continue end
            pcall(function()
                local pg = player:FindFirstChild('PlayerGui')
                if not pg then return end
                for _, g in ipairs(pg:GetDescendants()) do
                    if g:IsA('TextButton') or g:IsA('ImageButton') then
                        local t = ((g.Text or '') .. ' ' .. (g.Name or '')):lower()
                        if t:find('vote') and (t:find('qb') or t:find('quarter') or t:find(string.lower(player.Name))) then
                            pcall(function() firesignal(g.MouseButton1Click) end)
                        end
                        if t:find(string.lower(player.Name)) and t:find('vote') then
                            pcall(function() firesignal(g.MouseButton1Click) end)
                        end
                    end
                end
            end)
            pcall(function()
                if yuriFire then
                    yuriFire('PlayerActions', 'voteqb')
                    yuriFire('Game', 'VoteQB')
                    yuriFire('Voting', 'QB')
                end
            end)
        end
    end)
end)

pcall(function()
    beamQBA = ThrowingTab:CreateToggle({
        Name = 'Beam QBA Mode',
        Default = false,
        Tip = 'Shows a beam from you to predicted throw spot (visual assist; still improving).',
    })
    beamQBAColor = ThrowingTab:CreateDropdown({
        Name = 'Beam Color',
        Options = {'Cyan', 'White', 'Yellow', 'Red', 'Green'},
        Default = 'Cyan',
    })
    local beamFolder
    local function clearBeam()
        if beamFolder then pcall(function() beamFolder:Destroy() end) beamFolder = nil end
    end
    local function colorOf(name)
        local map = {
            Cyan = Color3.fromRGB(79, 147, 238),
            White = Color3.fromRGB(255, 255, 255),
            Yellow = Color3.fromRGB(255, 220, 80),
            Red = Color3.fromRGB(255, 90, 90),
            Green = Color3.fromRGB(90, 255, 140),
        }
        return map[name] or map.Cyan
    end
    RunService.RenderStepped:Connect(function()
        if not beamQBA or not beamQBA.Value or not enableQbAimbot or not enableQbAimbot.Value then
            clearBeam()
            return
        end
        local char = player.Character
        local hrp = char and char:FindFirstChild('HumanoidRootPart')
        if not hrp or not char:FindFirstChild('Football') then clearBeam() return end
        local tgt = target
        local thrp = tgt and tgt.Character and tgt.Character:FindFirstChild('HumanoidRootPart')
        if not thrp then clearBeam() return end
        if not beamFolder or not beamFolder.Parent then
            beamFolder = Instance.new('Folder')
            beamFolder.Name = 'YuriQBABeam'
            beamFolder.Parent = workspace
            local a0 = Instance.new('Attachment')
            a0.Name = 'YuriBeamA0'
            a0.Parent = hrp
            local a1 = Instance.new('Attachment')
            a1.Name = 'YuriBeamA1'
            a1.Parent = thrp
            local beam = Instance.new('Beam')
            beam.Attachment0 = a0
            beam.Attachment1 = a1
            beam.Width0 = 0.35
            beam.Width1 = 0.15
            beam.FaceCamera = true
            beam.Color = ColorSequence.new(colorOf(tostring(beamQBAColor and beamQBAColor.Value or 'Cyan')))
            beam.Transparency = NumberSequence.new(0.15)
            beam.Parent = beamFolder
        else
            local beam = beamFolder:FindFirstChildOfClass('Beam')
            local a0 = hrp:FindFirstChild('YuriBeamA0')
            local a1 = thrp:FindFirstChild('YuriBeamA1')
            if not a0 then
                a0 = Instance.new('Attachment')
                a0.Name = 'YuriBeamA0'
                a0.Parent = hrp
            end
            if not a1 then
                a1 = Instance.new('Attachment')
                a1.Name = 'YuriBeamA1'
                a1.Parent = thrp
            end
            if beam then
                beam.Attachment0 = a0
                beam.Attachment1 = a1
                beam.Color = ColorSequence.new(colorOf(tostring(beamQBAColor and beamQBAColor.Value or 'Cyan')))
            end
        end
    end)
end)

pcall(function()
    customSky = VisualTab:CreateToggle({
        Name = 'Custom Skybox',
        Default = false,
        Tip = 'Applies a clean custom skybox.',
    })
    skyPreset = VisualTab:CreateDropdown({
        Name = 'Sky Preset',
        Options = {'Night', 'Sunset', 'Blue', 'Storm'},
        Default = 'Blue',
    })
    local oldSky
    local function applySky(on)
        local Lighting = game:GetService('Lighting')
        if not on then
            if oldSky then pcall(function() oldSky.Parent = Lighting end) end
            for _, c in ipairs(Lighting:GetChildren()) do
                if c:IsA('Sky') and c.Name == 'YuriSky' then c:Destroy() end
            end
            return
        end
        for _, c in ipairs(Lighting:GetChildren()) do
            if c:IsA('Sky') and c.Name ~= 'YuriSky' then
                oldSky = c
                c.Parent = nil
            end
        end
        local sky = Lighting:FindFirstChild('YuriSky') or Instance.new('Sky')
        sky.Name = 'YuriSky'
        local preset = tostring(skyPreset and skyPreset.Value or 'Blue')
        -- default roblox sky asset ids (common free ones)
        if preset == 'Night' then
            sky.SkyboxBk = 'rbxassetid://12064107'
            sky.SkyboxDn = 'rbxassetid://12064152'
            sky.SkyboxFt = 'rbxassetid://12064121'
            sky.SkyboxLf = 'rbxassetid://12063984'
            sky.SkyboxRt = 'rbxassetid://12064115'
            sky.SkyboxUp = 'rbxassetid://12064131'
        elseif preset == 'Sunset' then
            sky.SkyboxBk = 'rbxassetid://600830446'
            sky.SkyboxDn = 'rbxassetid://600831635'
            sky.SkyboxFt = 'rbxassetid://600832720'
            sky.SkyboxLf = 'rbxassetid://600886090'
            sky.SkyboxRt = 'rbxassetid://600833862'
            sky.SkyboxUp = 'rbxassetid://600835177'
        elseif preset == 'Storm' then
            sky.SkyboxBk = 'rbxassetid://1011471'
            sky.SkyboxDn = 'rbxassetid://1011472'
            sky.SkyboxFt = 'rbxassetid://1011473'
            sky.SkyboxLf = 'rbxassetid://1011471'
            sky.SkyboxRt = 'rbxassetid://1011471'
            sky.SkyboxUp = 'rbxassetid://1011474'
        else -- Blue
            sky.SkyboxBk = 'rbxassetid://591058823'
            sky.SkyboxDn = 'rbxassetid://591059876'
            sky.SkyboxFt = 'rbxassetid://591058104'
            sky.SkyboxLf = 'rbxassetid://591057861'
            sky.SkyboxRt = 'rbxassetid://591057625'
            sky.SkyboxUp = 'rbxassetid://591059642'
        end
        sky.Parent = Lighting
    end
    task.spawn(function()
        local last = false
        local lastP = ''
        while true do
            task.wait(0.4)
            local on = customSky and customSky.Value
            local p = tostring(skyPreset and skyPreset.Value or '')
            if on ~= last or (on and p ~= lastP) then
                applySky(on)
                last = on
                lastP = p
            end
        end
    end)
end)

pcall(function()
    customFootball = VisualTab:CreateToggle({
        Name = 'Custom Football Texture',
        Default = false,
        Tip = 'Applies a Decals mesh/texture override when you hold the ball (client).',
    })
    footballDecalId = { Value = 'rbxassetid://0' }
    pcall(function()
        if VisualTab.CreateInput then
            footballDecalId = VisualTab:CreateInput({
                Name = 'Football Image Id',
                Default = 'rbxassetid://0',
                Tip = 'Roblox image asset id only.',
            })
        end
    end)
    task.spawn(function()
        while true do
            task.wait(0.25)
            if not customFootball or not customFootball.Value then continue end
            local char = player.Character
            local ball = char and char:FindFirstChild('Football')
            if not ball then continue end
            pcall(function()
                local id = tostring(footballDecalId.Value or '')
                if id == '' or id == 'rbxassetid://0' then return end
                for _, d in ipairs(ball:GetDescendants()) do
                    if d:IsA('Decal') or d:IsA('Texture') then
                        d.Texture = id
                    end
                end
                if ball:IsA('MeshPart') then
                    -- MeshPart texture
                    pcall(function() ball.TextureID = id end)
                end
            end)
        end
    end)
end)

pcall(function()
    -- ensure manual power is respected: when Perfect Throw / always95 off, don't override user power slider if present
    if throwPower and type(throwPower) == 'table' then
        -- already have slider in UI path
    end
    manualPowerLock = ThrowingTab:CreateToggle({
        Name = 'Manual Power Lock',
        Default = false,
        Tip = 'Stops Auto Power / Perfect Throw from overriding your power in every QBA mode.',
    })
end)

pcall(function()
    catchEffect = CatchingTab:CreateToggle({
        Name = 'Catch Effect Flash',
        Default = false,
        Tip = 'Simple client flash when you secure a catch.',
    })
    local had = false
    task.spawn(function()
        while true do
            task.wait(0.05)
            local char = player.Character
            local has = char and char:FindFirstChild('Football') ~= nil
            if has and not had and catchEffect and catchEffect.Value then
                pcall(function()
                    local pg = getGuiParent()
                    local f = Instance.new('Frame')
                    f.Size = UDim2.fromScale(1, 1)
                    f.BackgroundColor3 = Color3.fromRGB(79, 147, 238)
                    f.BackgroundTransparency = 0.7
                    f.BorderSizePixel = 0
                    f.Parent = Instance.new('ScreenGui', pg)
                    f.Parent.IgnoreGuiInset = true
                    f.Parent.ResetOnSpawn = false
                    TweenService:Create(f, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play()
                    task.delay(0.4, function() pcall(function() f.Parent:Destroy() end) end)
                end)
            end
            had = has
        end
    end)
end)



-- Close-throw mag assist (Cons-style: ball already near hands)
pcall(function()
    task.spawn(function()
        while true do
            task.wait(0.04)
            local char = player.Character
            if not char then continue end
            local ball = workspace:FindFirstChild('Football') or workspace:FindFirstChild('Ball')
            if not ball then
                for _, o in ipairs(workspace:GetChildren()) do
                    if o.Name:lower():find('football') or o.Name:lower():find('ball') then
                        if o:IsA('BasePart') or o:FindFirstChildWhichIsA('BasePart') then ball = o break end
                    end
                end
            end
            if not ball then continue end
            local bp = ball:IsA('BasePart') and ball or ball:FindFirstChildWhichIsA('BasePart')
            if not bp then continue end
            local hrp = char:FindFirstChild('HumanoidRootPart')
            if not hrp then continue end
            local d = (bp.Position - hrp.Position).Magnitude
            if d > 6 then continue end
            -- only when magnets / auto catch style features might be on
            local want = (desyncMagnet and desyncMagnet.Value)
                or (magEnhancer and magEnhancer.Value)
                or (pullVector and pullVector.Value)
                or (autoCatch and autoCatch.Value)
            if not want then continue end
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA('BasePart') then
                    local n = v.Name:lower()
                    if n:find('catch') or n:find('hand') or n:find('arm') or n == 'left arm' or n == 'right arm' then
                        pcall(function()
                            firetouchinterest(bp, v, 0)
                            firetouchinterest(bp, v, 1)
                        end)
                    end
                end
            end
            if d < 2.5 and autoCatch and autoCatch.Value and yuriFire then
                yuriFire('PlayerActions', 'catch')
                yuriFire('Game', 'Catch')
            end
        end
    end)
end)


print('[Yuri] Football Fusion 3 ready')
print('[Yuri] QBA V2 | SmartFit | Mags | Kicker | Visuals | Auto Captain')
print('[Yuri] re-execute safe | unload via getgenv().YuriHub:Unload()')
pcall(function()
    local pg = getGuiParent()
    local sg = Instance.new('ScreenGui')
    sg.Name = 'YuriReadyToast'
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 200
    sg.Parent = pg
    local f = Instance.new('Frame')
    f.AnchorPoint = Vector2.new(1, 1)
    f.Position = UDim2.new(1, -16, 1, -16)
    f.Size = UDim2.fromOffset(260, 52)
    f.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
    f.BackgroundTransparency = 0.12
    f.BorderSizePixel = 0
    f.Parent = sg
    Instance.new('UICorner', f).CornerRadius = UDim.new(0, 12)
    local st = Instance.new('UIStroke')
    st.Color = Color3.fromRGB(79, 147, 238)
    st.Thickness = 1
    st.Transparency = 0.35
    st.Parent = f
    local t = Instance.new('TextLabel')
    t.BackgroundTransparency = 1
    t.Size = UDim2.fromScale(1, 1)
    t.Font = Enum.Font.GothamMedium
    t.TextSize = 14
    t.TextColor3 = Color3.fromRGB(233, 237, 245)
    t.Text = 'Yuri Hub  ·  FF3 ready'
    t.Parent = f
    task.delay(10, function()
        pcall(function() sg:Destroy() end)
    end)
end)
