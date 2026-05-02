local _, BR = ...

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local CreatePanel = BR.CreatePanel

local UpdateDisplay = BR.Display.Update

local tinsert = table.insert
local tsort = table.sort

local roguePoisonDialog = nil

local function EnsureRoguePoisonPrefs()
    local db = BR.profile
    if not db.roguePoisonPreferences then
        db.roguePoisonPreferences = {}
    end
    local prefs = db.roguePoisonPreferences
    for _, cat in ipairs({ "lethal", "nonLethal" }) do
        if not prefs[cat] or #prefs[cat] == 0 then
            prefs[cat] = {}
            for _, seed in ipairs(BR.DEFAULT_POISON_PREFERENCES[cat]) do
                tinsert(prefs[cat], { spellID = seed.spellID, enabled = seed.enabled })
            end
        end
    end
    return prefs
end

local function Show()
    if roguePoisonDialog then
        EnsureRoguePoisonPrefs()
        if roguePoisonDialog.Rebuild then
            roguePoisonDialog:Rebuild()
        end
        Components.RefreshAll()
        roguePoisonDialog:Show()
        return
    end

    local DIALOG_WIDTH = 520
    local DIALOG_HEIGHT = 290
    local MARGIN = 16
    local ROW_HEIGHT = 24
    local LABEL_TO_ROW_GAP = 6 -- gap between column label and first row
    local NOTE_TO_LABEL_GAP = 16 -- gap between note text and column label

    local dialog = CreatePanel("BuffRemindersRoguePoisonDialog", DIALOG_WIDTH, DIALOG_HEIGHT, {
        level = 200,
        dialog = true,
    })

    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText(L["Options.RoguePoisonPreferences"])

    local closeBtn = CreateButton(dialog, "x", function()
        dialog:Hide()
    end)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    local note = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", MARGIN, -36)
    note:SetPoint("TOPRIGHT", -MARGIN, -36)
    note:SetJustifyH("LEFT")
    note:SetText("|cffaaaaaa" .. L["Options.RoguePoisonNote"] .. "|r")

    local colWidth = (DIALOG_WIDTH - MARGIN * 2) / 2

    -- Column labels anchor to the note's bottom so the layout self-adjusts if the note
    -- wraps to an extra line in a longer translation.
    local lethalLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lethalLabel:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -NOTE_TO_LABEL_GAP)
    lethalLabel:SetText("|cffffcc00" .. L["Options.PoisonLethal"] .. "|r")

    local nonLethalLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nonLethalLabel:SetPoint("TOPLEFT", lethalLabel, "TOPLEFT", colWidth, 0)
    nonLethalLabel:SetText("|cffffcc00" .. L["Options.PoisonNonLethal"] .. "|r")

    local categoryLabels = { lethal = lethalLabel, nonLethal = nonLethalLabel }
    local rows = { lethal = {}, nonLethal = {} }

    local function Reposition(category)
        local rowsList = rows[category]
        local anchorLabel = categoryLabels[category]
        for i, row in ipairs(rowsList) do
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", anchorLabel, "BOTTOMLEFT", 0, -LABEL_TO_ROW_GAP - (i - 1) * ROW_HEIGHT)
            row.upBtn:SetEnabled(i > 1)
            row.downBtn:SetEnabled(i < #rowsList)
        end
    end

    local function ApplyChange()
        BR.InvalidatePoisonCache()
        BR.BuffState.Refresh()
        UpdateDisplay()
    end

    local function Swap(category, i, j)
        local prefs = EnsureRoguePoisonPrefs()
        local list = prefs[category]
        list[i], list[j] = list[j], list[i]
        local rowsList = rows[category]
        rowsList[i], rowsList[j] = rowsList[j], rowsList[i]
        Reposition(category)
        ApplyChange()
    end

    local function FindRowIndex(rowsList, row)
        for idx, r in ipairs(rowsList) do
            if r == row then
                return idx
            end
        end
        return nil
    end

    -- Reuse the chevron texture the dropdown uses - rotate 90° for up, -90° for down.
    -- Vertex color tracks state (idle / hover / disabled) to match Dropdown styling.
    local ARROW_IDLE = { 0.7, 0.7, 0.7 }
    local ARROW_HOVER = { 1, 0.82, 0 }
    local ARROW_DISABLED = { 0.4, 0.4, 0.4 }
    local function CreateArrowButton(parent, direction, tooltipTitle, onClick)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(14, 14)
        local arrow = btn:CreateTexture(nil, "ARTWORK")
        arrow:SetAllPoints()
        arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
        arrow:SetRotation(math.rad(direction == "Up" and 90 or -90))
        arrow:SetVertexColor(unpack(ARROW_IDLE))
        btn.arrow = arrow
        local enabled = true
        local function paint()
            if not enabled then
                arrow:SetVertexColor(unpack(ARROW_DISABLED))
            else
                arrow:SetVertexColor(unpack(ARROW_IDLE))
            end
        end
        btn:SetScript("OnEnter", function(self)
            if enabled then
                arrow:SetVertexColor(unpack(ARROW_HOVER))
            end
            BR.ShowTooltip(self, tooltipTitle, nil, "ANCHOR_TOP")
        end)
        btn:SetScript("OnLeave", function()
            paint()
            BR.HideTooltip()
        end)
        btn:SetScript("OnClick", function()
            if enabled then
                onClick()
            end
        end)
        function btn:SetEnabled(v)
            enabled = v and true or false
            paint()
        end
        return btn
    end

    local function CreatePoisonRow(category, entry)
        local row = CreateFrame("Frame", nil, dialog)
        row:SetSize(colWidth - 8, ROW_HEIGHT - 2)

        -- Assign to a local first: C_Spell.GetSpellTexture may return multiple values,
        -- and `{ f() }` as the final expression in a table constructor expands ALL of
        -- them - that would render one icon per returned value.
        local spellIcon = C_Spell.GetSpellTexture(entry.spellID)
        local holder = Components.Checkbox(row, {
            label = BR.GetSpellName(entry.spellID) or tostring(entry.spellID),
            icons = spellIcon and { spellIcon } or nil,
            get = function()
                return entry.enabled ~= false
            end,
            onChange = function(checked)
                entry.enabled = checked
                ApplyChange()
            end,
        })
        holder:SetPoint("LEFT", 0, 0)
        if holder.label then
            holder.label:SetWidth(colWidth - 110)
            holder.label:SetWordWrap(false)
        end

        local rowsList = rows[category]

        local upBtn = CreateArrowButton(row, "Up", L["Options.PoisonMoveUp"], function()
            local idx = FindRowIndex(rowsList, row)
            if idx and idx > 1 then
                Swap(category, idx, idx - 1)
            end
        end)
        upBtn:SetPoint("RIGHT", row, "RIGHT", -22, 0)

        local downBtn = CreateArrowButton(row, "Down", L["Options.PoisonMoveDown"], function()
            local idx = FindRowIndex(rowsList, row)
            if idx and idx < #rowsList then
                Swap(category, idx, idx + 1)
            end
        end)
        downBtn:SetPoint("LEFT", upBtn, "RIGHT", 2, 0)

        row.upBtn = upBtn
        row.downBtn = downBtn
        row.entry = entry
        row.checkbox = holder
        return row
    end

    local function BuildRows()
        -- Tear down any existing rows (re-open path after profile switch, etc.).
        -- Unregister each row's Checkbox holder so stale entries don't accumulate
        -- in the refresh registry across rebuilds.
        for _, category in ipairs({ "lethal", "nonLethal" }) do
            for _, row in ipairs(rows[category]) do
                row:Hide()
                row:SetParent(nil)
                Components.Unregister(row.checkbox)
            end
            rows[category] = {}
        end
        local prefs = EnsureRoguePoisonPrefs()
        for _, category in ipairs({ "lethal", "nonLethal" }) do
            for _, entry in ipairs(prefs[category]) do
                tinsert(rows[category], CreatePoisonRow(category, entry))
            end
            Reposition(category)
        end
    end

    -- Reset: reorder prefs in place and re-enable all, then sync rows to match.
    -- Does NOT rebuild row frames - avoids the rebuild cost since entry tables
    -- survive tsort and row Checkbox holders can be reused.
    local function ResetToDefaults()
        local prefs = EnsureRoguePoisonPrefs()
        for _, category in ipairs({ "lethal", "nonLethal" }) do
            local catDefaults = BR.DEFAULT_POISON_PREFERENCES[category]
            local defaultIndex = {}
            for i, e in ipairs(catDefaults) do
                defaultIndex[e.spellID] = i
            end
            tsort(prefs[category], function(a, b)
                return (defaultIndex[a.spellID] or math.huge) < (defaultIndex[b.spellID] or math.huge)
            end)
            for _, entry in ipairs(prefs[category]) do
                entry.enabled = true
            end
            -- Reorder row frames to match the new prefs order (rows are bound to entry
            -- tables by closure; entry identity survives tsort).
            local rowByEntry = {}
            for _, row in ipairs(rows[category]) do
                rowByEntry[row.entry] = row
            end
            local newRows = {}
            for _, entry in ipairs(prefs[category]) do
                local row = rowByEntry[entry]
                if row then
                    tinsert(newRows, row)
                end
            end
            rows[category] = newRows
            Reposition(category)
        end
        Components.RefreshAll()
        ApplyChange()
    end

    local resetBtn = CreateButton(dialog, L["Options.PoisonReset"], ResetToDefaults)
    resetBtn:SetPoint("BOTTOMLEFT", MARGIN, MARGIN)

    function dialog:Rebuild()
        BuildRows()
    end
    BuildRows()

    roguePoisonDialog = dialog
    dialog:Show()
end

BR.Options.Dialogs.RoguePoison = { Show = Show }
