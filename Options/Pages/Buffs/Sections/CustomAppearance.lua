local _, BR = ...

-- ============================================================================
-- BUFF PAGE SECTION: Appearance & Glow overrides
-- ============================================================================
-- Two independently-overridable sections, each headed by an Override checkbox
-- with a live state label ("Inherited from Defaults" / "Overriding defaults").
-- While inheriting, controls stay VISIBLE and show the live global default
-- values, dimmed - never blank, never stale. Flipping Override on snapshots
-- the current effective values into the category so nothing visually jumps;
-- flipping it off keeps the stored values dormant for a later re-enable.
--
-- Appearance override = useCustomAppearance; Glow override = useCustomGlow.
-- The two flags are independent (Core.lua GetCategorySetting).

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton

local GetCategorySettings = BR.Helpers.GetCategorySettings
local IsCategorySplit = BR.Helpers.IsCategorySplit

local LayoutSectionHeader = BR.Options.Helpers.LayoutSectionHeader

local IsMasqueActive = BR.Masque and BR.Masque.IsActive or function()
    return false
end

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local DROPDOWN_EXTRA = BR.Options.Constants.DROPDOWN_EXTRA
local COL_PADDING = BR.Options.Constants.COL_PADDING

local tinsert = table.insert
local abs = math.abs

BR.Options.BuffSections = BR.Options.BuffSections or {}

local APPEARANCE_KEYS = {
    "iconSize",
    "iconWidth",
    "textSize",
    "spacing",
    "iconZoom",
    "borderSize",
    "iconAlpha",
    "textAlpha",
    "growDirection",
}

local GLOW_SNAPSHOT_KEYS = {
    "showExpirationGlow",
    "showMissingGlow",
    "glowType",
    "glowSize",
    "glowPixelLines",
    "glowPixelFrequency",
    "glowPixelLength",
    "glowAutocastParticles",
    "glowAutocastFrequency",
    "glowAutocastScale",
    "glowBorderFrequency",
    "glowProcDuration",
    "glowProcStartAnim",
    "glowProcUseCustomColor",
    "glowXOffset",
    "glowYOffset",
    "missingGlowType",
    "missingGlowSize",
    "missingGlowPixelLines",
    "missingGlowPixelFrequency",
    "missingGlowPixelLength",
    "missingGlowAutocastParticles",
    "missingGlowAutocastFrequency",
    "missingGlowAutocastScale",
    "missingGlowBorderFrequency",
    "missingGlowProcDuration",
    "missingGlowProcStartAnim",
    "missingGlowProcUseCustomColor",
    "missingGlowXOffset",
    "missingGlowYOffset",
}

---Override checkbox + live inheritance state label, added to the layout.
---@param parent table
---@param layout table
---@param opts table Fields: get (fun(): boolean), desc (string tooltip text), onChange (fun(checked: boolean))
local function AddOverrideRow(parent, layout, opts)
    local holder = Components.Checkbox(parent, {
        label = L["Options.Override"],
        get = opts.get,
        tooltip = { title = L["Options.Override"], desc = opts.desc },
        onChange = opts.onChange,
    })

    local stateText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    stateText:SetPoint("LEFT", holder.infoIcon or holder.label, "RIGHT", 10, 0)
    local function refreshState()
        if opts.get() then
            stateText:SetText(L["Options.Override.Overriding"])
            stateText:SetTextColor(1, 0.82, 0)
        else
            stateText:SetText(L["Options.Override.Inherited"])
            stateText:SetTextColor(0.55, 0.55, 0.55)
        end
    end
    refreshState()
    tinsert(BR.RefreshableComponents, { Refresh = refreshState })

    layout:Add(holder, nil, COMPONENT_GAP)
    return holder
end

