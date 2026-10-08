--[[
    Custom Obsidian-style UI Library for Roblox (Luau)
    ---------------------------------------------------
    Features:
      Window (draggable, toggle keybind), sidebar Tabs, Left/Right Groupboxes
      Elements: Label, Divider, Button, Toggle, Slider, Input, Dropdown (single/multi), Keybind
      Library.Toggles / Library.Options (global lookup by index, like Obsidian)
      Notifications, live theme switching, Unload

    Usage:
      local Library = loadstring(readfile("ObsidianLib.lua"))()   -- or paste / require it
      See Example.lua
]]

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local CoreGui          = game:GetService("CoreGui")

local Library = {
    Toggles = {},
    Options = {},
    Registry = {},
    Connections = {},
    Unloaded = false,
    Version = "1.0.0",
    Theme = {
        Background = Color3.fromRGB(18, 18, 22),
        Sidebar    = Color3.fromRGB(24, 24, 30),
        Groupbox   = Color3.fromRGB(28, 28, 35),
        Element    = Color3.fromRGB(38, 38, 48),
        Outline    = Color3.fromRGB(55, 55, 70),
        Accent     = Color3.fromRGB(138, 99, 255),
        Text       = Color3.fromRGB(235, 235, 245),
        SubText    = Color3.fromRGB(150, 150, 170),
    },
}

Library.Themes = {
    Obsidian = Library.Theme,
    Ocean = {
        Background = Color3.fromRGB(12, 18, 26), Sidebar = Color3.fromRGB(16, 24, 34),
        Groupbox = Color3.fromRGB(20, 30, 42), Element = Color3.fromRGB(28, 42, 58),
        Outline = Color3.fromRGB(45, 65, 90), Accent = Color3.fromRGB(56, 189, 248),
        Text = Color3.fromRGB(230, 240, 250), SubText = Color3.fromRGB(130, 155, 180),
    },
    Rose = {
        Background = Color3.fromRGB(22, 14, 18), Sidebar = Color3.fromRGB(30, 18, 24),
        Groupbox = Color3.fromRGB(36, 22, 29), Element = Color3.fromRGB(50, 30, 40),
        Outline = Color3.fromRGB(80, 50, 64), Accent = Color3.fromRGB(244, 63, 120),
        Text = Color3.fromRGB(250, 235, 240), SubText = Color3.fromRGB(180, 140, 155),
    },
}

------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------
local FONT = Enum.Font.GothamMedium

local function New(class, props, children)
    local inst = Instance.new(class)
    local parent
    for k, v in pairs(props or {}) do
        if k == "Parent" then parent = v else inst[k] = v end
    end
    for _, c in ipairs(children or {}) do c.Parent = inst end
    if parent then inst.Parent = parent end
    return inst
end

-- Registers an instance so its colors follow the theme. map = { Property = "ThemeKey" }
local function Themed(inst, map)
    for prop, key in pairs(map) do inst[prop] = Library.Theme[key] end
    table.insert(Library.Registry, { Instance = inst, Map = map })
    return inst
end

local function Corner(parent, radius)
    return New("UICorner", { CornerRadius = UDim.new(0, radius or 4), Parent = parent })
end

local function Stroke(parent, key)
    local s = New("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent })
    return Themed(s, { Color = key or "Outline" })
end

local function Pad(parent, l, t, r, b)
    return New("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0), PaddingTop = UDim.new(0, t or 0),
        PaddingRight = UDim.new(0, r or 0), PaddingBottom = UDim.new(0, b or 0),
        Parent = parent,
    })
end

