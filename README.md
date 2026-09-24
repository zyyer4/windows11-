# Empire MacOSKit

A macOS-inspired Roblox UI library for the Empire script.

The library replaces the old Elerium UI dependency with a native Roblox implementation based on the supplied macOS UI kit visual language: translucent glass panels, traffic-light window controls, sidebar navigation, rounded cards, accent themes, animated interactions, search and notifications.

## Load

```lua
local MacOSKit = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/zyyer4/windows11-/main/macos.lua",
    true
))()

local Window = MacOSKit:AddWindow("Empire", {
    min_size = Vector2.new(900, 700),
    can_resize = true,
    theme = "Violet"
})
```

## Tabs

```lua
local Tab = Window:AddTab("Farming")
Tab:Show()
```

## Controls

```lua
Tab:AddLabel("Status: Ready")

Tab:AddButton("Start", function()
    print("started")
end)

Tab:AddTextBox("Username", function(value)
    print(value)
end)

local toggle = Tab:AddSwitch("Auto Farm", function(enabled)
    print(enabled)
end)

toggle:Set(true)
print(toggle:Get())
```

## Themes

Supported themes:

- Violet
- Midnight
- Emerald
- Crimson
- Mono

```lua
Window:SetTheme("Midnight")
```

## Notifications

```lua
Window:Notify("Empire", "Feature enabled.", 3)
```

## Window controls

The title bar provides macOS-style close, minimize and maximize controls. The window is draggable from the title bar.

## Existing Empire script

The `windows` script now loads `macos.lua` instead of the external Elerium library while preserving the existing `AddWindow`, `AddTab`, `AddLabel`, `AddButton`, `AddTextBox` and `AddSwitch` calls used by the script.

This means the feature logic stays in the Empire script while the UI layer is isolated in MacOSKit.
