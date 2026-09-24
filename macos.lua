--[[
    MacOSKit
    Stable native Roblox UI library for the Empire script.
    Keeps the existing Elerium-style API used by "windows":
        Window = Library:AddWindow(title, config)
        Tab = Window:AddTab(name)
        Tab:AddLabel(text)
        Tab:AddButton(text, callback)
        Tab:AddTextBox(label, callback)
        Tab:AddSwitch(text, callback)
        Tab:AddToggle(text, default, callback)
        Tab:AddSection(text)
        Tab:Show()
        Switch:Set(value)
        Switch:Get()
        Window:Notify(title, message, duration)
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

local MacOSKit = {}
MacOSKit.__index = MacOSKit
MacOSKit.Version = "2.0.0"

local Themes = {
    Violet = {accent = Color3.fromRGB(122, 90, 230), accent2 = Color3.fromRGB(58, 143, 255)},
    Midnight = {accent = Color3.fromRGB(47, 95, 224), accent2 = Color3.fromRGB(31, 176, 224)},
    Emerald = {accent = Color3.fromRGB(34, 197, 138), accent2 = Color3.fromRGB(31, 174, 106)},
    Crimson = {accent = Color3.fromRGB(255, 95, 87), accent2 = Color3.fromRGB(224, 57, 47)},
    Mono = {accent = Color3.fromRGB(154, 154, 160), accent2 = Color3.fromRGB(95, 95, 102)},
}

local function safeCall(fn, ...)
    local args = table.pack(...)
    return pcall(function()
        return fn(table.unpack(args, 1, args.n))
    end)
end

local function tween(instance, duration, properties, style, direction)
    if not instance or not instance.Parent then return end
    local ok, result = pcall(function()
        local info = TweenInfo.new(
            duration or 0.2,
            style or Enum.EasingStyle.Quad,
            direction or Enum.EasingDirection.Out
        )
        local t = TweenService:Create(instance, info, properties)
        t:Play()
        return t
    end)
    return ok and result or nil
end

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

local function addStroke(parent, color, transparency, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.new(1, 1, 1)
    s.Transparency = transparency or 0
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function addPadding(parent, left, right, top, bottom)
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0, left or 0)
    p.PaddingRight = UDim.new(0, right == nil and (left or 0) or right)
    p.PaddingTop = UDim.new(0, top == nil and (left or 0) or top)
    p.PaddingBottom = UDim.new(0, bottom == nil and (top == nil and (left or 0) or top) or bottom)
    p.Parent = parent
    return p
end

local function label(parent, text, size, color, font)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = tostring(text or "")
    l.TextColor3 = color or Color3.fromRGB(242, 242, 244)
    l.TextSize = size or 13
    l.Font = font or Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextYAlignment = Enum.TextYAlignment.Center
    l.Parent = parent
    return l
end

-- Executors differ in what GUI parents they allow. Never force CoreGui.
local function getGuiParent()
    local gethuiFn = rawget(getfenv and getfenv() or _G, "gethui")
    if typeof(gethuiFn) == "function" then
        local ok, hui = pcall(gethuiFn)
        if ok and hui then
            return hui
        end
    end

    local playerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        return playerGui
    end

    if LocalPlayer then
        local ok, result = pcall(function()
            return LocalPlayer:WaitForChild("PlayerGui", 15)
        end)
        if ok and result then
            return result
        end
    end

    return nil
end

local function protectGui(gui)
    local parent = getGuiParent()
    if not parent then
        error("MacOSKit: PlayerGui is not available yet")
    end

    local ok, err = pcall(function()
        gui.Parent = parent
    end)

    if not ok then
        error("MacOSKit: unable to parent ScreenGui: " .. tostring(err))
    end

    local synGlobal = rawget(getfenv and getfenv() or _G, "syn")
    if type(synGlobal) == "table" and type(synGlobal.protect_gui) == "function" then
        pcall(synGlobal.protect_gui, gui)
    end

    return gui
end

local function makeDraggable(handle, target)
    local dragging = false
    local dragStart
    local startPosition
    local dragInput

    handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        dragging = true
        dragStart = input.Position
        startPosition = target.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end)

    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging or input ~= dragInput then return end

        local delta = input.Position - dragStart
        target.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end)
end

local Window = {}
Window.__index = Window

function Window:SetTheme(name)
    local theme = Themes[name] or Themes.Violet
    self.ThemeName = Themes[name] and name or "Violet"
    self.Theme = theme

    if self.AccentGradient then
        self.AccentGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(27, 32, 40)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(15, 19, 25)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 10, 13)),
        })
    end

    for _, tab in pairs(self.Tabs) do
        if tab and tab._refresh then
            tab:_refresh()
        end
    end
