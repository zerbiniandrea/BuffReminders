local _, BR = ...

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local CreatePanel = BR.CreatePanel
local Glow = BR.Glow
local GlowTypes = Glow.Types
local GlowType = Glow.Type

local TEXCOORD_INSET = BR.TEXCOORD_INSET
local DEFAULT_BORDER_SIZE = BR.DEFAULT_BORDER_SIZE
local GetBuffTexture = BR.Helpers.GetBuffTexture

local LayoutSeparator = BR.Options.Helpers.LayoutSeparator

-- ============================================================================
-- GLOW PARAMETER SCHEMA
-- ============================================================================
-- One row per type-specific control. The runtime iterates this in order to
-- build the dynamic content area; adding a new param means adding one row.
-- `kind` switches between Components.Slider and Components.Checkbox; `fmt` is
-- the optional `formatValue` printf string (omit for integer rendering).
--
-- Keys are bare suffixes - they're prefixed with "glow"/"missingGlow" by the
-- K() closure, so the same schema drives both glow kinds.

local GLOW_SCHEMA = {
    [GlowType.Pixel] = {
        { kind = "slider", labelKey = "Lines", key = "PixelLines", min = 1, max = 20, step = 1, default = 8 },
        {
            kind = "slider",
            labelKey = "Frequency",
            key = "PixelFrequency",
            min = 0.01,
            max = 1,
            step = 0.01,
            default = 0.25,
            fmt = "%.2f",
        },
        { kind = "slider", labelKey = "Length", key = "PixelLength", min = 1, max = 20, step = 1, default = 10 },
    },
    [GlowType.AutoCast] = {
        {
            kind = "slider",
            labelKey = "Scale",
            key = "AutocastScale",
            min = 1,
            max = 3,
            step = 0.1,
            default = 1,
            fmt = "%.1f",
        },
        { kind = "slider", labelKey = "Particles", key = "AutocastParticles", min = 1, max = 8, step = 1, default = 4 },
        {
            kind = "slider",
            labelKey = "Frequency",
            key = "AutocastFrequency",
            min = 0.01,
            max = 1,
            step = 0.01,
            default = 0.125,
            fmt = "%.2f",
        },
    },
    [GlowType.Border] = {
        {
            kind = "slider",
            labelKey = "Speed",
            key = "BorderFrequency",
            min = 0.1,
            max = 2,
            step = 0.1,
            default = 0.6,
            fmt = "%.1f",
        },
    },
    [GlowType.Proc] = {
        {
            kind = "slider",
            labelKey = "Duration",
            key = "ProcDuration",
            min = 0.1,
            max = 3,
            step = 0.1,
            default = 1,
            fmt = "%.1f",
        },
        { kind = "checkbox", labelKey = "StartAnimation", key = "ProcStartAnim", default = false },
    },
}

-- Offsets are common to every glow type, rendered after the type-specific block.
local GLOW_COMMON_OFFSETS = {
    { kind = "slider", labelKey = "XOffset", key = "XOffset", min = -10, max = 10, step = 1, default = 0 },
    { kind = "slider", labelKey = "YOffset", key = "YOffset", min = -10, max = 10, step = 1, default = 0 },
}

local PANEL_W = 440
local PANEL_H = 460
local PREVIEW_SIZE = 64
local PREVIEW_PAD = 12
local MARGIN = 20
local SLIDER_SPACING = 24
local PREVIEW_KEY = "BR_adv_preview"

-- ============================================================================
-- SINGLETON STATE
-- ============================================================================
-- WoW frames are never garbage-collected, so the dialog is built once and
-- reused. The editing context (category + glow kind) lives in mutable upvalues
-- that every widget's get/onChange closure reads live; Show() just re-points
-- the context and refreshes, instead of recreating frames each open/tab switch.

local Show -- forward declaration (the tab handlers in BuildPanel call it)

local panel
local titleFS, expiringTab, missingTab, enableHolder, typeHolder
local previewFrame, staticLayout
local DYNAMIC_START_Y

-- Per-type dynamic content, cached so each of the four types is built at most
-- once. [typeIdx] = { frame, height }; switching type hides one and shows another.
local typeContainers = {}
local activeContainer

-- Current editing context (set by Show before anything reads it).
local currentCategory -- nil = global defaults, string = per-category override
local currentKind -- "expiring" | "missing"
local keyPrefix, configPrefix, enableKey, typeFallback

-- ============================================================================
-- CONTEXT HELPERS (read the mutable upvalues above)
-- ============================================================================

---@param suffix string e.g. "Type" -> "glowType" or "missingGlowType"
local function K(suffix)
    return keyPrefix .. suffix
