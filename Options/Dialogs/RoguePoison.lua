local _, BR = ...

-- ============================================================================
-- ROGUE POISON EDITOR (inline section)
-- ============================================================================
-- Two reorderable columns (Lethal | Non-lethal) of poison checkboxes, top =
-- highest priority. Formerly a standalone dialog opened by a button inside the
-- buff panel; now rendered INLINE at the top of the Rogue Poisons buff panel so
-- the buff's defining choice is one click away, not two windows deep.
--
-- BuildInline(parent, opts) draws the editor into `parent` at (opts.x, opts.y)
-- within opts.width and returns the vertical space it consumed. The buff panel
-- rebuilds its body (and this editor) on every open, so no persistent-dialog
-- caching is needed - each build is fresh. Checkbox holders are handed to
-- opts.registerHolder so the panel can unregister them on teardown.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton

local UpdateDisplay = BR.Display.Update

local tinsert = table.insert
local tsort = table.sort
local ceil = math.ceil
local max = math.max
local huge = math.huge

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

-- Reuse the dropdown chevron texture: rotate +90° for up, -90° for down. Vertex
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
    local colWidth = width / 2
    local colX = { lethal = x, nonLethal = x + colWidth }

    local prefs = EnsureRoguePoisonPrefs()
    local rows = { lethal = {}, nonLethal = {} }

    -- Intro note (wrap-aware).
    local note = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", x, y)
    note:SetWidth(width)
    note:SetJustifyH("LEFT")
    note:SetText(L["Options.RoguePoisonNote"])
    local noteH = max(ceil(note:GetStringHeight()), 12)

    -- Column headers.
    local labelY = y - noteH - NOTE_TO_LABEL_GAP
    local lethalLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lethalLabel:SetPoint("TOPLEFT", colX.lethal, labelY)
    lethalLabel:SetText("|cffffcc00" .. L["Options.PoisonLethal"] .. "|r")
    local nonLethalLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nonLethalLabel:SetPoint("TOPLEFT", colX.nonLethal, labelY)
    nonLethalLabel:SetText("|cffffcc00" .. L["Options.PoisonNonLethal"] .. "|r")

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
        BR.InvalidatePoisonCache()
        BR.BuffState.Refresh()
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

        -- Assign to a local first: C_Spell.GetSpellTexture may return multiple
        -- values, and `{ f() }` as the final table-constructor expression expands
        -- ALL of them - that would render one icon per returned value.
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

        local rowList = rows[category]
        local upBtn = CreateArrowButton(row, "Up", L["Options.PoisonMoveUp"], function()
            local idx = FindRowIndex(rowList, row)
            if idx and idx > 1 then
                Swap(category, idx, idx - 1)
            end
        end)
        upBtn:SetPoint("RIGHT", row, "RIGHT", -22, 0)

        local downBtn = CreateArrowButton(row, "Down", L["Options.PoisonMoveDown"], function()
            local idx = FindRowIndex(rowList, row)
            if idx and idx < #rowList then
                Swap(category, idx, idx + 1)
            end
        end)
        downBtn:SetPoint("LEFT", upBtn, "RIGHT", 2, 0)

        row.upBtn = upBtn
        row.downBtn = downBtn
        row.entry = entry
        return row
    end

    for _, category in ipairs({ "lethal", "nonLethal" }) do
        for _, entry in ipairs(prefs[category]) do
            tinsert(rows[category], CreatePoisonRow(category, entry))
        end
        Reposition(category)
    end

    -- Reset: reorder prefs to defaults + re-enable all, then reorder the live
    -- row frames to match (rows are bound to entry tables by closure; entry
    -- identity survives tsort).
    local function ResetToDefaults()
        for _, category in ipairs({ "lethal", "nonLethal" }) do
            local catDefaults = BR.DEFAULT_POISON_PREFERENCES[category]
            local defaultIndex = {}
            for i, e in ipairs(catDefaults) do
                defaultIndex[e.spellID] = i
            end
            tsort(prefs[category], function(a, b)
                return (defaultIndex[a.spellID] or huge) < (defaultIndex[b.spellID] or huge)
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

    local maxRows = max(#prefs.lethal, #prefs.nonLethal)
    local rowsBottom = rowsTop - maxRows * ROW_HEIGHT

    -- CreateButton auto-sizes to its text (height 22); just anchor it.
    local resetBtn = CreateButton(parent, L["Options.PoisonReset"], ResetToDefaults)
    resetBtn:SetPoint("TOPLEFT", x, rowsBottom - RESET_GAP)

    local finalY = rowsBottom - RESET_GAP - RESET_HEIGHT
    return y - finalY
end

BR.Options.Dialogs.RoguePoison = { BuildInline = BuildInline }
