# Contributing to BuffReminders

[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-yellow.svg)](https://conventionalcommits.org)

## Development environment

You need these tools to run `make`:

| Tool                                                                | Purpose                                                         |
| ------------------------------------------------------------------- | --------------------------------------------------------------- |
| [luacheck](https://github.com/mpeterv/luacheck)                     | Linter                                                          |
| [StyLua](https://github.com/JohnnyMorganz/StyLua)                   | Formatter                                                       |
| [lua-language-server](https://github.com/LuaLS/lua-language-server) | Type checker                                                    |
| [luac5.1](https://www.lua.org/versions.html#5.1)                    | Compiler. It finds the Lua 5.1 limits that the other tools miss |
| [ripgrep](https://github.com/BurntSushi/ripgrep)                    | File search for the `compile` and `ascii-clean` steps           |

```bash
make          # typecheck, lint, compile, ascii-clean, format
make check    # the same checks, but no file is changed
```

Run `make` before you commit.

## Commit messages

This project uses [Conventional Commits](https://www.conventionalcommits.org/) with
[gitmoji](https://gitmoji.dev/). The format is `type(scope): emoji description`. Do not write a
body. Pick the gitmoji from the official list. The scope is optional. It names the area that you
touch, for example `options`, `state`, or `loadouts`.

**The commits are the changelog.** [git-cliff](https://github.com/orhun/git-cliff) builds the
release notes from the commits. The release notes go to the GitHub release, CurseForge, Wago,
and Discord. There is no hand-written changelog. Players read your commit subject, so write a
clear summary. Pick the type by user impact.

| Type                                                                  | Section in the changelog                                               |
| --------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `feat`                                                                | ✨ New Features                                                        |
| `fix`                                                                 | 🐛 Bug Fixes                                                           |
| `perf`                                                                | ⚡️ Performance                                                         |
| `i18n(<locale>)`                                                      | 🌐 Localization. Put the locale in the scope, for example `i18n(zhTW)` |
| `refactor`, `style`, `chore`, `build`, `ci`, `docs`, `test`, `revert` | 🔧 Other Changes                                                       |

Only `feat`, `fix`, and `perf` get top billing. Every other type goes under "Other Changes".
Nothing is hidden. If a change matters to players, give it the type that shows this. A
user-facing feature is a `feat`, even when the diff looks like a refactor.

For a breaking change, add `!` before the colon (`feat(api)!: ...`), or add a
`BREAKING CHANGE:` footer.

### Examples

```
feat: ✨ add consumable display mode preview to options panel
fix: 🐛 refresh spells and overlays on spec swap and talent changes
perf: ⚡️ cache weapon enchant lookups in the refresh path
i18n(zhTW): 🌐 update localization
refactor: ♻️ decouple sub-icon display from click-to-cast setting
```

## Code patterns

### Basics

- Lua 5.1 is the runtime, because this is the WoW script environment.
- Lines are 120 columns wide. Indentation is 4 spaces. StyLua enforces both.
- Use `pcall()` for a WoW API call that can fail.

### Shared namespace

All modules share the `BR` namespace. Each file exports at the end. A later file reads the
export through a local alias at the top.

```lua
-- Export at the end of the file
BR.MyModule = { DoThing = DoThing }

-- Read the export at the top of a later file
local DoThing = BR.MyModule.DoThing
```

### Event-driven settings

Settings go through the Config API. The API fires the refresh callbacks. Each module subscribes
to the events that it needs. The options panel and the display never call each other. As a
result, you can change how a setting applies without a change to the UI that sets it.

```lua
-- The options panel sets a value. The Config API fires the matching callback.
BR.Config.Set("categorySettings.main.iconSize", val)

-- The display subscribes to the change
BR.CallbackRegistry:RegisterCallback("VisualsRefresh", UpdateVisuals)
```

### Cache computed values

Some values are read very often, for example on each frame update or for each group member.
Cache such a value in a local. Invalidate the local on the matching callback. Do not read the
value from the database each time.

```lua
local cachedIconSize
BR.CallbackRegistry:RegisterCallback("VisualsRefresh", function()
    cachedIconSize = BR.Config.Get("categorySettings.main.iconSize", 64)
end)
```

### Cache global lookups

Lua resolves a global with a table lookup on each access. In a hot path, cache the global as a
file-scope local. Hot paths are OnUpdate handlers, per-member loops, and refresh cycles.

```lua
-- Lua stdlib
local ceil = math.ceil
local format = string.format
local tinsert = table.insert

-- WoW API
local GetTime = GetTime
local UnitClass = UnitClass

-- Locale strings, because they never change at runtime
local FMT_MINUTES = L["Overlay.MinutesFormat"]
```

### State and display separation

State computes which buffs are missing. State is pure data and holds no UI code. Display draws
the frames from the state, and never changes the state. State never imports display.

### Declarative UI components

A component factory takes `get`, `enabled`, and `onChange` callbacks. If a change affects the
enabled state of other components, call `Components.RefreshAll()` in `onChange`. Do not write
imperative `UpdateXxxEnabled()` functions.

```lua
Components.Slider(parent, {
    label = L["Options.IconSize"],
    min = 32, max = 128, step = 1,
    get = function() return BR.Config.Get("categorySettings.main.iconSize", 64) end,
    enabled = function() return someCondition() end,
    onChange = function(val) BR.Config.Set("categorySettings.main.iconSize", val) end,
})
```

### SavedVariables compatibility

`BuffRemindersDB` keeps the settings of a user between sessions. Data from every version at or
above `MIN_DB_VERSION` (`Core/Migrations.lua`) is still in use. Every change must stay
compatible with that data. At login, a profile below `MIN_DB_VERSION` resets to empty.

CAUTION: Do not rename or remove a database key without a migration. A bad migration crashes
the addon for real users at login.

Rules:

- When you read a nested value, always add a nil-safe fallback, for example `or defaults.x`.
- Always make sure that a nested table is not `nil` before you index into it. The database of a
  user can predate the field.
- Set a removed field to `nil` to erase the stale data.

Migrations run in `ADDON_LOADED` on the raw saved profiles, before AceDB fills in the default
keys. In a migration, a key with a default reads `nil`. Add a migration as a new numbered entry
at the end of `Core/Migrations.lua`, then increase `DB_VERSION`. A migration must do three
things:

1. Make sure that the old shape is present.
2. Transform the old shape into the new shape.
3. Set the old key to `nil`.

```lua
-- Example: rename "showCount" -> "countDisplay" (string enum)
if type(profile.showCount) == "boolean" then
    profile.countDisplay = profile.showCount and "fraction" or "none"
    profile.showCount = nil
end
```

### Localization

Never write a user-facing English string in a source file. All text for players goes through
`BR.L`.

Keys use PascalCase with dot notation, for example `L["Options.ClickToCast"]`. Each source file
that shows text needs `local L = BR.L` at the top.

To add a new string:

1. Define the key in `Locales/enUS.lua`: `english["Section.Key"] = "English text"`.
2. Use `L["Section.Key"]` in the source file.
3. Run `make i18n` to make sure that the source and `enUS.lua` are in sync.

Add the key to `enUS.lua` only. Every other locale falls back to English until a translator
adds the key.

Do not localize spell names, setting keys, frame names, or other internal identifiers. The WoW
API gives the spell names.

Overlay text comes from the `Overlay.*` keys. This text must be very short, 2-4 characters per
line, because the addon shows it on a small buff icon.

For the translator guide, and for the rule for a string that changes meaning, read
[docs/Localization.md](docs/Localization.md).