local function List(parent, padding)
    return New("UIListLayout", {
        Padding = UDim.new(0, padding or 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = parent,
    })
end

local function Tween(inst, props, t)
    TweenService:Create(inst, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function Connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(Library.Connections, c)
    return c
end

local function Label(props)
    local l = New("TextLabel", {
        BackgroundTransparency = 1, Font = FONT, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 18),
    })
    for k, v in pairs(props) do
        if k ~= "ThemeKey" then l[k] = v end
    end
    return Themed(l, { TextColor3 = props.ThemeKey or "Text" })
end

local function IsClick(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local function Signal()
    local s = { _fns = {} }
    function s:Connect(fn) table.insert(self._fns, fn) end
    function s:Fire(...)
        for _, fn in ipairs(self._fns) do task.spawn(fn, ...) end
    end
    return s
end

local function GetParentGui()
    local gui = New("ScreenGui", {
        Name = "ObsidianLib_" .. tostring(math.random(1000, 9999)),
        ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
    })
    local ok = pcall(function()
        if typeof(gethui) == "function" then gui.Parent = gethui()
        else gui.Parent = CoreGui end
    end)
    if not ok or not gui.Parent then
        gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end
    return gui
end

------------------------------------------------------------------
-- Theme API
------------------------------------------------------------------
function Library:SetTheme(themeOrName)
    local t = type(themeOrName) == "string" and self.Themes[themeOrName] or themeOrName
    if type(t) ~= "table" then return end
    for k, v in pairs(t) do self.Theme[k] = v end
    for _, entry in ipairs(self.Registry) do
        if entry.Instance and entry.Instance.Parent then
            for prop, key in pairs(entry.Map) do
                Tween(entry.Instance, { [prop] = self.Theme[key] }, 0.25)
            end
        end
    end
end

------------------------------------------------------------------
-- Notifications
------------------------------------------------------------------
function Library:Notify(text, duration, title)
    if not self.NotifyHolder then return end
    duration = duration or 4

    local frame = Themed(New("Frame", {
        Size = UDim2.new(0, 260, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        Parent = self.NotifyHolder,
    }), { BackgroundColor3 = "Groupbox" })
    Corner(frame, 5); Stroke(frame)

    local inner = New("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, Parent = frame,
    })
    Pad(inner, 10, 8, 10, 12); List(inner, 2)

    Label({ Text = title or "Notification", Font = Enum.Font.GothamBold, ThemeKey = "Accent", Parent = inner })
    Label({
        Text = text, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 16), Parent = inner,
    })

    local bar = Themed(New("Frame", {
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 2), BorderSizePixel = 0, Parent = frame,
    }), { BackgroundColor3 = "Accent" })

    Tween(bar, { Size = UDim2.new(0, 0, 0, 2) }, duration)
    task.delay(duration, function()
        if frame.Parent then
            Tween(frame, { BackgroundTransparency = 1 }, 0.25)
            task.wait(0.25)
            frame:Destroy()
        end
    end)
end