local function Build(ctx, layout)
    local category = ctx.category
    local parent = ctx.content
    local db = BR.profile

    local function isOverridingAppearance()
        local cs = db.categorySettings and db.categorySettings[category]
        return (cs and cs.useCustomAppearance == true) or false
    end

    local function isOverridingGlow()
        local cs = db.categorySettings and db.categorySettings[category]
        return (cs and cs.useCustomGlow == true) or false
    end

    ---Effective value for a key: the category override when its section is
    ---overriding, else the live global default (BR.Config.GetCategorySetting
    ---resolves the gate). This is what makes inherited controls show real
    ---values instead of blanks.
    local function getEffectiveValue(key, default)
        local val = BR.Config.GetCategorySetting(category, key)
        if val ~= nil then
            return val
        end
        return default
    end

    -- ========================================================================
    -- APPEARANCE
    -- ========================================================================
    LayoutSectionHeader(layout, parent, L["Options.Appearance"])

    AddOverrideRow(parent, layout, {
        get = isOverridingAppearance,
        desc = L["Options.Override.Appearance.Desc"],
        onChange = function(checked)
            if checked then
                -- Snapshot current effective values so enabling the override
                -- doesn't visually change anything.
                local effective = GetCategorySettings(category)
                if not db.categorySettings then
                    db.categorySettings = {}
                end
                if not db.categorySettings[category] then
                    db.categorySettings[category] = {}
                end
                local cs = db.categorySettings[category]
                for _, key in ipairs(APPEARANCE_KEYS) do
                    if cs[key] == nil and effective[key] ~= nil then
                        cs[key] = effective[key]
                    end
                end
                if cs.textColor == nil and effective.textColor then
                    local tc = effective.textColor
                    cs.textColor = { tc[1], tc[2], tc[3] }
                end
            end
            BR.Config.Set("categorySettings." .. category .. ".useCustomAppearance", checked)
            Components.RefreshAll()
        end,
    })

    local dirHolder = Components.DirectionButtons(parent, {
        get = function()
            return getEffectiveValue("growDirection", "CENTER")
        end,
        enabled = function()
            return isOverridingAppearance() and IsCategorySplit(category)
        end,
        disabledReason = function()
            if not isOverridingAppearance() then
                return L["DisabledReason.OverrideSection"]
            end
            return L["DisabledReason.GrowDirection"]
        end,
        onChange = function(dir)
            BR.Config.Set("categorySettings." .. category .. ".growDirection", dir)
        end,
    })
    layout:Add(dirHolder, nil, COMPONENT_GAP + DROPDOWN_EXTRA)

    local function isDimensionsLinked()
        return getEffectiveValue("iconWidth", nil) == nil
    end

    local appFrame = CreateFrame("Frame", nil, parent)
    layout:Add(appFrame, 0)

    local catGrid = Components.AppearanceGrid(appFrame, {
        get = getEffectiveValue,
        set = function(key, value)
            BR.Config.Set("categorySettings." .. category .. "." .. key, value)
        end,
        setMulti = function(changes)
            local prefixed = {}
            for k, v in pairs(changes) do
                prefixed["categorySettings." .. category .. "." .. k] = v
            end
            BR.Config.SetMulti(prefixed)
        end,
        isLinked = isDimensionsLinked,
        onLink = function()
            BR.Config.Set("categorySettings." .. category .. ".iconWidth", nil)
            Components.RefreshAll()
        end,
        onUnlink = function()
            local size = getEffectiveValue("iconSize", 64)
            BR.Config.Set("categorySettings." .. category .. ".iconWidth", size)
            Components.RefreshAll()
        end,
        enabled = isOverridingAppearance,
        masqueCheck = IsMasqueActive,
    })
    appFrame:SetSize(480, catGrid.height)
    layout:Space(catGrid.height)

    -- ========================================================================
    -- GLOW
    -- ========================================================================
    LayoutSectionHeader(layout, parent, L["Options.Glow"])

    AddOverrideRow(parent, layout, {
        get = isOverridingGlow,
        desc = L["Options.Override.Glow.Desc"],
        onChange = function(checked)
            if checked then
                -- Snapshot the effective glow config (enable flags + style)
                -- so enabling the override doesn't visually change anything.
                if not db.categorySettings then
                    db.categorySettings = {}
                end
                if not db.categorySettings[category] then
                    db.categorySettings[category] = {}
                end
                local cs = db.categorySettings[category]
                local glowDefaults = db.defaults or {}
                for _, key in ipairs(GLOW_SNAPSHOT_KEYS) do
                    if cs[key] == nil and glowDefaults[key] ~= nil then
                        cs[key] = glowDefaults[key]
                    end
                end
                for _, colorKey in ipairs({ "glowColor", "missingGlowColor" }) do
                    if cs[colorKey] == nil and glowDefaults[colorKey] then
                        local gc = glowDefaults[colorKey]
                        cs[colorKey] = { gc[1], gc[2], gc[3], gc[4] }
                    end
                end
            end
            BR.Config.Set("categorySettings." .. category .. ".useCustomGlow", checked)
            Components.RefreshAll()
        end,
    })

    -- Shared label column so the Customize button lines up across the two glow
    -- rows regardless of which labels this category shows (their widths differ).
    local glowLabelWidth = Components.MeasureSharedLabelWidth({
        L["Options.ExpiringGlow"],
        L["Options.MissingGlow"],
        L["Options.GlowMissingPets"],
    }, "GameFontHighlightSmall", 0)

    ---One glow row: enable checkbox + Customize button opening the Glow
    ---dialog on that kind. Pet reminders have no expiration concept, so they
    ---get only the missing row (with a pet-specific label).
    local function AddGlowRow(labelText, enableKey, kind)
        local rowHolder = Components.Checkbox(parent, {
            label = labelText,
            get = function()
                return getEffectiveValue(enableKey, true) ~= false
            end,
            enabled = isOverridingGlow,
            disabledReason = L["DisabledReason.OverrideSection"],
            onChange = function(checked)
                BR.Config.Set("categorySettings." .. category .. "." .. enableKey, checked)
                Components.RefreshAll()
            end,
        })

        local customizeBtn = CreateButton(parent, L["Options.Customize"], function()
            BR.Options.Dialogs.Glow.Show(category, kind)
        end)
        customizeBtn:SetPoint("LEFT", rowHolder, "LEFT", rowHolder.labelOffset + glowLabelWidth + 8, 0)
        customizeBtn:SetFrameLevel(rowHolder:GetFrameLevel() + 5)
        customizeBtn:BindEnabled(isOverridingGlow)
        customizeBtn:SetDisabledReason(L["DisabledReason.OverrideSection"])

        layout:Add(rowHolder, nil, COMPONENT_GAP)
    end

    if category == "pet" then
        AddGlowRow(L["Options.GlowMissingPets"], "showMissingGlow", "missing")
    else
        AddGlowRow(L["Options.ExpiringGlow"], "showExpirationGlow", "expiring")
        AddGlowRow(L["Options.MissingGlow"], "showMissingGlow", "missing")
    end

    layout:SetX(COL_PADDING)

    -- This section is last on the page and owns the parent's final height.
    parent:SetHeight(abs(layout:GetY()) + (ctx.appearancePadding or 30))
    if ctx.onAppearanceResize then
        ctx.onAppearanceResize()
    end
end

BR.Options.BuffSections.CustomAppearance = Build
