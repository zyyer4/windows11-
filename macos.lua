--[[
    MacOSKit
    macOS-inspired Roblox UI library for the Empire project.
    API-compatible with the existing Elerium-style calls used by windows:
      local Window = MacOSKit:AddWindow("Title", config)
      local Tab = Window:AddTab("Player")
      Tab:AddLabel("Hello")
      Tab:AddButton("Run", callback)
      Tab:AddTextBox("Name", callback)
      Tab:Show()
      Window:Notify("Title", "Message")

    Built from the supplied macos-ui-kit.html visual language:
    glass window, traffic-light controls, sidebar navigation, cards,
    collapsible sections, accent themes, compact mode and motion.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local MacOSKit = {}
MacOSKit.__index = MacOSKit
MacOSKit.Version = "1.0.0"

local Themes = {
    Violet = {
        accent = Color3.fromRGB(122, 90, 230),
        accent2 = Color3.fromRGB(58, 143, 255),
        blob = Color3.fromRGB(106, 79, 216),
    },
    Midnight = {
        accent = Color3.fromRGB(47, 95, 224),
        accent2 = Color3.fromRGB(31, 176, 224),
        blob = Color3.fromRGB(47, 95, 224),
    },
    Emerald = {
        accent = Color3.fromRGB(34, 197, 138),
        accent2 = Color3.fromRGB(31, 174, 106),
        blob = Color3.fromRGB(34, 197, 138),
    },
    Crimson = {
        accent = Color3.fromRGB(255, 95, 87),
        accent2 = Color3.fromRGB(224, 57, 47),
        blob = Color3.fromRGB(255, 95, 87),
    },
    Mono = {
        accent = Color3.fromRGB(154, 154, 160),
        accent2 = Color3.fromRGB(95, 95, 102),
        blob = Color3.fromRGB(95, 95, 102),
    },
}

local function tween(instance, info, props)
    local t = TweenService:Create(instance, info, props)
    t:Play()
    return t
end

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
    return c
end

local function stroke(parent, color, transparency, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Transparency = transparency or 0
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function padding(parent, l, r, t, b)
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0, l or 0)
    p.PaddingRight = UDim.new(0, r or l or 0)
    p.PaddingTop = UDim.new(0, t or l or 0)
    p.PaddingBottom = UDim.new(0, b or t or l or 0)
    p.Parent = parent
    return p
end

local function makeText(parent, text, size, color, font)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Text = tostring(text or "")
    label.TextColor3 = color or Color3.fromRGB(242, 242, 244)
    label.TextSize = size or 13
    label.Font = font or Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Parent = parent
    return label
end

local function protectGui(gui)
    pcall(function()
        if gethui then
            gui.Parent = gethui()
            return
        end
    end)

    pcall(function()
        if syn and syn.protect_gui then
            syn.protect_gui(gui)
        end
    end)

    gui.Parent = CoreGui
end

local function makeDraggable(handle, target)
    local dragging = false
    local dragStart
    local startPos
    local connection

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position

            if connection then connection:Disconnect() end
            connection = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if connection then
                        connection:Disconnect()
                        connection = nil
                    end
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local delta = input.Position - dragStart
        target.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end)
end

local Window = {}
Window.__index = Window

function Window:_setVisible(value)
    self.Gui.Enabled = value
end

function Window:SetTheme(name)
    local theme = Themes[name] or Themes.Violet
    self.ThemeName = name
    self.Theme = theme

    self.AccentGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, theme.accent),
        ColorSequenceKeypoint.new(1, theme.accent2),
    })

    for _, tab in pairs(self.Tabs) do
        tab:_refresh()
    end

    for _, button in ipairs(self.ThemeButtons) do
        button.BackgroundColor3 = theme.accent
    end
end