end

function Window:Notify(title, message, duration)
    if not self.Gui or not self.Gui.Parent then return end

    local toast = Instance.new("Frame")
    toast.Name = "Notification"
    toast.AnchorPoint = Vector2.new(1, 1)
    toast.Position = UDim2.new(1, 340, 1, -18)
    toast.Size = UDim2.fromOffset(310, 72)
    toast.BackgroundColor3 = Color3.fromRGB(25, 25, 29)
    toast.BackgroundTransparency = 0.04
    toast.BorderSizePixel = 0
    toast.ZIndex = 100
    toast.Parent = self.Gui
    corner(toast, 11)
    addStroke(toast, Color3.fromRGB(255, 255, 255), 0.82, 1)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 3, 1, -16)
    bar.Position = UDim2.fromOffset(8, 8)
    bar.BackgroundColor3 = self.Theme.accent
    bar.BorderSizePixel = 0
    bar.ZIndex = 101
    bar.Parent = toast
    corner(bar, 2)

    local titleText = label(toast, title or "Notification", 13, Color3.fromRGB(245,245,247), Enum.Font.GothamBold)
    titleText.Position = UDim2.fromOffset(20, 8)
    titleText.Size = UDim2.new(1, -28, 0, 21)
    titleText.ZIndex = 101

    local messageText = label(toast, message or "", 11, Color3.fromRGB(175,175,181), Enum.Font.Gotham)
    messageText.Position = UDim2.fromOffset(20, 31)
    messageText.Size = UDim2.new(1, -28, 0, 32)
    messageText.TextWrapped = true
    messageText.ZIndex = 101

    tween(toast, 0.3, {Position = UDim2.new(1, -18, 1, -18)}, Enum.EasingStyle.Back)

    task.delay(duration or 3, function()
        if not toast.Parent then return end
        tween(toast, 0.2, {
            Position = UDim2.new(1, 340, 1, -18),
            BackgroundTransparency = 1
        })
        task.wait(0.22)
        if toast.Parent then toast:Destroy() end
    end)
end

function Window:Minimize()
    if self.Minimized then
        return self:Restore()
    end

    self.Minimized = true
    self.Body.Visible = false
    tween(self.Main, 0.2, {Size = UDim2.fromOffset(self.CurrentSize.X, 46)})
end

function Window:Restore()
    self.Minimized = false
    self.Body.Visible = true
    tween(self.Main, 0.2, {
        Size = UDim2.fromOffset(self.CurrentSize.X, self.CurrentSize.Y)
    })
end

function Window:Maximize()
    if self.Maximized then
        self.Maximized = false
        tween(self.Main, 0.2, {
            Position = self.RestorePosition,
            Size = UDim2.fromOffset(self.CurrentSize.X, self.CurrentSize.Y)
        })
        return
    end

    self.Maximized = true
    self.RestorePosition = self.Main.Position
    tween(self.Main, 0.2, {
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(0.94, 0, 0.90, 0)
    })
end

function Window:Destroy()
    if self.Gui then
        pcall(function()
            self.Gui:Destroy()
        end)
    end
    if MacOSKit.Window == self then
        MacOSKit.Window = nil
    end
end

local Tab = {}
Tab.__index = Tab

function Tab:_refresh()
    if not self.Nav or not self.Page or not self.Window then return end

    local selected = self.Window.ActiveTab == self
    local theme = self.Window.Theme

    self.Nav.BackgroundColor3 = theme.accent
    self.Nav.BackgroundTransparency = selected and 0.72 or 1
    if self.NavGradient then
        self.NavGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, theme.accent),
            ColorSequenceKeypoint.new(1, theme.accent2),
        })
        self.NavGradient.Transparency = selected
            and NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.02),
                NumberSequenceKeypoint.new(1, 0.52),
            })
            or NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(1, 1),
            })
    end
    self.Nav.TextColor3 = selected
        and Color3.fromRGB(248,248,250)
        or Color3.fromRGB(155,155,163)

    self.Page.Visible = selected
end

function Tab:Show()
    self.Window.ActiveTab = self
    for _, tab in pairs(self.Window.Tabs) do
        tab:_refresh()
    end
end

