local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- ROGUE POISON EDITOR (inline section)
-- ============================================================================
-- One reorderable column of poison checkboxes per BR.BuffData.poisonColumns entry. The
-- top row is the highest priority.
--
-- BuildInline(parent, opts) draws the editor into `parent` at (opts.x, opts.y)
-- within opts.width and returns the vertical space it consumed. The buff panel
-- rebuilds its body (and this editor) on every open, so the editor holds no
-- widget state between builds. Checkbox holders go to opts.registerHolder, so the
-- panel can unregister them on teardown.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton

local UpdateDisplay = BR.Display.Update

local tinsert = table.insert

local ROW_HEIGHT = 24
local NOTE_TO_LABEL_GAP = 8
local LABEL_TO_ROW_GAP = 18
local RESET_GAP = 6
local RESET_HEIGHT = 22

local ARROW_IDLE = { 0.7, 0.7, 0.7 }
local ARROW_HOVER = BR.Colors.Accent
local ARROW_DISABLED = { 0.4, 0.4, 0.4 }

local function EnsureRoguePoisonPrefs()
    local db = BR.profile
    if not db.roguePoisonPreferences then
        db.roguePoisonPreferences = {}
    end
    local prefs = db.roguePoisonPreferences
    for _, column in ipairs(BR.BuffData.poisonColumns) do
        local cat = column.key
        if not prefs[cat] or #prefs[cat] == 0 then
            prefs[cat] = {}
            for _, seed in ipairs(BR.BuffData.poisonDefaults[cat]) do
                tinsert(prefs[cat], { spellID = seed.spellID, enabled = seed.enabled })
            end
        end
    end
    return prefs
end

-- Reuse the dropdown chevron texture: rotate +90 deg for up, -90 deg for down. Vertex
-- color tracks state (idle / hover / disabled) to match Dropdown styling.
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
        arrow:SetVertexColor(unpack(enabled and ARROW_IDLE or ARROW_DISABLED))
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

---Render the poison editor into `parent`. Returns the height consumed (px).
---@param parent table Frame to parent the editor into
---@param opts table { x, y, width, registerHolder? }
---@return number height
local function BuildInline(parent, opts)
    local x, y, width = opts.x, opts.y, opts.width
    local register = opts.registerHolder or function(_) end
    local columns = BR.BuffData.poisonColumns
    local colWidth = width / #columns
    local colX, rows = {}, {}
    for i, column in ipairs(columns) do
        colX[column.key] = x + (i - 1) * colWidth
        rows[column.key] = {}
    end

    local prefs = EnsureRoguePoisonPrefs()

    local note = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", x, y)
    note:SetWidth(width)
    note:SetJustifyH("LEFT")
    note:SetText(L["Options.RoguePoisonNote"])
    local noteH = math.max(math.ceil(note:GetStringHeight()), 12)

    local labelY = y - noteH - NOTE_TO_LABEL_GAP
    for _, column in ipairs(columns) do
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("TOPLEFT", colX[column.key], labelY)
        label:SetText("|cffffcc00" .. column.label .. "|r")
    end

    local rowsTop = labelY - LABEL_TO_ROW_GAP

    local function Reposition(category)
        local list = rows[category]
        for i, row in ipairs(list) do
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", parent, "TOPLEFT", colX[category], rowsTop - (i - 1) * ROW_HEIGHT)
            row.upBtn:SetEnabled(i > 1)
            row.downBtn:SetEnabled(i < #list)
        end
    end

    local function ApplyChange()
        -- Nil on a client whose poison reminder keeps no cache.
        if BR.InvalidatePoisonCache then
            BR.InvalidatePoisonCache()
        end
        UpdateDisplay()
        -- Repaint the All Buffs row: its trailing link flips gold <-> orange as
        -- the poison selection goes set <-> unset.
        Components.RefreshAll()
    end

    local function Swap(category, i, j)
        local list = prefs[category]
        list[i], list[j] = list[j], list[i]
        local rowList = rows[category]
        rowList[i], rowList[j] = rowList[j], rowList[i]
        Reposition(category)
        ApplyChange()
    end

    local function FindRowIndex(rowList, row)
        for idx, r in ipairs(rowList) do
            if r == row then
                return idx
            end
        end
        return nil
    end

    local function CreatePoisonRow(category, entry)
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(colWidth - 8, ROW_HEIGHT - 2)

        -- Assign to a local first: C_Spell.GetSpellTexture can return more than
        -- one value. `{ f() }` as the final table-constructor expression expands
        -- ALL of them, and each value renders one icon.
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
        register(holder)

        -- ResetToDefaults replaces rows[category], so each click reads it again.
        local upBtn = CreateArrowButton(row, "Up", L["Options.PoisonMoveUp"], function()
            local idx = FindRowIndex(rows[category], row)
            if idx and idx > 1 then
                Swap(category, idx, idx - 1)
            end
        end)
        upBtn:SetPoint("RIGHT", row, "RIGHT", -22, 0)

        local downBtn = CreateArrowButton(row, "Down", L["Options.PoisonMoveDown"], function()
            local idx = FindRowIndex(rows[category], row)
            if idx and idx < #rows[category] then
                Swap(category, idx, idx + 1)
            end
        end)
        downBtn:SetPoint("LEFT", upBtn, "RIGHT", 2, 0)

        row.upBtn = upBtn
        row.downBtn = downBtn
        row.entry = entry
        return row
    end

    local maxRows = 0
    for _, column in ipairs(columns) do
        local category = column.key
        for _, entry in ipairs(prefs[category]) do
            tinsert(rows[category], CreatePoisonRow(category, entry))
        end
        Reposition(category)
        maxRows = math.max(maxRows, #prefs[category])
    end

    -- Rows bind to their entry table by closure, and entry identity survives
    -- table.sort. The row frames reorder to match the sorted prefs.
    local function ResetToDefaults()
        for _, column in ipairs(columns) do
            local category = column.key
            local catDefaults = BR.BuffData.poisonDefaults[category]
            local defaultIndex = {}
            for i, e in ipairs(catDefaults) do
                defaultIndex[e.spellID] = i
            end
            table.sort(prefs[category], function(a, b)
                return (defaultIndex[a.spellID] or math.huge) < (defaultIndex[b.spellID] or math.huge)
            end)
            for _, entry in ipairs(prefs[category]) do
                entry.enabled = true
            end
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
        -- ApplyChange re-syncs every refreshable (poison checkboxes + the row).
        ApplyChange()
    end

    local rowsBottom = rowsTop - maxRows * ROW_HEIGHT

    -- CreateButton auto-sizes to its text (height 22); just anchor it.
    local resetBtn = CreateButton(parent, L["Options.PoisonReset"], ResetToDefaults)
    resetBtn:SetPoint("TOPLEFT", x, rowsBottom - RESET_GAP)

    local finalY = rowsBottom - RESET_GAP - RESET_HEIGHT
    return y - finalY
end

BR.Options.Dialogs.RoguePoison = {
    BuildInline = BuildInline,
    Name = L["BuffRow.Option.Poisons"],
    Width = 468,
}