function Window:Notify(title, message, duration)
    local toast = Instance.new("Frame")
    toast.Name = "Toast"
    toast.Size = UDim2.fromOffset(290, 70)
    toast.Position = UDim2.new(1, 20, 1, -90)
    toast.AnchorPoint = Vector2.new(1, 1)
    toast.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
    toast.BackgroundTransparency = 0.08
    toast.ZIndex = 100
    toast.Parent = self.Gui
    corner(toast, 10)
    stroke(toast, Color3.fromRGB(255,255,255), 0.82, 1)

    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(0, 3, 1, -16)
    accent.Position = UDim2.fromOffset(8, 8)
    accent.BackgroundColor3 = self.Theme.accent
    accent.ZIndex = 101
    accent.Parent = toast
    corner(accent, 2)

    local titleLabel = makeText(toast, title or "Notification", 13, Color3.fromRGB(245,245,247), Enum.Font.GothamBold)
    titleLabel.Position = UDim2.fromOffset(20, 9)
    titleLabel.Size = UDim2.new(1, -28, 0, 20)
    titleLabel.ZIndex = 101

    local messageLabel = makeText(toast, message or "", 11, Color3.fromRGB(152,152,158), Enum.Font.Gotham)
    messageLabel.Position = UDim2.fromOffset(20, 31)
    messageLabel.Size = UDim2.new(1, -28, 0, 28)
    messageLabel.TextWrapped = true
    messageLabel.ZIndex = 101

    tween(toast, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(1, -18, 1, -90)
    })

    task.delay(duration or 3, function()
        if not toast.Parent then return end
        tween(toast, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(1, 20, 1, -90),
            BackgroundTransparency = 1
        })
        task.wait(0.28)
        toast:Destroy()
    end)
end

function Window:Minimize()
    if self.Minimized then return end
    self.Minimized = true
    self.Body.Visible = false
    tween(self.Main, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(self.Config.min_size.X, 46)
    })
end

function Window:Restore()
    self.Minimized = false
    self.Body.Visible = true
    tween(self.Main, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(self.CurrentSize.X, self.CurrentSize.Y)
    })
end

function Window:Maximize()
    if self.Maximized then
        self.Maximized = false
        tween(self.Main, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = self.RestorePosition,
            Size = UDim2.fromOffset(self.CurrentSize.X, self.CurrentSize.Y)
        })
    else
        self.Maximized = true
        self.RestorePosition = self.Main.Position
        tween(self.Main, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(0.94, 0, 0.90, 0)
        })
    end
end

function Window:Destroy()
    if self.Gui then
        self.Gui:Destroy()
    end
end

local Tab = {}
Tab.__index = Tab

function Tab:_refresh()
    local selected = self == self.Window.ActiveTab
    local theme = self.Window.Theme

    self.Nav.BackgroundTransparency = selected and 0.70 or 1
    self.Nav.BackgroundColor3 = theme.accent
    self.Nav.TextColor3 = selected
        and Color3.fromRGB(245,245,247)
        or Color3.fromRGB(152,152,158)

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

    local label = makeText(row, text, 13, Color3.fromRGB(152,152,158), Enum.Font.Gotham)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.TextWrapped = true

    return label
end

function Tab:AddButton(text, callback)
    local button = Instance.new("TextButton")
    button.Name = "Button"
    button.Size = UDim2.new(1, 0, 0, 34)
    button.BackgroundColor3 = Color3.fromRGB(255,255,255)
    button.BackgroundTransparency = 0.93
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Text = tostring(text or "Button")
    button.TextColor3 = Color3.fromRGB(242,242,244)
    button.TextSize = 12
    button.Font = Enum.Font.GothamSemibold
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.Parent = self.Content
    corner(button, 8)
    local s = stroke(button, Color3.fromRGB(255,255,255), 0.90, 1)
    padding(button, 12, 12)

    button.MouseEnter:Connect(function()
        tween(button, TweenInfo.new(0.15), {
            BackgroundTransparency = 0.87
        })
        tween(s, TweenInfo.new(0.15), {
            Transparency = 0.78
        })
    end)

    button.MouseLeave:Connect(function()
        tween(button, TweenInfo.new(0.15), {
            BackgroundTransparency = 0.93
        })
        tween(s, TweenInfo.new(0.15), {
            Transparency = 0.90
        })
    end)

    button.MouseButton1Click:Connect(function()
        if callback then
            task.spawn(function()
                local ok, err = pcall(callback)
                if not ok then
                    self.Window:Notify("Callback error", tostring(err))
                end
            end)
        end
    end)

    return button