end

local function getSource()
    if currentCategory then
        return (BR.profile.categorySettings and BR.profile.categorySettings[currentCategory]) or {}
    else
        return BR.profile.defaults or {}
    end
end

local function readKey(key, default)
    local v = getSource()[K(key)]
    if v == nil then
        return default
    end
    return v
end

local function writeKey(key, val)
    BR.Config.Set(configPrefix .. K(key), val)
end

local function RefreshPreview()
    Glow.StopAll(previewFrame, PREVIEW_KEY)
    local d = getSource()
    local typeIdx = d[K("Type")] or typeFallback
    local color = d[K("Color")]
    if typeIdx == GlowType.Proc and not d[K("ProcUseCustomColor")] then
        color = nil
    end
    local size = d[K("Size")] or 2
    local params = Glow.BuildAdvancedParams(d, typeIdx, keyPrefix)
    local xOff = DEFAULT_BORDER_SIZE + (d[K("XOffset")] or 0)
    local yOff = DEFAULT_BORDER_SIZE + (d[K("YOffset")] or 0)
    Glow.Start(previewFrame, typeIdx, color, PREVIEW_KEY, size, xOff, yOff, params)
end

-- Build a Components.Slider config from one schema row.
local function sliderConfigFromSpec(spec)
    local cfg = {
        label = L["Options.Glow." .. spec.labelKey],
        min = spec.min,
        max = spec.max,
        step = spec.step,
        get = function()
            return readKey(spec.key, spec.default)
        end,
        onChange = function(val)
            writeKey(spec.key, val)
            RefreshPreview()
        end,
    }
    if spec.fmt then
        local fmt = spec.fmt
        cfg.formatValue = function(val)
            return string.format(fmt, val)
        end
    end
    return cfg
end

local function checkboxConfigFromSpec(spec)
    return {
        label = L["Options.Glow." .. spec.labelKey],
        get = function()
            return readKey(spec.key, spec.default)
        end,
        onChange = function(checked)
            writeKey(spec.key, checked)
            RefreshPreview()
        end,
    }
end

-- ============================================================================
-- DYNAMIC (PER-TYPE) CONTENT
-- ============================================================================

