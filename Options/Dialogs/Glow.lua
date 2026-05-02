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
-- Keys are bare suffixes — they're prefixed with "glow"/"missingGlow" by the
-- K() closure inside Show, so the same schema drives both glow kinds.

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

local glowAdvancedDialog = nil

---@param targetCategory? string nil = global defaults, string = per-category override
---@param glowKind? "expiring"|"missing" Which glow style to edit (default "expiring")
local function Show(targetCategory, glowKind)
    glowKind = glowKind or "expiring"

    if glowAdvancedDialog then
        glowAdvancedDialog:Hide()
        glowAdvancedDialog = nil
    end

    -- Key prefix: "glow" for expiring, "missingGlow" for missing
    local keyPrefix = glowKind == "missing" and "missingGlow" or "glow"
    ---@param suffix string e.g. "Type" → "glowType" or "missingGlowType"
    local function K(suffix)
        return keyPrefix .. suffix
    end

    local configPrefix = targetCategory and ("categorySettings." .. targetCategory .. ".") or "defaults."
    local function getSource()
        if targetCategory then
            return (BR.profile.categorySettings and BR.profile.categorySettings[targetCategory]) or {}
        else
            return BR.profile.defaults or {}
        end
    end

    -- Schema-driven get/set wired to the per-Show keyPrefix + configPrefix.
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

    local PANEL_W = 440
    local PANEL_H = 460
    local PREVIEW_SIZE = 64
    local MARGIN = 20

    local panel = CreatePanel("BuffRemindersGlowAdvanced", PANEL_W, PANEL_H, {
        strata = "FULLSCREEN",
        dialog = true,
    })

    local titleBase = glowKind == "missing" and L["Options.GlowSettings.Missing"] or L["Options.GlowSettings.Expiring"]
    local titleText = targetCategory
            and (titleBase .. " - " .. targetCategory:sub(1, 1):upper() .. targetCategory:sub(2))
        or titleBase
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("|cffffcc00" .. titleText .. "|r")

    local closeBtn = CreateButton(panel, "x", function()
        panel:Hide()
    end)
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", -6, -6)

    -- Expiring / Missing tab toggle
    local expiringTab = Components.Tab(panel, { label = L["Options.GlowKind.Expiring"] })
    expiringTab:SetPoint("TOPLEFT", MARGIN, -32)
    expiringTab:SetActive(glowKind == "expiring")
    expiringTab:SetScript("OnClick", function()
        Show(targetCategory, "expiring")
    end)

    local missingTab = Components.Tab(panel, { label = L["Options.GlowKind.Missing"] })
    missingTab:SetPoint("LEFT", expiringTab, "RIGHT", 4, 0)
    missingTab:SetActive(glowKind == "missing")
    missingTab:SetScript("OnClick", function()
        Show(targetCategory, "missing")
    end)

    local previewKey = "BR_adv_preview"

    -- Content area
    local dynamicHolders = {}
    local staticLayout = Components.VerticalLayout(panel, { x = MARGIN, y = -56 })

    -- Enabled checkbox (per-kind enable/disable)
    local enableKey = glowKind == "missing" and "showMissingGlow" or "showExpirationGlow"
    local enableHolder = Components.Checkbox(panel, {
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

    -- Type dropdown (always visible, top-left beside preview)
    local typeFallback = glowKind == "missing" and GlowType.Pixel or GlowType.AutoCast
    local typeOptions = {}
    for i, gt in ipairs(GlowTypes) do
        typeOptions[i] = { label = gt.name, value = i }
    end

    local typeHolder = Components.Dropdown(panel, {
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

    local DYNAMIC_START_Y = staticLayout:GetY()

    -- Preview icon (below separator, top-right)
    local previewFrame = CreateFrame("Frame", nil, panel)
    previewFrame:SetSize(PREVIEW_SIZE, PREVIEW_SIZE)
    previewFrame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -(MARGIN + 20), DYNAMIC_START_Y)

    local previewIcon = previewFrame:CreateTexture(nil, "ARTWORK")
    previewIcon:SetAllPoints()
    previewIcon:SetTexCoord(TEXCOORD_INSET, 1 - TEXCOORD_INSET, TEXCOORD_INSET, 1 - TEXCOORD_INSET)
    previewIcon:SetTexture(GetBuffTexture(1459))

    local previewBorder = previewFrame:CreateTexture(nil, "BACKGROUND")
    previewBorder:SetPoint("TOPLEFT", -DEFAULT_BORDER_SIZE, DEFAULT_BORDER_SIZE)
    previewBorder:SetPoint("BOTTOMRIGHT", DEFAULT_BORDER_SIZE, -DEFAULT_BORDER_SIZE)
    previewBorder:SetColorTexture(0, 0, 0, 1)

    local function RefreshPreview()
        Glow.StopAll(previewFrame, previewKey)
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
        Glow.Start(previewFrame, typeIdx, color, previewKey, size, xOff, yOff, params)
    end

    local SLIDER_SPACING = 24
    local dynamicLayout

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

    local function AddSlider(config)
        local holder = Components.Slider(panel, config)
        holder:SetPoint("RIGHT", panel, "RIGHT", -MARGIN, 0)
        dynamicLayout:Add(holder, SLIDER_SPACING)
        table.insert(dynamicHolders, holder)
        return holder
    end

    local function AddCheckbox(config)
        local holder = Components.Checkbox(panel, config)
        dynamicLayout:Add(holder, SLIDER_SPACING)
        table.insert(dynamicHolders, holder)
        return holder
    end

    local function AddSpec(spec)
        if spec.kind == "slider" then
            AddSlider(sliderConfigFromSpec(spec))
        elseif spec.kind == "checkbox" then
            AddCheckbox(checkboxConfigFromSpec(spec))
        end
    end

    local function UnregisterDynamicHolders()
        for _, h in ipairs(dynamicHolders) do
            h:Hide()
            Components.Unregister(h)
        end
    end

    local function BuildTypeContent()
        -- Hide and unregister old dynamic components
        UnregisterDynamicHolders()
        wipe(dynamicHolders)
        dynamicLayout = Components.VerticalLayout(panel, { x = MARGIN, y = DYNAMIC_START_Y })

        local typeIdx = readKey("Type", typeFallback)

        -- Size + Color row
        local sizeHolder
        if typeIdx == GlowType.Pixel or typeIdx == GlowType.Border then
            sizeHolder = Components.NumericStepper(panel, {
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
            table.insert(dynamicHolders, sizeHolder)
        end

        local colorSwatchHolder
        local procColorCheckbox
        if typeIdx == GlowType.Proc then
            -- Proc: optional custom color (desaturated + vertex color, less vibrant than default)
            procColorCheckbox = Components.Checkbox(panel, {
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
            table.insert(dynamicHolders, procColorCheckbox)

            colorSwatchHolder = Components.ColorSwatch(panel, {
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
            table.insert(dynamicHolders, colorSwatchHolder)
        else
            colorSwatchHolder = Components.ColorSwatch(panel, {
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
            table.insert(dynamicHolders, colorSwatchHolder)
        end

        if sizeHolder and colorSwatchHolder and not procColorCheckbox then
            dynamicLayout:Add(sizeHolder, 26)
            colorSwatchHolder:SetPoint("LEFT", sizeHolder, "RIGHT", 8, 0)
        elseif sizeHolder then
            dynamicLayout:Add(sizeHolder, 26)
        elseif colorSwatchHolder and not procColorCheckbox then
            dynamicLayout:Add(colorSwatchHolder, 26)
        end

        if procColorCheckbox then
            dynamicLayout:Add(procColorCheckbox, SLIDER_SPACING)
            colorSwatchHolder:SetPoint("LEFT", procColorCheckbox, "RIGHT", 8, 0)
        end

        -- Type-specific parameters from schema
        local typeSpecs = GLOW_SCHEMA[typeIdx]
        if typeSpecs then
            for _, spec in ipairs(typeSpecs) do
                AddSpec(spec)
            end
        end

        -- Common offsets
        for _, spec in ipairs(GLOW_COMMON_OFFSETS) do
            AddSpec(spec)
        end

        -- Reset button (resets shared keys + every type-specific key from schema).
        dynamicLayout:Space(8)
        local resetBtn = CreateButton(panel, L["Options.ResetToDefaults"], function()
            local keys = { K("Color"), K("Size"), K("XOffset"), K("YOffset") }
            if typeSpecs then
                for _, spec in ipairs(typeSpecs) do
                    keys[#keys + 1] = K(spec.key)
                end
            end
            -- Proc's optional custom-color toggle isn't in the schema (it sits
            -- next to the swatch, not in the type rows) so reset it explicitly.
            if typeIdx == GlowType.Proc then
                keys[#keys + 1] = K("ProcUseCustomColor")
            end
            for _, key in ipairs(keys) do
                BR.Config.Set(configPrefix .. key, nil)
            end
            BuildTypeContent()
            RefreshPreview()
            Components.RefreshAll()
        end)
        resetBtn:SetSize(140, 24)
        dynamicLayout:Add(resetBtn, 24)
        table.insert(dynamicHolders, resetBtn)

        -- Adjust panel height
        panel:SetHeight(math.abs(dynamicLayout:GetY()) + 46)

        RefreshPreview()
    end

    BuildTypeContent()

    -- Subscribe to glow type changes to rebuild type-specific content
    local function OnSettingChanged(_, path)
        if path == configPrefix .. K("Type") then
            BuildTypeContent()
        end
    end
    BR.CallbackRegistry:RegisterCallback("SettingChanged", OnSettingChanged, panel)

    panel:SetScript("OnHide", function()
        Glow.StopAll(previewFrame, previewKey)
        BR.CallbackRegistry:UnregisterCallback("SettingChanged", panel)
        UnregisterDynamicHolders()
    end)

    glowAdvancedDialog = panel
end

BR.Options.Dialogs.Glow = { Show = Show }