end

function Tab:AddTextBox(labelText, callback)
    local holder = Instance.new("Frame")
    holder.Name = "TextBox"
    holder.Size = UDim2.new(1, 0, 0, 58)
    holder.BackgroundTransparency = 1
    holder.Parent = self.Content

    local label = makeText(holder, labelText, 11, Color3.fromRGB(152,152,158), Enum.Font.GothamSemibold)
    label.Size = UDim2.new(1, 0, 0, 18)

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 0, 32)
    box.Position = UDim2.fromOffset(0, 22)
    box.BackgroundColor3 = Color3.fromRGB(255,255,255)
    box.BackgroundTransparency = 0.94
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
    stroke(box, Color3.fromRGB(255,255,255), 0.88, 1)
    padding(box, 10, 10)

    box.FocusLost:Connect(function()
        if callback then
            task.spawn(function()
                local ok, err = pcall(callback, box.Text)
                if not ok then
                    self.Window:Notify("Input error", tostring(err))
                end
            end)
        end
    end)

    return box
end

function Tab:AddToggle(text, default, callback)
    local row = Instance.new("Frame")
    row.Name = "Toggle"
    row.Size = UDim2.new(1, 0, 0, 38)
    row.BackgroundTransparency = 1
    row.Parent = self.Content

    local label = makeText(row, text, 12, Color3.fromRGB(218,218,222), Enum.Font.Gotham)
    label.Size = UDim2.new(1, -54, 1, 0)

    local switch = Instance.new("TextButton")
    switch.Size = UDim2.fromOffset(34, 20)
    switch.Position = UDim2.new(1, -34, 0.5, -10)
    switch.BackgroundColor3 = Color3.fromRGB(75,75,82)
    switch.Text = ""
    switch.AutoButtonColor = false
    switch.Parent = row
    corner(switch, 10)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(16, 16)
    knob.Position = UDim2.fromOffset(2, 2)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob.Parent = switch
    corner(knob, 8)

    local state = default == true

    local function setState(value, fire)
        state = value == true
        switch.BackgroundColor3 = state and self.Window.Theme.accent or Color3.fromRGB(75,75,82)
        tween(knob, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = state and UDim2.fromOffset(16,2) or UDim2.fromOffset(2,2)
        })
        if fire and callback then callback(state) end
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
    line.BackgroundTransparency = 0.92
    line.Parent = section

    local label = makeText(section, text, 11, self.Window.Theme.accent, Enum.Font.GothamBold)
    label.Size = UDim2.new(1, 0, 1, 0)

    return label
end

