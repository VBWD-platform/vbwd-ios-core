# Theming Guide

VBWDCore includes a flexible theme system with three built-in themes and support for custom themes via plugins.

## Built-in Themes

| Theme | ID | Color Scheme | Description |
|-------|----|-------------|-------------|
| Classic | `"classic"` | System-adaptive | Follows system light/dark mode |
| Dark Blue | `"dark-blue"` | Always dark | Navy (#0D1B2A) with blue (#3498DB) accent |
| Dark Green | `"dark-green"` | Always dark | Dark (#1A1A2E) with emerald (#2ECC71) accent |

Users switch themes in Settings. The selection is persisted to `UserDefaults`.

## Using Themes in Views

Access the current theme via the environment:

```swift
struct MyView: View {
    @Environment(\.appTheme) var theme

    var body: some View {
        VStack {
            Text("Title")
                .foregroundColor(theme.textPrimary)
            Text("Subtitle")
                .foregroundColor(theme.textSecondary)
        }
        .background(theme.background)
    }
}
```

## Theme Properties

Every theme conforms to the `AppTheme` protocol and provides these colors:

| Property | Purpose |
|----------|---------|
| `accent` | Primary action color (buttons, links) |
| `background` | Main background |
| `cardBackground` | Card/surface background |
| `textPrimary` | Primary text |
| `textSecondary` | Secondary/caption text |
| `destructive` | Destructive actions (delete, logout) |
| `success` | Success indicators |
| `separator` | Divider lines |
| `menuBackground` | Side menu background |
| `avatarBackground` | User avatar circle |
| `preferredColorScheme` | Force `.light`/`.dark`, or `nil` for system |

## Creating a Custom Theme

### 1. Define the Theme

```swift
import SwiftUI
import VBWDCore

struct OceanTheme: AppTheme {
    let id = "ocean"
    let displayName = "Ocean"
    let accent = Color(red: 0.0, green: 0.6, blue: 0.8)
    let background = Color(red: 0.05, green: 0.1, blue: 0.15)
    let cardBackground = Color(red: 0.08, green: 0.15, blue: 0.22)
    let textPrimary = Color.white
    let textSecondary = Color(white: 0.65)
    let destructive = Color(red: 0.9, green: 0.3, blue: 0.3)
    let success = Color(red: 0.2, green: 0.8, blue: 0.5)
    let separator = Color(white: 0.2)
    let menuBackground = Color(red: 0.03, green: 0.06, blue: 0.1)
    let avatarBackground = Color(red: 0.0, green: 0.5, blue: 0.7)
    let preferredColorScheme: ColorScheme? = .dark
}
```

### 2. Register in a Plugin

Register the theme during plugin installation by accessing the `ThemeRegistry` through `SDKContainer`. Custom themes added via `ThemeRegistry.register()` appear automatically in the Settings theme picker.

```swift
// In your plugin's install() method, or in the host app setup:
themeRegistry.register(OceanTheme())
```

## Architecture

```
ThemeRegistry (stores all themes)
       │
ThemeManager (@MainActor, persists selection)
       │
Environment(\.appTheme) → used by all views
```

- `ThemeRegistry` holds all registered themes (3 built-in + any custom)
- `ThemeManager` reads the persisted theme ID from `UserDefaults` at launch
- `ThemeManager.selectTheme(_:)` updates the current theme and persists
- The current theme flows through `@Environment(\.appTheme)` to all views
- `preferredColorScheme` is applied globally via `.preferredColorScheme()` modifier
