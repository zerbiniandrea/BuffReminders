local _, BR = ...

-- ============================================================================
-- RUNEFORGE EDITOR (inline section)
-- ============================================================================
-- A 4-tab strip (Blood / Frost 2H / Frost Dual-Wield / Unholy) of accepted
-- runeforge checkboxes, stored per spec. Formerly a standalone dialog opened by
-- a button inside the buff panel; now rendered INLINE at the top of the
-- Runeforge buff panel so the choice is one click away, not two windows deep.
--
-- BuildInline(parent, opts) draws the editor into `parent` at (opts.x, opts.y)
-- within opts.width and returns the vertical space it consumed. The buff panel
-- rebuilds its body (and this editor) on every open, so no persistent-dialog
-- caching is needed. Checkbox holders are handed to opts.registerHolder so the
-- panel can unregister them on teardown.

local L = BR.L
local Components = BR.Components

local UpdateDisplay = BR.Display.Update

local CHECKBOX_HEIGHT = 22
local CHECKBOX_GAP = 3
local TAB_HEIGHT = 24
local TAB_GAP = 2
local TABS_TO_CONTENT_GAP = 10
local DW_LABEL_HEIGHT = 18
local RUNE_LABEL_FONT = "GameFontHighlight"

-- Rune icon textures resolved once (cached across builds).
local cachedRuneIcons = nil
local function GetRuneIcons()
    if cachedRuneIcons then
        return cachedRuneIcons
    end
    cachedRuneIcons = {}
    for _, rune in ipairs(BR.DK_RUNEFORGES) do
        local texture = C_Spell.GetSpellTexture(rune.spellID)
        cachedRuneIcons[rune.enchantID] = texture and { texture } or nil
    end
    return cachedRuneIcons
end

local function EnsureSpecPrefs(specId)
    local db = BR.profile
    if not db.dkRunePreferences then
        db.dkRunePreferences = {}
    end
    if not db.dkRunePreferences[specId] then
        db.dkRunePreferences[specId] = {}
    end
    return db.dkRunePreferences[specId]
end

-- Which tab to open on first show: the player's current spec (dual-wield vs
-- two-handed for Frost), so a DK lands on the runes that matter right now.
local function DefaultTabKey()
    local specId = BR.StateHelpers.GetPlayerSpecId()
    if specId == 251 then
        return BR.BuffState.HasOffHandWeapon() and "frostdw" or "frost2h"
    elseif specId == 252 then
        return "unholy"
    end
    return "blood"
end