function Window:AddTab(name)
    local tab = setmetatable({
        Window = self,
        Name = name,
    }, Tab)

    local nav = Instance.new("TextButton")
    nav.Name = name
    nav.Size = UDim2.new(1, 0, 0, 34)
    nav.BackgroundTransparency = 1
    nav.Text = tostring(name)
    nav.TextColor3 = Color3.fromRGB(152,152,158)
    nav.TextSize = 12
    nav.Font = Enum.Font.GothamMedium
    nav.TextXAlignment = Enum.TextXAlignment.Left
    nav.AutoButtonColor = false
    nav.Parent = self.Sidebar
    corner(nav, 7)
    padding(nav, 12, 8)

    local page = Instance.new("ScrollingFrame")
    page.Name = name .. "Page"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 5
    page.ScrollBarImageColor3 = Color3.fromRGB(90,90,98)
    page.CanvasSize = UDim2.fromOffset(0,0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = self.Pages
    padding(page, 2, 12, 2, 18)

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

    self.Tabs[name] = tab

    if not self.ActiveTab then
        tab:Show()
    else
        tab:_refresh()
    end

    return tab
end

function MacOSKit:AddWindow(title, config)
    config = config or {}

    local existing = self.Window
    if existing and existing.Gui then
        existing:Destroy()
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "MacOSKit"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    protectGui(gui)

    local root = Instance.new("Frame")
    root.Name = "Window"
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Position = UDim2.fromScale(0.5, 0.5)
    root.Size = UDim2.fromOffset(
        math.max((config.min_size and config.min_size.X) or 900, 720),
        math.max((config.min_size and config.min_size.Y) or 640, 500)
    )
    root.BackgroundColor3 = Color3.fromRGB(18,18,20)
    root.BackgroundTransparency = 0.20
    root.BorderSizePixel = 0
    root.ClipsDescendants = true
    root.Parent = gui
    corner(root, 14)
    stroke(root, Color3.fromRGB(255,255,255), 0.86, 1)

    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 145
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Themes.Violet.accent),
        ColorSequenceKeypoint.new(0.55, Themes.Violet.accent2),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(18,18,20)),
    })
    gradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.80),
        NumberSequenceKeypoint.new(0.55, 0.91),
        NumberSequenceKeypoint.new(1, 0.98),
    })
    gradient.Parent = root

    local topHighlight = Instance.new("Frame")
    topHighlight.Size = UDim2.new(1, 0, 0, 46)
    topHighlight.BackgroundColor3 = Color3.fromRGB(255,255,255)
    topHighlight.BackgroundTransparency = 0.96
    topHighlight.BorderSizePixel = 0
    topHighlight.Parent = root

    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1,0,0,46)
    titleBar.BackgroundTransparency = 1
    titleBar.Parent = root

    makeDraggable(titleBar, root)

    local dots = {
        {Color3.fromRGB(255,95,87), "Close"},
        {Color3.fromRGB(245,166,35), "Minimize"},
        {Color3.fromRGB(51,209,122), "Maximize"},
    }

    local controls = {}
    for i, item in ipairs(dots) do
        local dot = Instance.new("TextButton")
        dot.Size = UDim2.fromOffset(12,12)
        dot.Position = UDim2.fromOffset(14 + (i-1)*20, 17)
        dot.BackgroundColor3 = item[1]
        dot.Text = ""
        dot.AutoButtonColor = false
        dot.Parent = titleBar
        corner(dot, 6)
        controls[i] = dot

        dot.MouseEnter:Connect(function()
            tween(dot, TweenInfo.new(0.12), {Size = UDim2.fromOffset(14,14)})
        end)
        dot.MouseLeave:Connect(function()
            tween(dot, TweenInfo.new(0.12), {Size = UDim2.fromOffset(12,12)})
        end)
    end

    local titleLabel = makeText(titleBar, title or "MacOSKit", 13, Color3.fromRGB(242,242,244), Enum.Font.GothamBold)
    titleLabel.Position = UDim2.fromOffset(88, 5)
    titleLabel.Size = UDim2.new(0.5, -88, 0, 19)

    local subLabel = makeText(titleBar, "macOS-style UI", 10, Color3.fromRGB(99,99,104), Enum.Font.Gotham)
    subLabel.Position = UDim2.fromOffset(88, 23)
    subLabel.Size = UDim2.new(0.5, -88, 0, 15)

    local settings = Instance.new("TextButton")
    settings.Size = UDim2.fromOffset(27,27)
    settings.Position = UDim2.new(1,-40,0,9)
    settings.BackgroundColor3 = Color3.fromRGB(255,255,255)
    settings.BackgroundTransparency = 0.95
    settings.Text = "⚙"
    settings.TextColor3 = Color3.fromRGB(170,170,176)
    settings.TextSize = 15
    settings.Font = Enum.Font.Gotham
    settings.AutoButtonColor = false
    settings.Parent = titleBar
    corner(settings, 7)

    local body = Instance.new("Frame")
    body.Name = "Body"
    body.Size = UDim2.new(1,0,1,-46)
    body.Position = UDim2.fromOffset(0,46)
    body.BackgroundTransparency = 1
    body.Parent = root

    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.fromOffset(210,1)
    sidebar.Position = UDim2.fromOffset(0,0)
    sidebar.BackgroundColor3 = Color3.fromRGB(10,10,12)
    sidebar.BackgroundTransparency = 0.38
    sidebar.BorderSizePixel = 0
    sidebar.Parent = body
    padding(sidebar, 8, 8, 12, 12)

    local search = Instance.new("TextBox")
    search.Size = UDim2.new(1,0,0,30)
    search.BackgroundColor3 = Color3.fromRGB(255,255,255)
    search.BackgroundTransparency = 0.95
    search.PlaceholderText = "Search"
    search.PlaceholderColor3 = Color3.fromRGB(99,99,104)
    search.TextColor3 = Color3.fromRGB(235,235,239)
    search.TextSize = 11
    search.Font = Enum.Font.Gotham
    search.ClearTextOnFocus = false
    search.Text = ""
    search.Parent = sidebar
    corner(search, 7)
    padding(search, 10, 8)
    stroke(search, Color3.fromRGB(255,255,255), 0.91, 1)

    local sidebarList = Instance.new("Frame")
    sidebarList.Size = UDim2.new(1,0,1,-38)
    sidebarList.Position = UDim2.fromOffset(0,38)
    sidebarList.BackgroundTransparency = 1
    sidebarList.Parent = sidebar

    local sideLayout = Instance.new("UIListLayout")
    sideLayout.Padding = UDim.new(0,4)
    sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sideLayout.Parent = sidebarList

    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(0,1,1,0)
    divider.Position = UDim2.fromOffset(210,0)
    divider.BackgroundColor3 = Color3.fromRGB(255,255,255)
    divider.BackgroundTransparency = 0.93
    divider.Parent = body

    local pages = Instance.new("Frame")
    pages.Name = "Pages"
    pages.Size = UDim2.new(1,-235,1,0)
    pages.Position = UDim2.fromOffset(225,0)
    pages.BackgroundTransparency = 1
    pages.Parent = body

    padding(pages, 18, 18, 18, 18)

    local self = setmetatable({
        Gui = gui,
        Main = root,
        Body = body,
        Sidebar = sidebarList,
        Pages = pages,
        Tabs = {},
        ActiveTab = nil,
        Config = config,
        CurrentSize = Vector2.new(root.Size.X.Offset, root.Size.Y.Offset),
        RestorePosition = root.Position,
        Minimized = false,
        Maximized = false,
        ThemeName = "Violet",
        Theme = Themes.Violet,
        AccentGradient = gradient,
        ThemeButtons = {},
    }, Window)

    self.Window = self

    controls[1].MouseButton1Click:Connect(function()
        tween(root, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.fromOffset(self.CurrentSize.X * 0.92, self.CurrentSize.Y * 0.92),
            BackgroundTransparency = 1,
        })
        task.delay(0.23, function()
            if gui.Parent then gui:Destroy() end
        end)
    end)

    controls[2].MouseButton1Click:Connect(function()
        if self.Minimized then self:Restore() else self:Minimize() end
    end)

    controls[3].MouseButton1Click:Connect(function()
        self:Maximize()
    end)

    settings.MouseButton1Click:Connect(function()
        self:Notify("MacOSKit", "Theme and UI controls are available through the library API.")
    end)

    search:GetPropertyChangedSignal("Text"):Connect(function()
        local q = search.Text:lower()
        for _, tab in pairs(self.Tabs) do
            tab.Nav.Visible = q == "" or tab.Name:lower():find(q, 1, true) ~= nil
        end
    end)

    self.Gui.Destroying:Connect(function()
        self.Window = nil
    end)

    self:SetTheme(config.theme or "Violet")
    self.Window = self
    MacOSKit.Window = self

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