-- Build the type-specific controls for one glow type into a cached container
-- frame. Values are wired through readKey/writeKey, so the same container is
-- reused across kinds/categories - only the displayed values change.
local function BuildTypeContainer(typeIdx)
    local container = CreateFrame("Frame", nil, panel)
    container:SetAllPoints(panel)
    local layout = Components.VerticalLayout(container, { x = MARGIN, y = DYNAMIC_START_Y })

    local function addSlider(cfg)
        local holder = Components.Slider(container, cfg)
        holder:SetPoint("RIGHT", container, "RIGHT", -MARGIN, 0)
        layout:Add(holder, SLIDER_SPACING)
    end
    local function addCheckbox(cfg)
        layout:Add(Components.Checkbox(container, cfg), SLIDER_SPACING)
    end
    local function addSpec(spec)
        if spec.kind == "slider" then
            addSlider(sliderConfigFromSpec(spec))
        elseif spec.kind == "checkbox" then
            addCheckbox(checkboxConfigFromSpec(spec))
        end
    end

    -- Size + Color row
    local sizeHolder
    if typeIdx == GlowType.Pixel or typeIdx == GlowType.Border then
        sizeHolder = Components.NumericStepper(container, {
            label = L["Options.Glow.Size"],
            labelWidth = 34,
            min = 1,
            max = 10,
            step = 1,
            get = function()
                return readKey("Size", 2)
            end,
            onChange = function(val)
                writeKey("Size", val)
                RefreshPreview()
            end,
        })
    end

    local colorSwatchHolder
    local procColorCheckbox
    if typeIdx == GlowType.Proc then
        -- Proc: optional custom color (desaturated + vertex color, less vibrant than default)
        procColorCheckbox = Components.Checkbox(container, {
            label = L["Options.UseCustomColor"],
            tooltip = {
                title = L["Options.UseCustomColor"],
                desc = L["Options.UseCustomColor.Desc"],
            },
            get = function()
                return readKey("ProcUseCustomColor", false)
            end,
            onChange = function(checked)
                writeKey("ProcUseCustomColor", checked)
                Components.RefreshAll()
                RefreshPreview()
            end,
        })

        colorSwatchHolder = Components.ColorSwatch(container, {
            hasOpacity = true,
            enabled = function()
                return readKey("ProcUseCustomColor", false)
            end,
            get = function()
                local c = readKey("Color", Glow.DEFAULT_COLOR)
                return c[1], c[2], c[3], c[4] or 1
            end,
            onChange = function(r, g, b, a)
                writeKey("Color", { r, g, b, a or 1 })
                RefreshPreview()
            end,
        })
    else
        colorSwatchHolder = Components.ColorSwatch(container, {
            hasOpacity = true,
            get = function()
                local c = readKey("Color", Glow.DEFAULT_COLOR)
                return c[1], c[2], c[3], c[4] or 1
            end,
            onChange = function(r, g, b, a)
                writeKey("Color", { r, g, b, a or 1 })
                RefreshPreview()
            end,
        })
    end

    if sizeHolder and colorSwatchHolder and not procColorCheckbox then
        layout:Add(sizeHolder, 26)
        colorSwatchHolder:SetPoint("LEFT", sizeHolder, "RIGHT", 8, 0)
    elseif sizeHolder then
        layout:Add(sizeHolder, 26)
    elseif colorSwatchHolder and not procColorCheckbox then
        layout:Add(colorSwatchHolder, 26)
    end

    if procColorCheckbox then
        layout:Add(procColorCheckbox, SLIDER_SPACING)
        colorSwatchHolder:SetPoint("LEFT", procColorCheckbox, "RIGHT", 8, 0)
    end

    -- Type-specific parameters from schema
    local typeSpecs = GLOW_SCHEMA[typeIdx]
    if typeSpecs then
        for _, spec in ipairs(typeSpecs) do
            addSpec(spec)
        end
    end

    -- Common offsets
    for _, spec in ipairs(GLOW_COMMON_OFFSETS) do
        addSpec(spec)
    end

    -- Reset button (resets shared keys + every type-specific key from schema).
    layout:Space(8)
    local resetBtn = CreateButton(container, L["Options.ResetToDefaults"], function()
        local keys = { K("Color"), K("Size"), K("XOffset"), K("YOffset") }
        if typeSpecs then
            for _, spec in ipairs(typeSpecs) do
                keys[#keys + 1] = K(spec.key)
            end
        end
        -- Proc's optional custom-color toggle isn't in the schema (it sits next to
        -- the swatch, not in the type rows) so reset it explicitly.
        if typeIdx == GlowType.Proc then
            keys[#keys + 1] = K("ProcUseCustomColor")
        end
        for _, key in ipairs(keys) do
            BR.Config.Set(configPrefix .. key, nil)
        end
        Components.RefreshAll()
        RefreshPreview()
    end)
    resetBtn:SetSize(140, 24)
    layout:Add(resetBtn, 24)

    local entry = { frame = container, height = math.abs(layout:GetY()) + 46 }
    typeContainers[typeIdx] = entry
    return entry
end

-- Swap the visible type container (building it the first time), resize the panel
-- to fit, sync widget values, and restart the preview glow.
local function ShowTypeContent(typeIdx)
    if activeContainer then
        activeContainer.frame:Hide()
    end
    local entry = typeContainers[typeIdx] or BuildTypeContainer(typeIdx)
    entry.frame:Show()
    activeContainer = entry
    panel:SetHeight(entry.height)
    Components.RefreshAll()
    RefreshPreview()
end

-- ============================================================================
-- PANEL (built once)
-- ============================================================================

local function BuildPanel()
    panel = CreatePanel("BuffRemindersGlowAdvanced", PANEL_W, PANEL_H, {
        strata = "FULLSCREEN",
        dialog = true,
    })

    titleFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleFS:SetPoint("TOP", 0, -10)

    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function()
        panel:Hide()
    end)

    -- Expiring / Missing tab toggle (sits below the header divider)
    expiringTab = Components.Tab(panel, { label = L["Options.GlowKind.Expiring"] })
    expiringTab:SetPoint("TOPLEFT", MARGIN, -42)
    expiringTab:SetScript("OnClick", function()
        Show(currentCategory, "expiring")
    end)

    missingTab = Components.Tab(panel, { label = L["Options.GlowKind.Missing"] })
    missingTab:SetPoint("LEFT", expiringTab, "RIGHT", 10, 0)
    missingTab:SetScript("OnClick", function()
        Show(currentCategory, "missing")
    end)

    -- Grounding baseline under the tab strip (matches the Categories tabs).
    Components.TabBaseline(panel, expiringTab, PANEL_W - MARGIN * 2)

    staticLayout = Components.VerticalLayout(panel, { x = MARGIN, y = -74 })

    enableHolder = Components.Checkbox(panel, {
        label = L["Options.Glow.Enabled"],
        get = function()
            return getSource()[enableKey] ~= false
        end,
        onChange = function(checked)
            BR.Config.Set(configPrefix .. enableKey, checked)
            Components.RefreshAll()
        end,
    })
    staticLayout:Add(enableHolder, 24, 2)

    local typeOptions = {}
    for i, gt in ipairs(GlowTypes) do
        typeOptions[i] = { label = gt.name, value = i }
    end

    typeHolder = Components.Dropdown(panel, {
        label = L["Options.Glow.Type"],
        labelWidth = 40,
        options = typeOptions,
        get = function()
            return readKey("Type", typeFallback)
        end,
        width = 140,
        onChange = function(val)
            writeKey("Type", val)
        end,
    }, "BuffRemindersGlowAdvTypeDropdown")
    staticLayout:Add(typeHolder, 30, 4)

    LayoutSeparator(staticLayout, panel)
    staticLayout:Space(10)
    DYNAMIC_START_Y = staticLayout:GetY()

    -- Preview: a captioned inset pinned to the header's free right-hand column,
    -- beside the enable/type controls. Framing it (border + caption) reads as an
    -- intentional preview panel; keeping it up here clears the full-width sliders
    -- that fill the dynamic region below.
    local previewBox = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    previewBox:SetSize(PREVIEW_SIZE + PREVIEW_PAD * 2, PREVIEW_SIZE + PREVIEW_PAD * 2)
    previewBox:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -MARGIN, -70)
    previewBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    previewBox:SetBackdropColor(0.08, 0.08, 0.1, 1)
    previewBox:SetBackdropBorderColor(unpack(BR.Colors.Border))

    local previewCaption = previewBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    previewCaption:SetPoint("BOTTOM", previewBox, "TOP", 0, 3)
    previewCaption:SetText(L["Options.Preview"])

    previewFrame = CreateFrame("Frame", nil, previewBox)
    previewFrame:SetSize(PREVIEW_SIZE, PREVIEW_SIZE)
    previewFrame:SetPoint("CENTER", previewBox, "CENTER", 0, 0)

    local previewIcon = previewFrame:CreateTexture(nil, "ARTWORK")
    previewIcon:SetAllPoints()
    previewIcon:SetTexCoord(TEXCOORD_INSET, 1 - TEXCOORD_INSET, TEXCOORD_INSET, 1 - TEXCOORD_INSET)
    previewIcon:SetTexture(GetBuffTexture(1459))

    local previewBorder = previewFrame:CreateTexture(nil, "BACKGROUND")
    previewBorder:SetPoint("TOPLEFT", -DEFAULT_BORDER_SIZE, DEFAULT_BORDER_SIZE)
    previewBorder:SetPoint("BOTTOMRIGHT", DEFAULT_BORDER_SIZE, -DEFAULT_BORDER_SIZE)
    previewBorder:SetColorTexture(0, 0, 0, 1)

    -- Rebuild the dynamic block when the glow type changes (only while shown, and
    -- only for this dialog's current Type key). The callback lives for the life of
    -- the panel - no per-show register/unregister churn.
    BR.CallbackRegistry:RegisterCallback("SettingChanged", function(_, path)
        if panel:IsShown() and path == configPrefix .. K("Type") then
            ShowTypeContent(readKey("Type", typeFallback))
        end
    end, panel)

    panel:SetScript("OnHide", function()
        Glow.StopAll(previewFrame, PREVIEW_KEY)
    end)
end

-- ============================================================================
-- ENTRY POINT
-- ============================================================================

---@param category? string nil = global defaults, string = per-category override
---@param kind? "expiring"|"missing" Which glow style to edit (default "expiring")
Show = function(category, kind)
    currentCategory = category
    currentKind = kind or "expiring"
    keyPrefix = currentKind == "missing" and "missingGlow" or "glow"
    configPrefix = currentCategory and ("categorySettings." .. currentCategory .. ".") or "defaults."
    enableKey = currentKind == "missing" and "showMissingGlow" or "showExpirationGlow"
    typeFallback = currentKind == "missing" and GlowType.Pixel or GlowType.AutoCast

    if not panel then
        BuildPanel()
    end

    local titleBase = currentKind == "missing" and L["Options.GlowSettings.Missing"]
        or L["Options.GlowSettings.Expiring"]
    local titleText = currentCategory
            and (titleBase .. " - " .. currentCategory:sub(1, 1):upper() .. currentCategory:sub(2))
        or titleBase
    titleFS:SetText("|cffffcc00" .. titleText .. "|r")

    expiringTab:SetActive(currentKind == "expiring")
    missingTab:SetActive(currentKind == "missing")

    ShowTypeContent(readKey("Type", typeFallback))
    panel:Show()
end

BR.Options.Dialogs.Glow = { Show = Show }
