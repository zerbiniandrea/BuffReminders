local _, BR = ...

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local CreatePanel = BR.CreatePanel

local UpdateDisplay = BR.Display.Update

local runeforgeDialog = nil

-- Resolve rune icon textures once (cached across dialog opens)
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

local function Show()
    if runeforgeDialog then
        Components.RefreshAll()
        runeforgeDialog:Show()
        return
    end

    local DIALOG_WIDTH = 560
    local DIALOG_HEIGHT = 280
    local MARGIN = 16
    local CHECKBOX_HEIGHT = 22
    local CHECKBOX_GAP = 3
    local RUNE_LABEL_FONT = "GameFontHighlight"

    local dialog = CreatePanel("BuffRemindersRuneforgeDialog", DIALOG_WIDTH, DIALOG_HEIGHT, {
        level = 200,
        dialog = true,
    })

    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText(L["Options.RuneforgePreferences"])

    local closeBtn = CreateButton(dialog, "x", function()
        dialog:Hide()
    end)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    local runeIcons = GetRuneIcons()

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

    -- Helper: create rune checkboxes for a slot
    local function CreateRuneCheckboxes(parent, specId, slot, x, startY, maxLabelWidth)
        local y = startY
        for _, rune in ipairs(BR.DK_RUNEFORGES) do
            local enchantID = rune.enchantID
            local runeName = BR.GetSpellName(rune.spellID) or rune.key
            local runeHolder = Components.Checkbox(parent, {
                label = runeName,
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
            if maxLabelWidth and runeHolder.label then
                runeHolder.label:SetWidth(maxLabelWidth)
                runeHolder.label:SetWordWrap(false)
            end
            runeHolder:SetPoint("TOPLEFT", x, y)
            y = y - (CHECKBOX_HEIGHT + CHECKBOX_GAP)
        end
        return y
    end

    -- 4 top-level tabs: Blood, Frost 2H, Frost DW, Unholy
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
            if key == activeKey then
                content:Show()
            else
                content:Hide()
            end
        end
    end

    -- Build tab buttons (evenly distributed across dialog width)
    local tabGap = 2
    local totalTabWidth = DIALOG_WIDTH - MARGIN * 2
    local numTabs = #DK_TABS
    local tabWidth = (totalTabWidth - (numTabs - 1) * tabGap) / numTabs

    local prevTab = nil
    for _, tabDef in ipairs(DK_TABS) do
        local tab = Components.Tab(dialog, { label = tabDef.label, width = tabWidth })
        if prevTab then
            tab:SetPoint("LEFT", prevTab, "RIGHT", tabGap, 0)
        else
            tab:SetPoint("TOPLEFT", MARGIN, -36)
        end
        local key = tabDef.key
        tab:SetScript("OnClick", function()
            SetActiveTab(key)
        end)
        tabButtons[key] = tab
        prevTab = tab
    end

    local contentWidth = DIALOG_WIDTH - MARGIN * 2

    -- Build tab content
    for _, tabDef in ipairs(DK_TABS) do
        local content = CreateFrame("Frame", nil, dialog)
        content:SetPoint("TOPLEFT", MARGIN, -60)
        content:SetPoint("BOTTOMRIGHT", -MARGIN, MARGIN)
        content:Hide()
        tabContents[tabDef.key] = content

        local y = -6

        if tabDef.key == "frostdw" then
            -- Frost DW: two columns (MH | OH)
            local colWidth = contentWidth / 2

            local mhLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            mhLabel:SetPoint("TOPLEFT", 0, y)
            mhLabel:SetText("|cffffcc00" .. L["Options.RuneMainHand"] .. "|r")

            local ohLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            ohLabel:SetPoint("TOPLEFT", colWidth, y)
            ohLabel:SetText("|cffffcc00" .. L["Options.RuneOffHand"] .. "|r")

            local dwLabelWidth = colWidth - 46
            CreateRuneCheckboxes(content, tabDef.specId, "dw_mainhand", 6, y - 16, dwLabelWidth)
            CreateRuneCheckboxes(content, tabDef.specId, "dw_offhand", colWidth + 6, y - 16, dwLabelWidth)
        else
            -- Blood / Frost 2H / Unholy: single column
            CreateRuneCheckboxes(content, tabDef.specId, "mainhand", 6, y)
        end
    end

    SetActiveTab("blood")

    runeforgeDialog = dialog
    dialog:Show()
end

BR.Options.Dialogs.Runeforge = { Show = Show }