---Render the runeforge editor into `parent`. Returns the height consumed (px).
---@param parent table Frame to parent the editor into
---@param opts table { x, y, width, registerHolder? }
---@return number height
local function BuildInline(parent, opts)
    local x, y, width = opts.x, opts.y, opts.width
    local register = opts.registerHolder or function(_) end
    local runeIcons = GetRuneIcons()
    local numRunes = #BR.DK_RUNEFORGES

    local function CreateRuneCheckboxes(content, specId, slot, cx, startY, maxLabelWidth)
        local cy = startY
        for _, rune in ipairs(BR.DK_RUNEFORGES) do
            local enchantID = rune.enchantID
            local holder = Components.Checkbox(content, {
                label = BR.GetSpellName(rune.spellID) or rune.key,
                labelFont = RUNE_LABEL_FONT,
                icons = runeIcons[enchantID],
                get = function()
                    local prefs = EnsureSpecPrefs(specId)
                    return prefs[slot] and prefs[slot][enchantID] or false
                end,
                onChange = function(checked)
                    local prefs = EnsureSpecPrefs(specId)
                    if not prefs[slot] then
                        prefs[slot] = {}
                    end
                    prefs[slot][enchantID] = checked or nil
                    BR.BuffState.Refresh()
                    UpdateDisplay()
                end,
            })
            if maxLabelWidth and holder.label then
                holder.label:SetWidth(maxLabelWidth)
                holder.label:SetWordWrap(false)
            end
            holder:SetPoint("TOPLEFT", cx, cy)
            register(holder)
            cy = cy - (CHECKBOX_HEIGHT + CHECKBOX_GAP)
        end
        return cy
    end

    -- Tab definitions (spec + storage slot per column).
    local _, bloodName = GetSpecializationInfoByID(250)
    local _, frostName = GetSpecializationInfoByID(251)
    local _, unholyName = GetSpecializationInfoByID(252)
    local DK_TABS = {
        { key = "blood", specId = 250, label = bloodName or "Blood" },
        { key = "frost2h", specId = 251, label = (frostName or "Frost") .. " " .. L["Options.RuneTwoHanded"] },
        { key = "frostdw", specId = 251, label = (frostName or "Frost") .. " " .. L["Options.RuneDualWield"] },
        { key = "unholy", specId = 252, label = unholyName or "Unholy" },
    }

    local tabButtons = {}
    local tabContents = {}
    local function SetActiveTab(activeKey)
        for key, tab in pairs(tabButtons) do
            tab:SetActive(key == activeKey)
        end
        for key, content in pairs(tabContents) do
            content:SetShown(key == activeKey)
        end
    end

    -- Tab strip, evenly distributed across the width.
    local numTabs = #DK_TABS
    local tabWidth = (width - (numTabs - 1) * TAB_GAP) / numTabs
    local prevTab, firstTab
    for _, tabDef in ipairs(DK_TABS) do
        local tab = Components.Tab(parent, { label = tabDef.label, width = tabWidth })
        if prevTab then
            tab:SetPoint("LEFT", prevTab, "RIGHT", TAB_GAP, 0)
        else
            tab:SetPoint("TOPLEFT", x, y)
            firstTab = tab
        end
        local key = tabDef.key
        tab:SetScript("OnClick", function()
            SetActiveTab(key)
        end)
        tabButtons[key] = tab
        prevTab = tab
    end
    Components.TabBaseline(parent, firstTab, width)

    -- Content height fits the tallest tab (Frost Dual-Wield adds a column-label
    -- row above its checkboxes); shorter tabs simply leave slack below.
    local contentTop = y - TAB_HEIGHT - TABS_TO_CONTENT_GAP
    local contentH = DW_LABEL_HEIGHT + numRunes * (CHECKBOX_HEIGHT + CHECKBOX_GAP)

    for _, tabDef in ipairs(DK_TABS) do
        local content = CreateFrame("Frame", nil, parent)
        content:SetPoint("TOPLEFT", x, contentTop)
        content:SetSize(width, contentH)
        content:Hide()
        tabContents[tabDef.key] = content

        if tabDef.key == "frostdw" then
            local colWidth = width / 2
            local mhLabel = content:CreateFontString(nil, "OVERLAY", RUNE_LABEL_FONT)
            mhLabel:SetPoint("TOPLEFT", 0, -2)
            mhLabel:SetText("|cffffcc00" .. L["Options.RuneMainHand"] .. "|r")
            local ohLabel = content:CreateFontString(nil, "OVERLAY", RUNE_LABEL_FONT)
            ohLabel:SetPoint("TOPLEFT", colWidth, -2)
            ohLabel:SetText("|cffffcc00" .. L["Options.RuneOffHand"] .. "|r")

            local dwLabelWidth = colWidth - 46
            CreateRuneCheckboxes(content, tabDef.specId, "dw_mainhand", 6, -DW_LABEL_HEIGHT, dwLabelWidth)
            CreateRuneCheckboxes(content, tabDef.specId, "dw_offhand", colWidth + 6, -DW_LABEL_HEIGHT, dwLabelWidth)
        else
            CreateRuneCheckboxes(content, tabDef.specId, "mainhand", 6, -2)
        end
    end

    SetActiveTab(DefaultTabKey())

    local finalY = contentTop - contentH
    return y - finalY
end

BR.Options.Dialogs.Runeforge = { BuildInline = BuildInline }
