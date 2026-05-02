local _, BR = ...

-- ============================================================================
-- BUFF PAGE SECTION: Custom Appearance
-- ============================================================================
-- Master toggle that gates per-category overrides for direction, the
-- AppearanceGrid (size/zoom/border/spacing/alpha/text/color), and glow
-- controls. Glow layout varies per category (pet, custom, standard).

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

local function Build(ctx, layout)
    local category = ctx.category
    local parent = ctx.content
    local db = BR.profile

    local function isCustomAppearanceEnabled()
        return db.categorySettings
            and db.categorySettings[category]
            and db.categorySettings[category].useCustomAppearance == true
    end

    local function isCustomGlowEnabled()
        return isCustomAppearanceEnabled() and db.categorySettings[category].useCustomGlow == true
    end

    local function snapshotGlowDefaults()
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

    LayoutSectionHeader(layout, parent, L["Options.CustomAppearance"])

    layout:SetX(COL_PADDING)
    local useCustomAppHolder = Components.Checkbox(parent, {
        label = L["Options.CustomAppearance"],
        get = function()
            return db.categorySettings
                and db.categorySettings[category]
                and db.categorySettings[category].useCustomAppearance == true
        end,
        tooltip = {
            title = L["Options.CustomAppearance"],
            desc = L["Options.CustomAppearance.Desc"],
        },
        onChange = function(checked)
            if not db.categorySettings then
                db.categorySettings = {}
            end
            if not db.categorySettings[category] then
                db.categorySettings[category] = {}
            end
            if checked then
                local effective = GetCategorySettings(category)
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
    layout:Add(useCustomAppHolder, nil, COMPONENT_GAP)

    -- Capture layout Y just before the conditional appearance block so we can
    -- collapse the page height when the toggle is off (otherwise the layout
    -- still reserves dirHolder + grid + glow rows worth of empty space, which
    -- makes the page scroll for nothing).
    local yBeforeBlock = layout:GetY()

    layout:SetX(COL_PADDING + 10)
    local dirHolder = Components.DirectionButtons(parent, {
        get = function()
            local catSettings = db.categorySettings and db.categorySettings[category]
            local val = catSettings and catSettings.growDirection
            if val ~= nil then
                return val
            end
            return db.defaults and db.defaults.growDirection or "CENTER"
        end,
        enabled = function()
            return isCustomAppearanceEnabled() and IsCategorySplit(category)
        end,
        onChange = function(dir)
            BR.Config.Set("categorySettings." .. category .. ".growDirection", dir)
        end,
    })
    layout:Add(dirHolder, nil, COMPONENT_GAP + DROPDOWN_EXTRA)

    local function getCatOwnValue(key, default)
        local catSettings = db.categorySettings and db.categorySettings[category]
        local val = catSettings and catSettings[key]
        if val ~= nil then
            return val
        end
        return db.defaults and db.defaults[key] or default
    end

    local function isCatDimensionsLinked()
        local cs = db.categorySettings and db.categorySettings[category]
        return not cs or cs.iconWidth == nil
    end

    layout:SetX(COL_PADDING + 10)
    local appFrame = CreateFrame("Frame", nil, parent)
    appFrame:SetSize(480, 50)
    layout:Add(appFrame, 0)

    local catGrid = Components.AppearanceGrid(appFrame, {
        get = getCatOwnValue,
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
        isLinked = isCatDimensionsLinked,
        onLink = function()
            BR.Config.Set("categorySettings." .. category .. ".iconWidth", nil)
            Components.RefreshAll()
        end,
        onUnlink = function()
            local size = getCatOwnValue("iconSize", 64)
            BR.Config.Set("categorySettings." .. category .. ".iconWidth", size)
            Components.RefreshAll()
        end,
        enabled = isCustomAppearanceEnabled,
        masqueCheck = IsMasqueActive,
    })

    local glowRowY = -catGrid.height
    local gridHeight

    if category == "pet" then
        local petGlowHolder = Components.Checkbox(appFrame, {
            label = L["Options.GlowMissingPets"],
            get = function()
                return getCatOwnValue("showMissingGlow", true) ~= false
            end,
            enabled = isCustomAppearanceEnabled,
            onChange = function(checked)
                BR.Config.Set("categorySettings." .. category .. ".showMissingGlow", checked)
                Components.RefreshAll()
            end,
        })
        petGlowHolder:SetPoint("TOPLEFT", 0, glowRowY)

        local petCustomGlowHolder = Components.Checkbox(appFrame, {
            label = L["Options.CustomGlowStyle"],
            get = function()
                return isCustomGlowEnabled()
            end,
            enabled = isCustomAppearanceEnabled,
            onChange = function(checked)
                if checked then
                    snapshotGlowDefaults()
                end
                BR.Config.Set("categorySettings." .. category .. ".useCustomGlow", checked)
                Components.RefreshAll()
            end,
        })
        petCustomGlowHolder:SetPoint("TOPLEFT", 0, glowRowY - 24)

        local petGlowSettingsBtn = CreateButton(appFrame, L["Options.Customize"], function()
            BR.Options.Dialogs.Glow.Show(category, "missing")
        end)
        petGlowSettingsBtn:SetPoint("LEFT", petCustomGlowHolder.label, "RIGHT", 8, 0)
        petGlowSettingsBtn:SetFrameLevel(petCustomGlowHolder:GetFrameLevel() + 5)

        local function updatePetGlowBtnEnabled()
            local enabled = isCustomGlowEnabled()
            if enabled then
                petGlowSettingsBtn:Enable()
                petGlowSettingsBtn:SetAlpha(1)
            else
                petGlowSettingsBtn:Disable()
                petGlowSettingsBtn:SetAlpha(0.4)
            end
        end
        updatePetGlowBtnEnabled()
        tinsert(BR.RefreshableComponents, { Refresh = updatePetGlowBtnEnabled })

        gridHeight = catGrid.height + 48
    elseif category == "custom" then
        local customMissGlowHolder = Components.Checkbox(appFrame, {
            label = L["Options.Glow"],
            get = function()
                return getCatOwnValue("showMissingGlow", true) ~= false
            end,
            enabled = isCustomAppearanceEnabled,
            onChange = function(checked)
                BR.Config.Set("categorySettings." .. category .. ".showMissingGlow", checked)
                Components.RefreshAll()
            end,
        })
        customMissGlowHolder:SetPoint("TOPLEFT", 0, glowRowY)

        local customGlowStyleHolder = Components.Checkbox(appFrame, {
            label = L["Options.CustomGlowStyle"],
            get = function()
                return isCustomGlowEnabled()
            end,
            enabled = isCustomAppearanceEnabled,
            onChange = function(checked)
                if checked then
                    snapshotGlowDefaults()
                end
                BR.Config.Set("categorySettings." .. category .. ".useCustomGlow", checked)
                Components.RefreshAll()
            end,
        })
        customGlowStyleHolder:SetPoint("TOPLEFT", 0, glowRowY - 24)

        local customGlowBtn = CreateButton(appFrame, L["Options.Customize"], function()
            BR.Options.Dialogs.Glow.Show(category)
        end)
        customGlowBtn:SetPoint("LEFT", customGlowStyleHolder.label, "RIGHT", 8, 0)
        customGlowBtn:SetFrameLevel(customGlowStyleHolder:GetFrameLevel() + 5)

        local function updateCustomGlowBtnEnabled()
            local enabled = isCustomGlowEnabled()
            if enabled then
                customGlowBtn:Enable()
                customGlowBtn:SetAlpha(1)
            else
                customGlowBtn:Disable()
                customGlowBtn:SetAlpha(0.4)
            end
        end
        updateCustomGlowBtnEnabled()
        tinsert(BR.RefreshableComponents, { Refresh = updateCustomGlowBtnEnabled })

        gridHeight = catGrid.height + 48
    else
        local thresholdHolder = Components.Slider(appFrame, {
            label = L["Options.Expiration"],
            labelWidth = 56,
            min = 0,
            max = 45,
            step = 5,
            formatValue = function(val)
                return val == 0 and L["Options.Off"] or (val .. " " .. L["Options.Min"])
            end,
            get = function()
                return getCatOwnValue("expirationThreshold", 15)
            end,
            enabled = isCustomAppearanceEnabled,
            onChange = function(val)
                BR.Config.Set("categorySettings." .. category .. ".expirationThreshold", val)
            end,
        })
        thresholdHolder:SetPoint("TOPLEFT", 0, glowRowY)

        local glowCheckHolder = Components.Checkbox(appFrame, {
            label = L["Options.Glow"],
            get = function()
                local ex = getCatOwnValue("showExpirationGlow", true) ~= false
                local miss = getCatOwnValue("showMissingGlow", true) ~= false
                return ex or miss
            end,
            enabled = isCustomAppearanceEnabled,
            onChange = function(checked)
                BR.Config.Set("categorySettings." .. category .. ".showExpirationGlow", checked)
                BR.Config.Set("categorySettings." .. category .. ".showMissingGlow", checked)
                Components.RefreshAll()
            end,
        })
        glowCheckHolder:SetPoint("TOPLEFT", 0, glowRowY - 24)

        local customGlowHolder = Components.Checkbox(appFrame, {
            label = L["Options.CustomGlowStyle"],
            get = function()
                return isCustomGlowEnabled()
            end,
            enabled = isCustomAppearanceEnabled,
            onChange = function(checked)
                if checked then
                    snapshotGlowDefaults()
                end
                BR.Config.Set("categorySettings." .. category .. ".useCustomGlow", checked)
                Components.RefreshAll()
            end,
        })
        customGlowHolder:SetPoint("TOPLEFT", 0, glowRowY - 48)

        local glowSettingsBtn = CreateButton(appFrame, L["Options.Customize"], function()
            BR.Options.Dialogs.Glow.Show(category)
        end)
        glowSettingsBtn:SetPoint("LEFT", customGlowHolder.label, "RIGHT", 8, 0)
        glowSettingsBtn:SetFrameLevel(customGlowHolder:GetFrameLevel() + 5)

        local function updateGlowBtnEnabled()
            local enabled = isCustomGlowEnabled()
            if enabled then
                glowSettingsBtn:Enable()
                glowSettingsBtn:SetAlpha(1)
            else
                glowSettingsBtn:Disable()
                glowSettingsBtn:SetAlpha(0.4)
            end
        end
        updateGlowBtnEnabled()
        tinsert(BR.RefreshableComponents, { Refresh = updateGlowBtnEnabled })

        gridHeight = catGrid.height + 72
    end

    layout:Space(gridHeight)
    layout:SetX(COL_PADDING)

    -- Capture layout Y after the conditional block so we know the expanded
    -- footprint. This section MUST be the last one on the page — it owns the
    -- parent's final height (and reverts the conditional reservation when the
    -- toggle is off, instead of leaving empty scrollable space below).
    local yAfterBlock = layout:GetY()
    local pad = ctx.appearancePadding or 30

    local function applyParentHeight()
        local y = isCustomAppearanceEnabled() and yAfterBlock or yBeforeBlock
        parent:SetHeight(abs(y) + pad)
        if ctx.onAppearanceResize then
            ctx.onAppearanceResize()
        end
    end

    local function updateAppearanceVisibility()
        local show = isCustomAppearanceEnabled()
        if show then
            dirHolder:Show()
            appFrame:Show()
        else
            dirHolder:Hide()
            appFrame:Hide()
        end
        applyParentHeight()
    end
    tinsert(BR.RefreshableComponents, { Refresh = updateAppearanceVisibility })
    updateAppearanceVisibility()
end

BR.Options.BuffSections.CustomAppearance = Build
