# Contributing to BuffReminders

## Development Environment Setup

You need three tools to run `make`:

| Tool | Purpose |
|------|---------|
| [luacheck](https://github.com/mpeterv/luacheck) | Linter |
| [StyLua](https://github.com/JohnnyMorganz/StyLua) | Formatter |
| [lua-language-server](https://github.com/LuaLS/lua-language-server) | Type checker |

```bash
make          # Run all three: typecheck, lint, format
make check    # Same but format is check-only (no writes)
```

Run `make` before committing.

## Commit Messages

This project uses [Conventional Commits](https://www.conventionalcommits.org/) with [gitmoji](https://gitmoji.dev/). A body and footer are usually not needed, but add them if the change warrants extra context.

```
type: <gitmoji> short description
```

Pick the commit type (`feat`, `fix`, `refactor`, `perf`, `docs`, `chore`, ...) and pair it with the matching gitmoji from the official list - not a random emoji.

### Examples

```
feat: ✨ add consumable display mode preview to options panel
fix: 🐛 refresh spells and overlays on spec swap and talent changes
refactor: ♻️ decouple sub-icon display from click-to-cast setting
refactor: 🔥 remove tooltips from buff icons and sub-icons
chore: 🔧 add 12.0.1 interface version to TOC
```

## Code Patterns

### Basics

- Lua 5.1 (WoW scripting environment)
- 120 column width, 4-space indentation (enforced by StyLua)
- Use `pcall()` for WoW API calls that can fail

### Shared Namespace

All modules share the `BR` namespace. Each file exports at the end and consumes via local aliases at the top:

```lua
-- Exporting (end of file)
BR.MyModule = { DoThing = DoThing }

-- Consuming (top of a later file)
local DoThing = BR.MyModule.DoThing
```

### Event-Driven Config

Settings go through the Config API, which fires refresh callbacks automatically. Modules subscribe to the events they care about - options and display never call each other directly. This keeps the codebase decoupled: you can change how a setting is applied without touching the UI that sets it, and vice versa.

```lua
-- Options sets a value (triggers the appropriate callback automatically)
BR.Config.Set("categorySettings.main.iconSize", val)

-- Display subscribes to changes
BR.CallbackRegistry:RegisterCallback("VisualsRefresh", UpdateVisuals)
```

### Cache Computed Values

When a value is read frequently (e.g. every frame update or for each group member), cache it in a local and invalidate on the relevant callback rather than re-reading from the DB every time:

```lua
local cachedIconSize
BR.CallbackRegistry:RegisterCallback("VisualsRefresh", function()
    cachedIconSize = BR.Config.Get("categorySettings.main.iconSize", 64)
end)
```

### Cache Global Lookups

Lua resolves globals through table lookups on every access. In hot paths (OnUpdate handlers, per-member loops, refresh cycles), cache globals as file-scope locals:

```lua
-- Lua stdlib
local ceil = math.ceil
local format = string.format
local tinsert = table.insert

-- WoW API
local GetTime = GetTime
local UnitClass = UnitClass

-- Locale strings (never change at runtime)
local FMT_MINUTES = L["Overlay.MinutesFormat"]
```

### State / Display Separation

State computes what buffs are missing (pure data, no UI). Display renders frames based on state (no state mutation). State never imports display.

### Declarative UI Components

Components use factory functions with `get`/`enabled`/`onChange` callbacks. When a change affects other components' enabled state, call `Components.RefreshAll()` in `onChange`. Never use imperative `UpdateXxxEnabled()` patterns.

```lua
Components.Slider(parent, {
    label = L["Options.IconSize"],
    min = 32, max = 128, step = 1,
    get = function() return BR.Config.Get("categorySettings.main.iconSize", 64) end,
    enabled = function() return someCondition() end,
    onChange = function(val) BR.Config.Set("categorySettings.main.iconSize", val) end,
})
```

### SavedVariables Compatibility

`BuffRemindersDB` persists user settings across sessions. Every change must be backwards-compatible with data that's already out in the wild - a bad migration crashes the addon for real users on login.

**Rules:**
- Never rename or remove a DB key without a migration
- Always add nil-safe fallbacks when reading nested values (`or defaults.x`)
- Set removed fields to `nil` to clean up stale data

**Migrations** run in `ADDON_LOADED`, after `DeepCopyDefault(defaults, BuffRemindersDB)` has filled in any missing keys with their defaults. A migration should check for the old shape, transform it into the new shape, and nil out the old key:

```lua
-- Example: renaming "showCount" → "countDisplay" (string enum)
if type(db.showCount) == "boolean" then
    db.countDisplay = db.showCount and "fraction" or "none"
    db.showCount = nil
end
```

Always check for `nil` before indexing into nested tables - a user's DB may predate the field entirely.

### Localization

**Never hardcode user-facing English strings in source files.** All display text must go through `BR.L`.

Keys use PascalCase dot notation (`L["Options.ClickToCast"]`, `L["Overlay.NoFlask"]`). Each source file that shows text to users needs `local L = BR.L` at the top.

**To add a new string:**

1. Define it in `Locales/enUS.lua`: `english["Section.Key"] = "English text"`
2. Add translations to all 10 locale files: `L["Section.Key"] = "Translated text"`
3. Use `L["Section.Key"]` in the source file
4. Run `make` - the `locales` target verifies all keys are in sync

**Don't localize:** spell names (WoW API handles those), config keys, frame names, internal identifiers.

**Overlay text** (`Overlay.*` keys) must be very short (2-4 chars per line) to fit on small buff icons.