function Tab:AddLabel(text)
    local row = Instance.new("Frame")
    row.Name = "Label"
    row.Size = UDim2.new(1, 0, 0, 28)
    row.BackgroundTransparency = 1
    row.Parent = self.Content

    local l = label(row, text, 13, Color3.fromRGB(164,164,172), Enum.Font.Gotham)
    l.Size = UDim2.new(1, 0, 1, 0)
    l.TextWrapped = true
    return l
end

function Tab:AddButton(text, callback)
    local button = Instance.new("TextButton")
    button.Name = "Button"
    button.Size = UDim2.new(1, 0, 0, 36)
    button.BackgroundColor3 = Color3.fromRGB(32, 38, 46)
    button.BackgroundTransparency = 0.12
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Text = tostring(text or "Button")
    button.TextColor3 = Color3.fromRGB(242,242,244)
    button.TextSize = 12
    button.Font = Enum.Font.GothamSemibold
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.Parent = self.Content
    corner(button, 8)
    addPadding(button, 12, 12)

    local buttonGradient = Instance.new("UIGradient")
    buttonGradient.Rotation = 0
    buttonGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(38, 45, 55)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(25, 30, 38)),
    })
    buttonGradient.Parent = button
    button._MacOSGradient = buttonGradient

    local outline = addStroke(button, Color3.fromRGB(255,255,255), 0.90, 1)

    button.MouseEnter:Connect(function()
        tween(button, 0.12, {BackgroundTransparency = 0.02})
        tween(outline, 0.12, {Transparency = 0.76})
    end)

    button.MouseLeave:Connect(function()
        tween(button, 0.12, {BackgroundTransparency = 0.12})
        tween(outline, 0.12, {Transparency = 0.90})
    end)

    button.MouseButton1Click:Connect(function()
        if type(callback) ~= "function" then return end
        task.spawn(function()
            local ok, err = safeCall(callback)
            if not ok then
                self.Window:Notify("Callback error", tostring(err))
            end
        end)
    end)

    return button
end

function Tab:AddTextBox(labelText, callback)
    local holder = Instance.new("Frame")
    holder.Name = "TextBox"
    holder.Size = UDim2.new(1, 0, 0, 60)
    holder.BackgroundTransparency = 1
    holder.Parent = self.Content

    local l = label(holder, labelText, 11, Color3.fromRGB(155,155,163), Enum.Font.GothamSemibold)
    l.Size = UDim2.new(1, 0, 0, 18)

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 0, 34)
    box.Position = UDim2.fromOffset(0, 23)
    box.BackgroundColor3 = Color3.fromRGB(17, 21, 26)
    box.BackgroundTransparency = 0.08
    box.BorderSizePixel = 0
    box.Text = ""
    box.PlaceholderText = "Enter value..."
    box.PlaceholderColor3 = Color3.fromRGB(105,105,112)
    box.TextColor3 = Color3.fromRGB(242,242,244)
    box.TextSize = 12
    box.Font = Enum.Font.Gotham
    box.ClearTextOnFocus = false
    box.Parent = holder
    corner(box, 7)
    addStroke(box, Color3.fromRGB(255,255,255), 0.88, 1)
    addPadding(box, 10, 10)

    box.FocusLost:Connect(function()
        if type(callback) ~= "function" then return end
        task.spawn(function()
            local ok, err = safeCall(callback, box.Text)
            if not ok then
                self.Window:Notify("Input error", tostring(err))
            end
        end)
    end)

    return box
end

function Tab:AddToggle(text, default, callback)
    local row = Instance.new("Frame")
    row.Name = "Toggle"
    row.Size = UDim2.new(1, 0, 0, 38)
    row.BackgroundTransparency = 1
    row.Parent = self.Content

    local l = label(row, text, 12, Color3.fromRGB(218,218,222), Enum.Font.Gotham)
    l.Size = UDim2.new(1, -54, 1, 0)

    local switch = Instance.new("TextButton")
    switch.Size = UDim2.fromOffset(36, 21)
    switch.Position = UDim2.new(1, -36, 0.5, -10.5)
    switch.BackgroundColor3 = Color3.fromRGB(70,70,78)
    switch.BorderSizePixel = 0
    switch.Text = ""
    switch.AutoButtonColor = false
    switch.Parent = row
    corner(switch, 11)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(17, 17)
    knob.Position = UDim2.fromOffset(2, 2)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob.BorderSizePixel = 0
    knob.Parent = switch
    corner(knob, 9)

    local state = default == true

    local function setState(value, fire)
        state = value == true
        switch.BackgroundColor3 = state and self.Window.Theme.accent or Color3.fromRGB(70,70,78)
        tween(knob, 0.16, {
            Position = state and UDim2.fromOffset(17, 2) or UDim2.fromOffset(2, 2)
        }, Enum.EasingStyle.Back)
        if fire and type(callback) == "function" then
            local ok, err = safeCall(callback, state)
            if not ok then
                self.Window:Notify("Toggle error", tostring(err))
            end
        end
    end

    switch.MouseButton1Click:Connect(function()
        setState(not state, true)
    end)

    setState(state, false)

    return {
        Instance = switch,
        SetValue = function(_, value) setState(value, true) end,
        GetValue = function() return state end,
    }