------------------------------------------------------------------
-- Window
------------------------------------------------------------------
function Library:CreateWindow(cfg)
    cfg = cfg or {}
    local Window = { Tabs = {}, ActiveTab = nil, Visible = true }
    local size = cfg.Size or UDim2.fromOffset(620, 440)

    local gui = GetParentGui()
    self.ScreenGui = gui

    self.NotifyHolder = New("Frame", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -16, 1, -16), Size = UDim2.new(0, 260, 1, -32), Parent = gui,
    })
    New("UIListLayout", {
        Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom, Parent = self.NotifyHolder,
    })

    local main = Themed(New("Frame", {
        Name = "Main", Size = size, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = cfg.Position or UDim2.fromScale(0.5, 0.5), Parent = gui,
        ClipsDescendants = true,
    }), { BackgroundColor3 = "Background" })
    Corner(main, 6); Stroke(main)

    -- Title bar
    local titlebar = Themed(New("Frame", {
        Size = UDim2.new(1, 0, 0, 34), BorderSizePixel = 0, Parent = main,
    }), { BackgroundColor3 = "Sidebar" })

    local accentLine = Themed(New("Frame", {
        Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1),
        BorderSizePixel = 0, Parent = titlebar,
    }), { BackgroundColor3 = "Accent" })

    Label({
        Text = cfg.Title or "Obsidian", Font = Enum.Font.GothamBold, TextSize = 14,
        Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.6, 0, 1, 0), Parent = titlebar,
    })
    Label({
        Text = cfg.Footer or ("v" .. Library.Version), ThemeKey = "SubText", TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
        Position = UDim2.new(0.4, -12, 0, 0), Size = UDim2.new(0.6, 0, 1, 0), Parent = titlebar,
    })

    -- Sidebar
    local sidebar = Themed(New("Frame", {
        Position = UDim2.fromOffset(0, 34), Size = UDim2.new(0, 130, 1, -34),
        BorderSizePixel = 0, Parent = main,
    }), { BackgroundColor3 = "Sidebar" })
    local sideList = New("ScrollingFrame", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0,
        ScrollBarThickness = 0, AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(), Parent = sidebar,
    })
    Pad(sideList, 6, 8, 6, 8); List(sideList, 4)

    local sideDivider = Themed(New("Frame", {
        Position = UDim2.new(0, 130, 0, 34), Size = UDim2.new(0, 1, 1, -34),
        BorderSizePixel = 0, Parent = main,
    }), { BackgroundColor3 = "Outline" })

    -- Content area
    local content = New("Frame", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(131, 34),
        Size = UDim2.new(1, -131, 1, -34), Parent = main,
    })

    -- Dragging
    do
        local dragging, dragStart, startPos
        Connect(titlebar.InputBegan, function(input)
            if IsClick(input) then
                dragging, dragStart, startPos = true, input.Position, main.Position
            end
        end)
        Connect(UserInputService.InputChanged, function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                local d = input.Position - dragStart
                main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                          startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)
        Connect(UserInputService.InputEnded, function(input)
            if IsClick(input) then dragging = false end
        end)
    end

    -- Toggle keybind
    Window.ToggleKey = cfg.ToggleKeybind or Enum.KeyCode.RightShift
    function Window:SetVisible(v)
        self.Visible = v
        main.Visible = v
    end
    function Window:Toggle() self:SetVisible(not self.Visible) end
    Connect(UserInputService.InputBegan, function(input, gpe)
        if gpe then return end
        if input.KeyCode == Window.ToggleKey then Window:Toggle() end
    end)

    ------------------------------------------------------------------
    -- Tabs
    ------------------------------------------------------------------
    function Window:AddTab(name)
        local Tab = { Name = name }

        local btn = Themed(New("TextButton", {
            Size = UDim2.new(1, 0, 0, 28), AutoButtonColor = false, Text = "",
            BackgroundTransparency = 1, Parent = sideList,
        }), { BackgroundColor3 = "Element" })
        Corner(btn, 4)
        local indicator = Themed(New("Frame", {
            Size = UDim2.new(0, 3, 0, 14), Position = UDim2.new(0, 0, 0.5, -7),
            BackgroundTransparency = 1, BorderSizePixel = 0, Parent = btn,
        }), { BackgroundColor3 = "Accent" })
        Corner(indicator, 2)
        local btnLabel = Label({
            Text = name, ThemeKey = "SubText", Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -12, 1, 0), Parent = btn,
        })

        local page = New("Frame", {
            BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = content,
        })

        local function Column(xScale, xOffset)
            local col = New("ScrollingFrame", {
                BackgroundTransparency = 1, BorderSizePixel = 0,
                Position = UDim2.new(xScale, xOffset, 0, 0),
                Size = UDim2.new(0.5, -12, 1, 0),
                ScrollBarThickness = 2, AutomaticCanvasSize = Enum.AutomaticSize.Y,
                CanvasSize = UDim2.new(), Parent = page,
            })
            Themed(col, { ScrollBarImageColor3 = "Accent" })
            Pad(col, 0, 8, 0, 8); List(col, 8)
            return col
        end
        local left  = Column(0, 8)
        local right = Column(0.5, 4)

        function Tab:Show()
            if Window.ActiveTab then Window.ActiveTab:Hide() end
            Window.ActiveTab = Tab
            page.Visible = true
            Tween(btn, { BackgroundTransparency = 0 })
            Tween(indicator, { BackgroundTransparency = 0 })
            btnLabel.TextColor3 = Library.Theme.Text
        end
        function Tab:Hide()
            page.Visible = false
            Tween(btn, { BackgroundTransparency = 1 })
            Tween(indicator, { BackgroundTransparency = 1 })
            btnLabel.TextColor3 = Library.Theme.SubText
        end
        Tab:Hide()

        Connect(btn.MouseButton1Click, function() Tab:Show() end)

        ------------------------------------------------------------------
        -- Groupboxes
        ------------------------------------------------------------------
        local function MakeGroupbox(parent, title)
            local Groupbox = {}

            local box = Themed(New("Frame", {
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = parent,
            }), { BackgroundColor3 = "Groupbox" })
            Corner(box, 5); Stroke(box); Pad(box, 8, 6, 8, 8); List(box, 6)

            Label({
                Text = title, Font = Enum.Font.GothamBold, ThemeKey = "Accent",
                LayoutOrder = -1, Parent = box,
            })

            function Groupbox:AddDivider()
                Themed(New("Frame", {
                    Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, Parent = box,
                }), { BackgroundColor3 = "Outline" })
                return Groupbox
            end

            function Groupbox:AddLabel(text, wrap)
                local l = Label({
                    Text = text, TextWrapped = wrap or false,
                    AutomaticSize = wrap and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
                    Parent = box,
                })
                local obj = {}
                function obj:SetText(t) l.Text = t end
                return obj
            end

            ---------------- Button ----------------
            function Groupbox:AddButton(opts, func)
                if type(opts) == "string" then opts = { Text = opts, Func = func } end
                local obj = { Func = opts.Func or opts.Callback or function() end }

                local b = Themed(New("TextButton", {
                    Size = UDim2.new(1, 0, 0, 26), AutoButtonColor = false,
                    Font = FONT, TextSize = 13, Text = opts.Text or "Button", Parent = box,
                }), { BackgroundColor3 = "Element", TextColor3 = "Text" })
                Corner(b, 4); Stroke(b)

                Connect(b.MouseEnter, function() Tween(b, { BackgroundColor3 = Library.Theme.Outline }) end)
                Connect(b.MouseLeave, function() Tween(b, { BackgroundColor3 = Library.Theme.Element }) end)
                Connect(b.MouseButton1Click, function()
                    Tween(b, { BackgroundColor3 = Library.Theme.Accent }, 0.05)
                    task.delay(0.1, function() Tween(b, { BackgroundColor3 = Library.Theme.Element }) end)
                    local ok, err = pcall(obj.Func)
                    if not ok then warn("[Obsidian] Button error: " .. tostring(err)) end
                end)

                function obj:SetText(t) b.Text = t end
                return obj
            end

            ---------------- Toggle ----------------
            function Groupbox:AddToggle(idx, opts)
                opts = opts or {}
                local Toggle = { Value = opts.Default or false, Type = "Toggle", Changed = Signal() }

                local row = New("TextButton", {
                    BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, 0, 0, 20), Parent = box,
                })
                local checkbox = Themed(New("Frame", {
                    Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(0, 2), Parent = row,
                }), { BackgroundColor3 = "Element" })
                Corner(checkbox, 3); Stroke(checkbox)
                local fill = Themed(New("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
                    Size = UDim2.fromScale(0, 0), BorderSizePixel = 0, Parent = checkbox,
                }), { BackgroundColor3 = "Accent" })
                Corner(fill, 2)
                Label({
                    Text = opts.Text or "Toggle", Position = UDim2.fromOffset(24, 0),
                    Size = UDim2.new(1, -24, 1, 0), Parent = row,
                })

                function Toggle:SetValue(v)
                    v = v and true or false
                    self.Value = v
                    Tween(fill, { Size = v and UDim2.fromOffset(10, 10) or UDim2.fromScale(0, 0) })
                    if opts.Callback then task.spawn(opts.Callback, v) end
                    self.Changed:Fire(v)
                end
                function Toggle:OnChanged(fn) self.Changed:Connect(fn) end

                Connect(row.MouseButton1Click, function() Toggle:SetValue(not Toggle.Value) end)

                if Toggle.Value then fill.Size = UDim2.fromOffset(10, 10) end
                Library.Toggles[idx] = Toggle
                return Toggle
            end

            ---------------- Slider ----------------
            function Groupbox:AddSlider(idx, opts)
                opts = opts or {}
                local Slider = {
                    Value = opts.Default or opts.Min or 0, Min = opts.Min or 0, Max = opts.Max or 100,
                    Rounding = opts.Rounding or 0, Type = "Slider", Changed = Signal(),
                }
                local suffix = opts.Suffix or ""

                local holder = New("Frame", {
                    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Parent = box,
                })
                Label({ Text = opts.Text or "Slider", Size = UDim2.new(0.6, 0, 0, 16), Parent = holder })
                local valueLabel = Label({
                    Text = "", ThemeKey = "SubText", TextXAlignment = Enum.TextXAlignment.Right,
                    Position = UDim2.fromScale(0.4, 0), Size = UDim2.new(0.6, 0, 0, 16), Parent = holder,
                })
                local bar = Themed(New("Frame", {
                    Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 10), Parent = holder,
                }), { BackgroundColor3 = "Element" })
                Corner(bar, 5); Stroke(bar)
                local fill = Themed(New("Frame", {
                    Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, Parent = bar,
                }), { BackgroundColor3 = "Accent" })
                Corner(fill, 5)

                function Slider:SetValue(v)
                    local mult = 10 ^ self.Rounding
                    v = math.clamp(math.floor(v * mult + 0.5) / mult, self.Min, self.Max)
                    self.Value = v
                    local rel = (v - self.Min) / math.max(self.Max - self.Min, 1e-9)
                    Tween(fill, { Size = UDim2.fromScale(rel, 1) }, 0.06)
                    valueLabel.Text = tostring(v) .. suffix
                    if opts.Callback then task.spawn(opts.Callback, v) end
                    self.Changed:Fire(v)
                end
                function Slider:OnChanged(fn) self.Changed:Connect(fn) end

                local dragging = false
                local function update(x)
                    local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
                    Slider:SetValue(Slider.Min + (Slider.Max - Slider.Min) * rel)
                end
                Connect(bar.InputBegan, function(i)
                    if IsClick(i) then dragging = true; update(i.Position.X) end
                end)
                Connect(UserInputService.InputChanged, function(i)
                    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
                        or i.UserInputType == Enum.UserInputType.Touch) then
                        update(i.Position.X)
                    end
                end)
                Connect(UserInputService.InputEnded, function(i)
                    if IsClick(i) then dragging = false end
                end)

                Slider:SetValue(Slider.Value)
                Library.Options[idx] = Slider
                return Slider
            end

            ---------------- Input ----------------
            function Groupbox:AddInput(idx, opts)
                opts = opts or {}
                local Input = { Value = opts.Default or "", Type = "Input", Changed = Signal() }

                local holder = New("Frame", {
                    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Parent = box,
                })
                Label({ Text = opts.Text or "Input", Size = UDim2.new(1, 0, 0, 16), Parent = holder })
                local tb = Themed(New("TextBox", {
                    Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 26),
                    Font = FONT, TextSize = 13, ClearTextOnFocus = false,
                    Text = Input.Value, PlaceholderText = opts.Placeholder or "",
                    TextXAlignment = Enum.TextXAlignment.Left, Parent = holder,
                }), { BackgroundColor3 = "Element", TextColor3 = "Text", PlaceholderColor3 = "SubText" })
                Corner(tb, 4); Pad(tb, 8, 0, 8, 0)
                local stroke = Stroke(tb)

                function Input:SetValue(v)
                    self.Value = tostring(v)
                    tb.Text = self.Value
                    if opts.Callback then task.spawn(opts.Callback, self.Value) end
                    self.Changed:Fire(self.Value)
                end
                function Input:OnChanged(fn) self.Changed:Connect(fn) end

                Connect(tb.Focused, function() Tween(stroke, { Color = Library.Theme.Accent }) end)
                Connect(tb.FocusLost, function()
                    Tween(stroke, { Color = Library.Theme.Outline })
                    Input:SetValue(tb.Text)
                end)

                Library.Options[idx] = Input
                return Input
            end

            ---------------- Dropdown ----------------
            function Groupbox:AddDropdown(idx, opts)
                opts = opts or {}
                local Dropdown = {
                    Values = opts.Values or {}, Multi = opts.Multi or false,
                    Value = opts.Multi and {} or opts.Default, Type = "Dropdown", Changed = Signal(),
                }
                if opts.Multi and type(opts.Default) == "table" then
                    for _, v in ipairs(opts.Default) do Dropdown.Value[v] = true end
                end

                local holder = New("Frame", {
                    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y, Parent = box,
                })
                List(holder, 2)
                Label({ Text = opts.Text or "Dropdown", Parent = holder })

                local header = Themed(New("TextButton", {
                    Size = UDim2.new(1, 0, 0, 26), AutoButtonColor = false, Text = "",
                    Parent = holder,
                }), { BackgroundColor3 = "Element" })
                Corner(header, 4); Stroke(header)
                local display = Label({
                    Text = "", Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -28, 1, 0),
                    TextTruncate = Enum.TextTruncate.AtEnd, Parent = header,
                })
                local arrow = Label({
                    Text = "▾", TextXAlignment = Enum.TextXAlignment.Center, ThemeKey = "SubText",
                    Position = UDim2.new(1, -22, 0, 0), Size = UDim2.fromOffset(18, 26), Parent = header,
                })

                local list = Themed(New("Frame", {
                    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                    Visible = false, Parent = holder,
                }), { BackgroundColor3 = "Element" })
                Corner(list, 4); Stroke(list); Pad(list, 3, 3, 3, 3); List(list, 2)

                local optionButtons = {}

                local function isSelected(v)
                    if Dropdown.Multi then return Dropdown.Value[v] == true end
                    return Dropdown.Value == v
                end

                local function refreshDisplay()
                    if Dropdown.Multi then
                        local picked = {}
                        for _, v in ipairs(Dropdown.Values) do
                            if Dropdown.Value[v] then table.insert(picked, tostring(v)) end
                        end
                        display.Text = #picked > 0 and table.concat(picked, ", ") or "None"
                    else
                        display.Text = Dropdown.Value ~= nil and tostring(Dropdown.Value) or "None"
                    end
                    for v, b in pairs(optionButtons) do
                        local sel = isSelected(v)
                        b.TextColor3 = sel and Library.Theme.Accent or Library.Theme.Text
                        b.BackgroundTransparency = sel and 0.85 or 1
                    end
                end

                local function fire()
                    refreshDisplay()
                    if opts.Callback then task.spawn(opts.Callback, Dropdown.Value) end
                    Dropdown.Changed:Fire(Dropdown.Value)
                end

                local function build()
                    for _, b in pairs(optionButtons) do b:Destroy() end
                    optionButtons = {}
                    for _, v in ipairs(Dropdown.Values) do
                        local b = New("TextButton", {
                            Size = UDim2.new(1, 0, 0, 22), AutoButtonColor = false, Font = FONT,
                            TextSize = 13, Text = tostring(v), TextXAlignment = Enum.TextXAlignment.Left,
                            BackgroundColor3 = Library.Theme.Accent, BackgroundTransparency = 1,
                            Parent = list,
                        })
                        Corner(b, 3); Pad(b, 6, 0, 6, 0)
                        optionButtons[v] = b
                        Connect(b.MouseButton1Click, function()
                            if Dropdown.Multi then
                                Dropdown.Value[v] = not Dropdown.Value[v] or nil
                            else
                                Dropdown.Value = v
                                list.Visible = false
                                arrow.Text = "▾"
                            end
                            fire()
                        end)
                    end
                    refreshDisplay()
                end

                function Dropdown:SetValue(v)
                    if self.Multi then
                        self.Value = {}
                        for k, on in pairs(v or {}) do
                            if type(k) == "number" then self.Value[on] = true
                            elseif on then self.Value[k] = true end
                        end
                    else
                        self.Value = v
                    end
                    fire()
                end
                function Dropdown:SetValues(values)
                    self.Values = values
                    build()
                end
                function Dropdown:OnChanged(fn) self.Changed:Connect(fn) end

                Connect(header.MouseButton1Click, function()
                    list.Visible = not list.Visible
                    arrow.Text = list.Visible and "▴" or "▾"
                end)

                build()
                Library.Options[idx] = Dropdown
                return Dropdown
            end

            ---------------- Keybind ----------------
            function Groupbox:AddKeybind(idx, opts)
                opts = opts or {}
                local Keybind = { Value = opts.Default or Enum.KeyCode.Unknown, Type = "Keybind", Changed = Signal() }

                local row = New("Frame", {
                    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), Parent = box,
                })
                Label({
                    Text = opts.Text or "Keybind", Size = UDim2.new(1, -70, 1, 0), Parent = row,
                })
                local btn = Themed(New("TextButton", {
                    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
                    Size = UDim2.fromOffset(64, 22), AutoButtonColor = false, Font = FONT,
                    TextSize = 12, Text = "", Parent = row,
                }), { BackgroundColor3 = "Element", TextColor3 = "Text" })
                Corner(btn, 4); Stroke(btn)

                local listening = false
                local function render()
                    btn.Text = listening and "..." or (Keybind.Value == Enum.KeyCode.Unknown and "None" or Keybind.Value.Name)
                end

                function Keybind:SetValue(key)
                    self.Value = key
                    render()
                    self.Changed:Fire(key)
                end
                function Keybind:OnChanged(fn) self.Changed:Connect(fn) end
                function Keybind:OnClick(fn) self.Clicked = fn end

                Connect(btn.MouseButton1Click, function()
                    listening = true
                    render()
                end)
                Connect(UserInputService.InputBegan, function(input, gpe)
                    if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                        listening = false
                        Keybind:SetValue(input.KeyCode == Enum.KeyCode.Escape and Enum.KeyCode.Unknown or input.KeyCode)
                    elseif not gpe and not listening and input.KeyCode == Keybind.Value
                        and Keybind.Value ~= Enum.KeyCode.Unknown then
                        if opts.Callback then task.spawn(opts.Callback) end
                        if Keybind.Clicked then task.spawn(Keybind.Clicked) end
                    end
                end)

                render()
                Library.Options[idx] = Keybind
                return Keybind
            end

            return Groupbox
        end

        function Tab:AddLeftGroupbox(title)  return MakeGroupbox(left, title) end
        function Tab:AddRightGroupbox(title) return MakeGroupbox(right, title) end

        table.insert(Window.Tabs, Tab)
        if not Window.ActiveTab then Tab:Show() end
        return Tab
    end

    function Window:SetTitle(t) titlebar:FindFirstChildWhichIsA("TextLabel").Text = t end

    Library.Window = Window
    return Window
end

------------------------------------------------------------------
-- Unload
------------------------------------------------------------------
function Library:Unload()
    self.Unloaded = true
    for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
    if self.ScreenGui then self.ScreenGui:Destroy() end
    if self.OnUnload then pcall(self.OnUnload) end
end

return Library
