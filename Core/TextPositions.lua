local _, BR = ...

-- ============================================================================
-- TEXT POSITIONS
-- ============================================================================
-- Resolves per-text-item placement on buff icons. A "zone" is one of fifteen
-- semantic positions (5 vertical bands x 3 horizontal columns), plus an
-- optional pixel nudge. Display sites must call Apply() instead of SetPoint,
-- so the user can re-arrange overlapping text from Options.
--
-- Icon-overlay items also carry an optional size, stored as a percentage of the
-- icon size in defaults.textSizes[item].
--
-- Storage is global only. Each item has exactly one realistic consumer, so
-- there is no per-category override.

BR.TextPositions = {}

-- Each zone holds the SetPoint args plus a baseline nudge that keeps the text
-- off the icon edge. The user offset adds to that nudge.
local ZONES = {
    -- INSIDE: anchored to a point of the icon itself (inset by a few pixels)
    INSIDE_TL = { point = "TOPLEFT", relPoint = "TOPLEFT", dx = 2, dy = -2 },
    INSIDE_T = { point = "TOP", relPoint = "TOP", dx = 0, dy = -2 },
    INSIDE_TR = { point = "TOPRIGHT", relPoint = "TOPRIGHT", dx = -2, dy = -2 },
    INSIDE_L = { point = "LEFT", relPoint = "LEFT", dx = 2, dy = 0 },
    INSIDE_C = { point = "CENTER", relPoint = "CENTER", dx = 0, dy = 0 },
    INSIDE_R = { point = "RIGHT", relPoint = "RIGHT", dx = -2, dy = 0 },
    INSIDE_BL = { point = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", dx = 2, dy = 2 },
    INSIDE_B = { point = "BOTTOM", relPoint = "BOTTOM", dx = 0, dy = 2 },
    INSIDE_BR = { point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", dx = -2, dy = 2 },
    -- ABOVE: text's bottom edge anchored to icon's top
    ABOVE_L = { point = "BOTTOMLEFT", relPoint = "TOPLEFT", dx = 0, dy = 4 },
    ABOVE_C = { point = "BOTTOM", relPoint = "TOP", dx = 0, dy = 4 },
    ABOVE_R = { point = "BOTTOMRIGHT", relPoint = "TOPRIGHT", dx = 0, dy = 4 },
    -- BELOW: text's top edge anchored to icon's bottom
    BELOW_L = { point = "TOPLEFT", relPoint = "BOTTOMLEFT", dx = 0, dy = -4 },
    BELOW_C = { point = "TOP", relPoint = "BOTTOM", dx = 0, dy = -4 },
    BELOW_R = { point = "TOPRIGHT", relPoint = "BOTTOMRIGHT", dx = 0, dy = -4 },
}
BR.TextPositions.Zones = ZONES

-- Repositionable text items the UI exposes, in display order. The `count` key
-- name is too narrow: the region also carries countdowns and "NO FLASK"-style
-- labels. The UI calls it "Main text".
BR.TextPositions.Items = {
    "count",
    "buffReminder",
    "statLabel",
    "badge",
    "stackCount",
    "petLabel", -- anchors the pet name; the family and extra stack sit below it
}

-- Two-axis decomposition of zone names. The UI presents "Vertical" and
-- "Align" dropdowns instead of a 5x3 picker widget. The zone strings are
-- asymmetric ("INSIDE_T" = top-center, "INSIDE_TL" = top-left); the maps below
-- hide that from callers.

BR.TextPositions.VERTICAL_OPTIONS = {
    { value = "ABOVE", labelKey = "Options.TextPositions.Vertical.Above" },
    { value = "INSIDE_T", labelKey = "Options.TextPositions.Vertical.InsideTop" },
    { value = "INSIDE_M", labelKey = "Options.TextPositions.Vertical.InsideMiddle" },
    { value = "INSIDE_B", labelKey = "Options.TextPositions.Vertical.InsideBottom" },
    { value = "BELOW", labelKey = "Options.TextPositions.Vertical.Below" },
}

BR.TextPositions.ALIGN_OPTIONS = {
    { value = "L", labelKey = "Options.TextPositions.Align.Left" },
    { value = "C", labelKey = "Options.TextPositions.Align.Center" },
    { value = "R", labelKey = "Options.TextPositions.Align.Right" },
}

local ZONE_FROM_VA = {
    ABOVE = { L = "ABOVE_L", C = "ABOVE_C", R = "ABOVE_R" },
    INSIDE_T = { L = "INSIDE_TL", C = "INSIDE_T", R = "INSIDE_TR" },
    INSIDE_M = { L = "INSIDE_L", C = "INSIDE_C", R = "INSIDE_R" },
    INSIDE_B = { L = "INSIDE_BL", C = "INSIDE_B", R = "INSIDE_BR" },
    BELOW = { L = "BELOW_L", C = "BELOW_C", R = "BELOW_R" },
}

local VA_FROM_ZONE = {}
for v, row in pairs(ZONE_FROM_VA) do
    for a, z in pairs(row) do
        VA_FROM_ZONE[z] = { vertical = v, align = a }
    end
end

---Decompose a zone string into (vertical, align). Falls back to INSIDE_C
---components for unknown zones.
---@param zone string?
---@return string vertical
---@return string align
function BR.TextPositions.ToVA(zone)
    local va = VA_FROM_ZONE[zone] or VA_FROM_ZONE.INSIDE_C
    return va.vertical, va.align
end

---Recompose a zone string from (vertical, align). Falls back to INSIDE_C on
---missing/unknown axis values.
---@param vertical string
---@param align string
---@return string zone
function BR.TextPositions.FromVA(vertical, align)
    local row = ZONE_FROM_VA[vertical] or ZONE_FROM_VA.INSIDE_M
    return row[align] or row.C or "INSIDE_C"
end

local DEFAULT_ZONES = {
    count = "INSIDE_C",
    stackCount = "INSIDE_BR",
    statLabel = "INSIDE_TL",
    badge = "INSIDE_L",
    buffReminder = "BELOW_C",
    petLabel = "BELOW_C",
}
BR.TextPositions.DefaultZones = DEFAULT_ZONES

-- Icon-overlay text items that carry an independent size. The stored value is a
-- percentage of the icon size. An absent value follows consumableTextScale.
local SIZED_ITEMS = {
    statLabel = true,
    badge = true,
    stackCount = true,
}
BR.TextPositions.SizedItems = SIZED_ITEMS

---Stored size override for an item, or nil while the item follows the base.
---@param item string? A key from BR.TextPositions.SizedItems
---@return number?
function BR.TextPositions.GetSizeOverride(item)
    if not item or not SIZED_ITEMS[item] then
        return nil
    end
    local defaults = BR.profile and BR.profile.defaults
    local sizes = defaults and defaults.textSizes
    return sizes and sizes[item]
end

---Effective size percentage for an icon-overlay text item.
---@param item string? nil returns the shared base
---@return number percent
function BR.TextPositions.GetSizePercent(item)
    local own = BR.TextPositions.GetSizeOverride(item)
    if own then
        return own
    end
    local defaults = BR.profile and BR.profile.defaults
    return (defaults and defaults.consumableTextScale) or BR.defaults.defaults.consumableTextScale
end

---Resolve a zone name to its SetPoint descriptor. Falls back to INSIDE_C.
---@param zone string?
---@return table {point, relPoint, dx, dy}
function BR.TextPositions.Resolve(zone)
    return ZONES[zone] or ZONES.INSIDE_C
end

---Look up the effective text-position config for an item.
---@param item string A key from BR.TextPositions.Items
---@return string zone
---@return number offsetX
---@return number offsetY
function BR.TextPositions.Get(item)
    local db = BR.profile
    if not db then
        return DEFAULT_ZONES[item] or "INSIDE_C", 0, 0
    end

    local defaults = db.defaults
    if defaults and defaults.textPositions and defaults.textPositions[item] then
        local cfg = defaults.textPositions[item]
        return cfg.zone or DEFAULT_ZONES[item] or "INSIDE_C", cfg.offsetX or 0, cfg.offsetY or 0
    end

    return DEFAULT_ZONES[item] or "INSIDE_C", 0, 0
end

---Anchor a FontString (or texture) using a zone + user nudge.
---@param region table The Region (FontString/Texture) to anchor
---@param frame table The parent icon frame
---@param zone string Zone name (see ZONES)
---@param offsetX number?
---@param offsetY number?
function BR.TextPositions.Apply(region, frame, zone, offsetX, offsetY)
    local z = ZONES[zone] or ZONES.INSIDE_C
    region:ClearAllPoints()
    region:SetPoint(z.point, frame, z.relPoint, z.dx + (offsetX or 0), z.dy + (offsetY or 0))
end