end

function Tab:AddSwitch(text, callback)
    local control = self:AddToggle(text, false, callback)
    return {
        Instance = control.Instance,
        Set = function(_, value)
            control:SetValue(value)
        end,
        Get = function()
            return control:GetValue()
        end,
    }
end

function Tab:AddSection(text)
    local section = Instance.new("Frame")
    section.Name = "Section"
    section.Size = UDim2.new(1, 0, 0, 32)
    section.BackgroundTransparency = 1
    section.Parent = self.Content

    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 1)
    line.Position = UDim2.new(0, 0, 1, -1)
    line.BackgroundColor3 = Color3.fromRGB(255,255,255)
    line.BackgroundTransparency = 0.91
    line.BorderSizePixel = 0
    line.Parent = section

    local l = label(section, text, 11, self.Window.Theme.accent, Enum.Font.GothamBold)
    l.Size = UDim2.new(1, 0, 1, 0)
    return l
end

function Window:AddTab(name)
    local tabName = tostring(name or "Tab")
    local tab = setmetatable({Window = self, Name = tabName}, Tab)

    local nav = Instance.new("TextButton")
    nav.Name = tabName
    nav.Size = UDim2.new(1, 0, 0, 35)
    nav.BackgroundColor3 = self.Theme.accent
    nav.BackgroundTransparency = 1
    nav.BorderSizePixel = 0
    nav.Text = tabName
    nav.TextColor3 = Color3.fromRGB(155,155,163)
    nav.TextSize = 12
    nav.Font = Enum.Font.GothamMedium
    nav.TextXAlignment = Enum.TextXAlignment.Left
    nav.AutoButtonColor = false
    nav.Parent = self.Sidebar
    corner(nav, 7)
    addPadding(nav, 12, 8)

    local navGradient = Instance.new("UIGradient")
    navGradient.Rotation = 0
    navGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, self.Theme.accent),
        ColorSequenceKeypoint.new(1, self.Theme.accent2),
    })
    navGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.18),
        NumberSequenceKeypoint.new(1, 0.55),
    })
    navGradient.Parent = nav
    tab.NavGradient = navGradient

    local page = Instance.new("ScrollingFrame")
    page.Name = tabName .. "Page"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.ScrollBarImageTransparency = 0.15
    page.ScrollBarImageColor3 = Color3.fromRGB(95,95,105)
    page.Active = true
    page.CanvasSize = UDim2.fromOffset(0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.ScrollingDirection = Enum.ScrollingDirection.Y
    page.Visible = false
    page.Parent = self.Pages
    addPadding(page, 2, 4, 2, 18)

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    tab.Nav = nav
    tab.Page = page
    tab.Content = page

    nav.MouseButton1Click:Connect(function()
        tab:Show()
    end)

    self.Tabs[tabName] = tab

    if not self.ActiveTab then
        tab:Show()
    else
        tab:_refresh()
    end

    return tab
end

function MacOSKit:AddWindow(title, config)
    config = config or {}

    if self.Window and self.Window.Gui then
        self.Window:Destroy()
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "MacOSKit"
    gui.Enabled = true
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999
    gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets

    -- Remove stale copies left behind by a previous execution.
    local parent = getGuiParent()
    if parent then
        local old = parent:FindFirstChild("MacOSKit")
        if old then
            pcall(function()
                old:Destroy()
            end)
        end
    end

    protectGui(gui)

    -- Respect the requested minimum size, but never create a window larger
    -- than the current viewport. Oversized fixed windows can look "invisible"
    -- because their center is outside the usable area on smaller screens.
    local requestedWidth = math.max(
        tonumber(config.min_size and config.min_size.X) or 900,
        720
    )
    local requestedHeight = math.max(
        tonumber(config.min_size and config.min_size.Y) or 640,
        500
    )

    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
    local width = math.min(requestedWidth, math.max(720, viewport.X * 0.94))
    local height = math.min(requestedHeight, math.max(500, viewport.Y * 0.88))

    width = math.floor(width)
    height = math.floor(height)

    local root = Instance.new("Frame")
    root.Name = "Window"
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Position = UDim2.fromScale(0.5, 0.5)
    root.Size = UDim2.fromOffset(width, height)
    root.BackgroundColor3 = Color3.fromRGB(13, 16, 21)
    root.BackgroundTransparency = 0.08
    root.BorderSizePixel = 0
    root.Visible = true
    root.Active = true
    root.ClipsDescendants = true
    root.ZIndex = 1
    root.Parent = gui
    corner(root, 14)
    addStroke(root, Color3.fromRGB(72, 80, 94), 0.42, 1)

    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 145
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(27, 32, 40)),
        ColorSequenceKeypoint.new(0.50, Color3.fromRGB(15, 19, 25)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 10, 13)),
    })
    gradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.05),
        NumberSequenceKeypoint.new(0.55, 0.02),
        NumberSequenceKeypoint.new(1, 0.00),
    })
    gradient.Parent = root

    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1,0,0,48)
    titleBar.BackgroundColor3 = Color3.fromRGB(19, 23, 29)
    titleBar.BackgroundTransparency = 0.08
    titleBar.BorderSizePixel = 0
    titleBar.ZIndex = 5
    titleBar.Parent = root

    local titleGradient = Instance.new("UIGradient")
    titleGradient.Rotation = 90
    titleGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(31, 37, 46)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 20, 25)),
    })
    titleGradient.Parent = titleBar

    makeDraggable(titleBar, root)

    local dots = {
        {Color3.fromRGB(255,95,87), "Close"},
        {Color3.fromRGB(245,166,35), "Minimize"},
        {Color3.fromRGB(51,209,122), "Maximize"},
    }

    local controls = {}
    for i, info in ipairs(dots) do
        local dot = Instance.new("TextButton")
        dot.Name = info[2]
        dot.Size = UDim2.fromOffset(13,13)
        dot.Position = UDim2.fromOffset(14 + (i - 1) * 20, 17)
        dot.BackgroundColor3 = info[1]
        dot.BorderSizePixel = 0
        dot.Text = ""
        dot.AutoButtonColor = false
        dot.ZIndex = 7
        dot.Parent = titleBar
        corner(dot, 7)

        dot.MouseEnter:Connect(function()
            tween(dot, 0.1, {Size = UDim2.fromOffset(15,15)})
        end)
        dot.MouseLeave:Connect(function()
            tween(dot, 0.1, {Size = UDim2.fromOffset(13,13)})
        end)

        controls[i] = dot
    end

    local titleLabel = label(titleBar, title or "MacOSKit", 13, Color3.fromRGB(242,242,244), Enum.Font.GothamBold)
    titleLabel.Position = UDim2.fromOffset(88, 4)
    titleLabel.Size = UDim2.new(0.55, -88, 0, 20)
    titleLabel.ZIndex = 6

    local subLabel = label(titleBar, "macOS-style UI", 10, Color3.fromRGB(112,112,120), Enum.Font.Gotham)
    subLabel.Position = UDim2.fromOffset(88, 23)
    subLabel.Size = UDim2.new(0.55, -88, 0, 15)
    subLabel.ZIndex = 6

    local settings = Instance.new("TextButton")
    settings.Name = "Settings"
    settings.Size = UDim2.fromOffset(28,28)
    settings.Position = UDim2.new(1,-40,0,9)
    settings.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    settings.BackgroundTransparency = 0.08
    settings.BorderSizePixel = 0
    settings.Text = "•"
    settings.TextColor3 = Color3.fromRGB(175,175,182)
    settings.TextSize = 18
    settings.Font = Enum.Font.GothamBold
    settings.AutoButtonColor = false
    settings.ZIndex = 7
    settings.Parent = titleBar
    corner(settings, 7)

    local body = Instance.new("Frame")
    body.Name = "Body"
    body.Size = UDim2.new(1,0,1,-48)
    body.Position = UDim2.fromOffset(0,48)
    body.BackgroundTransparency = 1
    body.BorderSizePixel = 0
    body.ZIndex = 2
    body.Parent = root

    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, 224, 1, 0)
    sidebar.BackgroundColor3 = Color3.fromRGB(12, 15, 19)
    sidebar.BackgroundTransparency = 0.10
    sidebar.BorderSizePixel = 0
    sidebar.ZIndex = 3
    sidebar.Parent = body

    local search = Instance.new("TextBox")
    search.Name = "Search"
    search.Position = UDim2.fromOffset(9,11)
    search.Size = UDim2.new(1,-18,0,31)
    search.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
    search.BackgroundTransparency = 0.04
    search.BorderSizePixel = 0
    search.Text = ""
    search.PlaceholderText = "Search tabs..."
    search.PlaceholderColor3 = Color3.fromRGB(100,100,108)
    search.TextColor3 = Color3.fromRGB(235,235,239)
    search.TextSize = 11
    search.Font = Enum.Font.Gotham
    search.ClearTextOnFocus = false
    search.ZIndex = 5
    search.Parent = sidebar
    corner(search, 7)
    addStroke(search, Color3.fromRGB(255,255,255), 0.90, 1)
    addPadding(search, 10, 8)

    local sidebarList = Instance.new("ScrollingFrame")
    sidebarList.Name = "TabList"
    sidebarList.Position = UDim2.fromOffset(9,49)
    sidebarList.Size = UDim2.new(1,-18,1,-58)
    sidebarList.BackgroundTransparency = 1
    sidebarList.BorderSizePixel = 0
    sidebarList.ScrollBarThickness = 3
    sidebarList.ScrollBarImageTransparency = 0.35
    sidebarList.Active = true
    sidebarList.CanvasSize = UDim2.fromOffset(0,0)
    sidebarList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sidebarList.ZIndex = 4
    sidebarList.Parent = sidebar

    local sideLayout = Instance.new("UIListLayout")
    sideLayout.Padding = UDim.new(0,4)
    sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sideLayout.Parent = sidebarList

    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(0,1,1,0)
    divider.Position = UDim2.fromOffset(224,0)
    divider.BackgroundColor3 = Color3.fromRGB(255,255,255)
    divider.BackgroundTransparency = 0.91
    divider.BorderSizePixel = 0
    divider.ZIndex = 4
    divider.Parent = body

    local pages = Instance.new("Frame")
    pages.Name = "Pages"
    pages.Position = UDim2.fromOffset(225,0)
    pages.Size = UDim2.new(1,-225,1,0)
    pages.BackgroundColor3 = Color3.fromRGB(15, 18, 23)
    pages.BackgroundTransparency = 0.10
    pages.BorderSizePixel = 0
    pages.ZIndex = 3
    pages.Parent = body
    addPadding(pages, 24, 28, 24, 32)

    local self = setmetatable({
        Gui = gui,
        Main = root,
        Body = body,
        Sidebar = sidebarList,
        Pages = pages,
        Tabs = {},
        ActiveTab = nil,
        Config = config,
        CurrentSize = Vector2.new(width, height),
        RestorePosition = root.Position,
        Minimized = false,
        Maximized = false,
        ThemeName = config.theme or "Violet",
        Theme = Themes[config.theme] or Themes.Violet,
        AccentGradient = gradient,
        ThemeButtons = {},
    }, Window)

    self.Window = self

    controls[1].MouseButton1Click:Connect(function()
        if not root.Parent then return end
        tween(root, 0.18, {BackgroundTransparency = 1, Size = UDim2.fromOffset(width * 0.96, height * 0.96)})
        task.delay(0.2, function()
            if gui.Parent then gui:Destroy() end
            if MacOSKit.Window == self then MacOSKit.Window = nil end
        end)
    end)

    controls[2].MouseButton1Click:Connect(function()
        self:Minimize()
    end)

    controls[3].MouseButton1Click:Connect(function()
        self:Maximize()
    end)

    settings.MouseButton1Click:Connect(function()
        self:Notify("MacOSKit", "Use SetTheme(name) to change the accent theme.")
    end)

    search:GetPropertyChangedSignal("Text"):Connect(function()
        local query = search.Text:lower()
        for _, tab in pairs(self.Tabs) do
            local matches = query == "" or tab.Name:lower():find(query, 1, true) ~= nil
            tab.Nav.Visible = matches
        end
    end)

    gui.Destroying:Connect(function()
        if MacOSKit.Window == self then
            MacOSKit.Window = nil
        end
    end)

    self:SetTheme(self.ThemeName)
    MacOSKit.Window = self

    -- No startup fade-to-transparent. The window is rendered immediately.
    gui.Enabled = true
    root.Visible = true

    return self
end

function MacOSKit:CreateWindow(title, config)
    return self:AddWindow(title, config)
end

function MacOSKit:Destroy()
    if self.Window then
        self.Window:Destroy()
    end
end

return MacOSKit
