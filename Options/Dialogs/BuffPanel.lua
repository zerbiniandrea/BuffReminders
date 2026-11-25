local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- PER-BUFF SETTINGS: DRAWER + EDITOR
-- ============================================================================
-- Opened from an All Buffs row link. There are two surfaces.
--   * DRAWER - a popover anchored beside the row. It holds Sound, Detach, Show
--     where it applies, plus the buff's small special controls inline.
--   * EDITOR - a focused panel for the two buffs whose special section is a
--     full editor (poison priority columns, runeforge-per-spec tabs).
-- Enable is on neither surface: the All Buffs row checkbox owns it.
-- Chrome is built once, the body per open. Teardown must unregister every
-- holder that the body created. The drawer dismisses on click-away or ESC.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local Sounds = BR.Sounds

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

local tinsert = table.insert
local wipe = wipe
local Theme = BR.Theme
local CELL_EDGE = Theme.cell.edge
local CELL_EDGE_SELECTED = Theme.cell.selected
local CELL_CHECK = Theme.cell.check

-- Focused-editor default width. A section that names an editor module gets the
-- width that module declares instead.
local PANEL_W = 378

local drawer, drawerBody, drawerIcon, drawerTitle, catcher
local editor, editorBody
-- Active build surface. A build must first point body, bodyW and bodyHolders at
-- the drawer body or at the editor body. The shared row helpers write to these.
local body
local bodyW = 0
local bodyHolders = {}
local drawerHolders = {}
local editorHolders = {}

-- ============================================================================
-- SHOW (ready check) MODELS
-- ============================================================================
-- Each model gives the values of the Show dropdown, ordered from least to most visible.

---@class ShowOption
---@field value string
---@field label string
---@field desc string

---@class ShowModel
---@field options ShowOption[]
---@field get fun(): string
---@field set fun(value: string)
---@field note? string

local SHOW_READY_CHECK =
    { value = "readyCheck", label = L["BuffPanel.Show.ReadyCheck"], desc = L["BuffPanel.Show.ReadyCheck.Desc"] }
local SHOW_READY_CHECK_SOLO = {
    value = "readyCheckSolo",
    label = L["BuffPanel.Show.ReadyCheckSolo"],
    desc = L["BuffPanel.Show.ReadyCheckSolo.Desc"],
}
local SHOW_CASTER = { value = "casterOnly", label = L["BuffPanel.Show.Caster"], desc = L["BuffPanel.Show.Caster.Desc"] }
local SHOW_ALWAYS = { value = "always", label = L["BuffPanel.Show.Always"], desc = L["BuffPanel.Show.Always.Desc"] }

-- A buff with no mode setting of its own. readyCheckOnlyOverrides[key]: nil = ready check only, false = always.
---@return ShowModel
local function MakePerBuffShowModel(key)
    return {
        options = { SHOW_READY_CHECK, SHOW_ALWAYS },
        get = function()
            local overrides = BR.profile.readyCheckOnlyOverrides
            return overrides and overrides[key] == false and "always" or "readyCheck"
        end,
        set = function(value)
            local override
            if value == "always" then
                override = false
            end
            BR.Config.Set("readyCheckOnlyOverrides." .. key, override)
        end,
    }
end

---@param configKey string
---@param options ShowOption[]
---@return ShowModel
local function MakeModeShowModel(configKey, options)
    local path = "defaults." .. configKey
    return {
        options = options,
        get = function()
            return BR.Config.Get(path)
        end,
        set = function(value)
            BR.Config.Set(path, value)
        end,
    }
end

local SHOW_MODELS = {
    healthstone = function()
        return MakeModeShowModel("healthstoneVisibility", { SHOW_READY_CHECK, SHOW_CASTER, SHOW_ALWAYS })
    end,
    ---@param info table
    soulstone = function(info)
        -- An "ally" buff never shows solo, so the solo value needs a target that includes the player.
        local options = info.target == "ally" and { SHOW_READY_CHECK, SHOW_CASTER, SHOW_ALWAYS }
            or { SHOW_READY_CHECK, SHOW_READY_CHECK_SOLO, SHOW_CASTER, SHOW_ALWAYS }
        return MakeModeShowModel("soulstoneVisibility", options)
    end,
    -- The mana gem shares the Healthstone value. Its own list has no caster value,
    -- so a caster value reads as a ready check and survives a ready check choice.
    manaGem = function()
        local model = MakeModeShowModel("healthstoneVisibility", { SHOW_READY_CHECK, SHOW_ALWAYS })
        local get, set = model.get, model.set
        model.get = function()
            return get() == "always" and "always" or "readyCheck"
        end
        model.set = function(value)
            if value ~= model.get() then
                set(value)
            end
        end
        model.note = L["BuffPanel.ShowSharedWithHealthstone"]
        return model
    end,
}

-- Drawer / editor geometry.
local DRAWER_W = 300
local DRAWER_BODY_X = 14
local DRAWER_BODY_TOP = 40
local DRAWER_LABEL_W = 52
local DRAWER_FIELD_W = 178
local EDITOR_BODY_X = 16
local EDITOR_BODY_TOP = 44

-- ============================================================================
-- BUFF-SPECIFIC SECTIONS
-- ============================================================================
-- Each builder appends this buff's extra controls to the body layout.

local function AddSpecialCheckbox(layout, opts)
    local holder = Components.Checkbox(body, {
        label = opts.label,
        get = opts.get,
        tooltip = opts.tooltip,
        enabled = opts.enabled,
        disabledReason = opts.disabledReason,
        onChange = opts.onChange,
    })
    tinsert(bodyHolders, holder)
    layout:Add(holder, nil, COMPONENT_GAP)
    return holder
end

local GRID_ROWS = {
    { key = "world", label = L["BuffPanel.WarlockDemon.World"] },
    {
        key = "dungeon",
        label = L["BuffPanel.WarlockDemon.Dungeon"],
        desc = BR.ByClient({ retail = L["BuffPanel.WarlockDemon.Dungeon.Desc"], forever = BR.NONE }),
    },
    { key = "raid", label = L["BuffPanel.WarlockDemon.Raid"] },
    { key = "pvp", label = L["BuffPanel.WarlockDemon.PvP"] },
}
local GRID_CELL = 24
local GRID_GAP = 4
local GRID_INFO_ICON = 14

-- Class-colored header above controls that apply to one class only.
local function AddClassHeader(layout, classToken)
    local color = C_ClassColor.GetClassColor(classToken)
    local r, g, b = 1, 1, 1
    if color then
        r, g, b = color:GetRGB()
    end

    local head = CreateFrame("Frame", nil, body)
    head:SetSize(bodyW, 14)
    local name = head:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetPoint("LEFT")
    name:SetText(LOCALIZED_CLASS_NAMES_MALE[classToken] or classToken)
    name:SetTextColor(r, g, b)
    local rule = head:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("LEFT", name, "RIGHT", 6, 0)
    rule:SetPoint("RIGHT", head, "RIGHT")
    rule:SetColorTexture(r, g, b, 0.25)
    layout:Add(head, 14, COMPONENT_GAP)
end

---@class ContentGridChoice
---@field key string Saved-variable key in the grid rows
---@field label string
---@field icon number?

-- One row of choice toggles per content row of the grid in profile.defaults[setting].
---@param layout table
---@param setting string
---@param hintText string
---@param choices ContentGridChoice[]
local function AddContentGrid(layout, setting, hintText, choices)
    local IsContentChoiceAllowed = BR.Visibility.IsContentChoiceAllowed
    local hint = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetWidth(bodyW)
    hint:SetJustifyH("LEFT")
    hint:SetText(hintText)
    layout:AddText(hint, math.max(12, math.ceil(hint:GetStringHeight())), GRID_GAP + 2)

    local rowLabels = {}
    for i, row in ipairs(GRID_ROWS) do
        rowLabels[i] = row.label
    end
    local labelW = Components.MeasureSharedLabelWidth(rowLabels, "GameFontHighlightSmall", DRAWER_LABEL_W)
    for _, row in ipairs(GRID_ROWS) do
        if row.desc then
            local w = Components.MeasureSharedLabelWidth({ row.label }, "GameFontHighlightSmall", 0)
            labelW = math.max(labelW, w + GRID_INFO_ICON)
        end
    end

    local holder = CreateFrame("Frame", nil, body)
    holder:SetSize(bodyW, #GRID_ROWS * (GRID_CELL + GRID_GAP) - GRID_GAP)
    local cells = {}

    function holder:Refresh()
        for _, cell in ipairs(cells) do
            local selected = IsContentChoiceAllowed(setting, cell.row, cell.choiceKey)
            cell.icon:SetDesaturated(not selected)
            cell.icon:SetAlpha(selected and 1 or 0.45)
            cell.check:SetShown(selected)
            cell:SetBackdropBorderColor(unpack(selected and CELL_EDGE_SELECTED or CELL_EDGE))
        end
    end

    for r, row in ipairs(GRID_ROWS) do
        local y = -(r - 1) * (GRID_CELL + GRID_GAP)
        local label = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", holder, "TOPLEFT", 0, y - GRID_CELL / 2)
        label:SetWidth(labelW)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        label:SetText(row.label)
        if row.desc then
            local info = holder:CreateTexture(nil, "ARTWORK")
            info:SetSize(GRID_INFO_ICON, GRID_INFO_ICON)
            info:SetAtlas("QuestNormal")
            info:SetPoint("LEFT", holder, "TOPLEFT", label:GetStringWidth() + 2, y - GRID_CELL / 2)
            local hit = CreateFrame("Frame", nil, holder)
            hit:SetPoint("TOPLEFT", label, "TOPLEFT")
            hit:SetPoint("BOTTOMRIGHT", info, "BOTTOMRIGHT")
            hit:EnableMouse(true)
            hit:SetScript("OnEnter", function(self)
                BR.ShowTooltip(self, row.label, row.desc, "ANCHOR_TOP")
            end)
            hit:SetScript("OnLeave", BR.HideTooltip)
        end

        for c, choice in ipairs(choices) do
            local cell = CreateFrame("Button", nil, holder, "BackdropTemplate")
            cell:SetSize(GRID_CELL, GRID_CELL)
            cell:SetPoint("TOPLEFT", labelW + GRID_GAP + (c - 1) * (GRID_CELL + GRID_GAP), y)
            cell:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            cell.icon = BR.CreateBuffIcon(cell, GRID_CELL - 2, choice.icon)
            cell.icon:SetPoint("CENTER")
            cell.check = cell:CreateTexture(nil, "OVERLAY")
            cell.check:SetSize(14, 14)
            cell.check:SetPoint("BOTTOMRIGHT", 4, -4)
            cell.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            cell.check:SetVertexColor(unpack(CELL_CHECK))
            cell.row = row.key
            cell.choiceKey = choice.key
            cell:SetScript("OnClick", function()
                local allowed = IsContentChoiceAllowed(setting, row.key, choice.key)
                BR.Config.Set("defaults." .. setting .. "." .. row.key .. "." .. choice.key, not allowed)
                Components.RefreshAll()
            end)
            cell:SetScript("OnEnter", function(self)
                self.icon:SetAlpha(1)
                BR.ShowTooltip(self, choice.label, nil, "ANCHOR_TOP")
            end)
            cell:SetScript("OnLeave", function()
                BR.HideTooltip()
                holder:Refresh()
            end)
            cells[#cells + 1] = cell
        end
    end

    holder:Refresh()
    tinsert(BR.RefreshableComponents, holder)
    tinsert(bodyHolders, holder)
    layout:Add(holder, holder:GetHeight(), GRID_GAP + 2)
end

local function AddWarlockDemonGrid(layout)
    local choices = {}
    for i, demon in ipairs(BR.PetHelpers.WARLOCK_DEMON_CHOICES) do
        choices[i] = { key = demon.key, label = demon.label, icon = C_Spell.GetSpellTexture(demon.spellID) }
    end
    AddContentGrid(layout, "warlockDemons", L["BuffPanel.WarlockDemon.Hint"], choices)

    local felguardSpellID = BR.PetHelpers.FELGUARD_SPELL_ID
    if not felguardSpellID then
        return
    end
    local felguard = CreateFrame("Frame", nil, body)
    felguard:SetSize(bodyW, 16)
    local fgIcon = BR.CreateBuffIcon(felguard, 16, C_Spell.GetSpellTexture(felguardSpellID))
    fgIcon:SetPoint("LEFT")
    local fgText = felguard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    fgText:SetPoint("LEFT", fgIcon, "RIGHT", 6, 0)
    fgText:SetPoint("RIGHT", felguard, "RIGHT")
    fgText:SetJustifyH("LEFT")
    fgText:SetText(L["BuffPanel.WarlockDemon.Felguard"])
    layout:Add(felguard, 16, COMPONENT_GAP)
end

-- Render a buff's inline editor at the layout cursor, then advance the layout
-- past it. The builder parents its frames to `body` and registers its holders
-- for teardown.
local function AddInlineEditor(layout, builder)
    local height = builder(body, {
        x = 0,
        y = layout:GetY(),
        width = bodyW,
        registerHolder = function(holder)
            tinsert(bodyHolders, holder)
        end,
    })
    layout:Space(height)
end

-- ============================================================================
-- ROW WARNING
-- ============================================================================

-- True when no poison column has an enabled entry, so no reminder can
-- fire. GetSpecialState colors the All Buffs row link orange for it.
local function PoisonNeedsSetup()
    local prefs = BR.profile.roguePoisonPreferences
    for _, column in ipairs(BR.BuffData.poisonColumns) do
        local list = prefs and prefs[column.key]
        for _, entry in ipairs(list or {}) do
            if entry.enabled and entry.spellID then
                return false
            end
        end
    end
    return true
end

-- Stance grids of the client. A client with spec-based stance rules has none.
local WARRIOR_STANCE_GRID = BR.BuffData.stanceRules.WARRIOR.grid
local DRUID_FORM_GRID = BR.BuffData.stanceRules.DRUID.grid

---True when no row of the stance grid allows a choice, so no reminder can fire.
---@param grid StanceGrid
---@return boolean
local function StanceGridNeedsSetup(grid)
    for _, row in ipairs(GRID_ROWS) do
        for _, choice in ipairs(grid.choices) do
            if BR.Visibility.IsContentChoiceAllowed(grid.setting, row.key, choice.key) then
                return false
            end
        end
    end
    return true
end

---@param layout table
---@param grid StanceGrid
local function AddStanceGrid(layout, grid)
    local choices = {}
    for i, choice in ipairs(grid.choices) do
        local spellID = choice.iconSpellID or choice.spellIDs[#choice.spellIDs]
        choices[i] = {
            key = choice.key,
            label = choice.label or BR.GetSpellName(spellID) or choice.key,
            icon = C_Spell.GetSpellTexture(spellID),
        }
    end
    AddContentGrid(layout, grid.setting, grid.hint, choices)
end

---A stored list without unknown keys, repeats and empty slots.
---@param grid ChoiceOrderGrid
---@param stored any
---@return string[]
local function CleanChoiceOrder(grid, stored)
    local order = {}
    if type(stored) ~= "table" then
        return order
    end
    for i = 1, grid.slots do
        local key = stored[i]
        local valid, listed = false, false
        for _, choice in ipairs(grid.choices) do
            valid = valid or choice.key == key
        end
        for _, other in ipairs(order) do
            listed = listed or other == key
        end
        if valid and not listed then
            order[#order + 1] = key
        end
    end
    return order
end

---@param grid ChoiceOrderGrid
---@param rowKey string
---@return string[]
local function RowChoiceOrder(grid, rowKey)
    local byRow = BR.Config.Get("defaults." .. grid.setting)
    return CleanChoiceOrder(grid, type(byRow) == "table" and byRow[rowKey])
end

---@param grid ChoiceOrderGrid
---@param rowKey string
---@return string[]
local function DefaultChoiceOrder(grid, rowKey)
    local byRow = BR.defaults.defaults[grid.setting]
    return CleanChoiceOrder(grid, type(byRow) == "table" and byRow[rowKey])
end

---@param a string[]
---@param b string[]
---@return boolean
local function SameOrder(a, b)
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

---Store the list of every row. A slot past the end of a list stores false, so that
---AceDB cannot fill it from the default.
---@param grid ChoiceOrderGrid
---@param orderFor fun(rowKey: string): string[]
local function WriteChoiceRows(grid, orderFor)
    local map = {}
    for _, rowKey in ipairs(grid.rows) do
        local order = orderFor(rowKey)
        local slots = {}
        for i = 1, grid.slots do
            slots[i] = order[i] or false
        end
        map[rowKey] = slots
    end
    BR.Config.Set("defaults." .. grid.setting, map)
    -- A chat request macro can name a choice of the class list. Only a rebuild rewrites the macro.
    BR.SecureButtons.UpdateActionButtons("raid")
end

---Write one row list and keep the others.
---@param grid ChoiceOrderGrid
---@param rowKey string
---@param order string[]
local function WriteRowOrder(grid, rowKey, order)
    WriteChoiceRows(grid, function(other)
        return other == rowKey and order or RowChoiceOrder(grid, other)
    end)
    Components.RefreshAll()
end

---Put a key in a slot of the list. A key that is in another slot swaps with the slot.
---A key for the first empty slot appends. A nil key removes the slot, and later slots
---shift left.
---@param order string[]
---@param slot number
---@param key string?
local function SetChoiceSlot(order, slot, key)
    if not key then
        table.remove(order, slot)
        return
    end
    local from
    for i, other in ipairs(order) do
        if other == key then
            from = i
        end
    end
    if slot > #order then
        if from then
            table.remove(order, from)
        end
        order[#order + 1] = key
        return
    end
    if from then
        order[from] = order[slot]
    end
    order[slot] = key
end

---True when every row list is empty, so no reminder can fire.
---@param grid ChoiceOrderGrid
---@return boolean
local function ChoiceOrderNeedsSetup(grid)
    for _, rowKey in ipairs(grid.rows) do
        if #RowChoiceOrder(grid, rowKey) > 0 then
            return false
        end
    end
    return true
end

local CHOICE_SLOT_SIZES = { 26, 20, 20 }
local CHOICE_SLOT_ALPHA = { 1, 0.85, 0.7 }
local CHOICE_ROW_H = 28
local CHOICE_CLUSTER_GAP = 6
local CHOICE_HEADER_H = 14
local CHOICE_DOT_W = 12
local CHOICE_MAIN_W = 34
local CHOICE_ARROW_W = 14
local CHOICE_BACKUP_W = 26
local CHOICE_RESET_W = 14
local CHOICE_DIM_ALPHA = 0.35
local FLYOUT_ITEM_H = 20
local FLYOUT_PAD = 4
local WHITE8 = "Interface\\Buttons\\WHITE8x8"
local DOT_TEXTURE = "Interface\\AddOns\\BuffReminders\\Media\\dot.tga"

---A thin diagonal slash over an icon: the choice is not learned.
---@param frame table
---@return table line
local function AddNotLearnedSlash(frame)
    local slash = frame:CreateLine(nil, "OVERLAY")
    slash:SetThickness(2)
    slash:SetStartPoint("TOPRIGHT", frame, -2, -2)
    slash:SetEndPoint("BOTTOMLEFT", frame, 2, 2)
    BR.SetThemeColorTexture(slash, Theme.cell.unlearned)
    return slash
end

local AddResetGlyph = BR.Options.Helpers.AddResetGlyph

---A dashed 1 px edge of short textures around the frame.
---@param frame table
---@param size number Side length of the square frame
---@return table[] dashes
local function AddDashedEdge(frame, size)
    local dashes = {}
    for offset = 0, size - 3, 5 do
        for side = 1, 4 do
            local dash = frame:CreateTexture(nil, "BORDER")
            if side <= 2 then
                dash:SetSize(3, 1)
                dash:SetPoint(side == 1 and "TOPLEFT" or "BOTTOMLEFT", offset, 0)
            else
                dash:SetSize(1, 3)
                dash:SetPoint(side == 3 and "TOPLEFT" or "TOPRIGHT", 0, -offset)
            end
            dashes[#dashes + 1] = dash
        end
    end
    return dashes
end

local PaintParts = BR.Options.Helpers.PaintParts

---Paint an icon as learned or not learned.
---@param icon table
---@param slash table
---@param learned boolean
local function PaintLearned(icon, slash, learned)
    icon:SetDesaturated(not learned)
    local shade = learned and 1 or 0.55
    icon:SetVertexColor(shade, shade, shade)
    slash:SetShown(not learned)
end

---The picker under a slot: every choice, a separator, then Clear. Escape or a click
---outside closes it. The flyout is a child of the body, so a teardown removes it.
---@param grid ChoiceOrderGrid
---@param isLearned fun(choice: StanceChoice): boolean
---@param inMainNote string Note of a choice that the main slot holds
---@return table flyout With :Open(anchor, rowKey, slot) and :Close()
local function CreateChoiceFlyout(grid, isLearned, inMainNote)
    local flyout = CreateFrame("Frame", nil, body)
    flyout:SetFrameStrata("FULLSCREEN_DIALOG")
    flyout:SetClampedToScreen(true)
    flyout:EnableMouse(true)
    flyout:Hide()
    BR.PaintSurface(BR.CreateSurface(flyout), Theme.menu)
    local itemColors = Theme.menuItem

    local inBackupNote = L["BuffPanel.Blessing.InBackup"]
    local items = {}
    local function AddItem(choice)
        local item = CreateFrame("Button", nil, flyout)
        item:SetHeight(FLYOUT_ITEM_H)
        item.bg = item:CreateTexture(nil, "BACKGROUND")
        item.bg:SetAllPoints()
        item.bar = item:CreateTexture(nil, "BORDER")
        item.bar:SetPoint("TOPLEFT")
        item.bar:SetPoint("BOTTOMLEFT")
        item.bar:SetWidth(2)
        BR.SetThemeColorTexture(item.bar, itemColors.bar)
        item.bar:Hide()
        local textLeft = 6
        if choice then
            local iconHolder = CreateFrame("Frame", nil, item)
            iconHolder:SetSize(16, 16)
            iconHolder:SetPoint("LEFT", 6, 0)
            item.icon = BR.CreateBuffIcon(iconHolder, 16, C_Spell.GetSpellTexture(choice.spellIDs[#choice.spellIDs]))
            item.icon:SetPoint("CENTER")
            item.slash = AddNotLearnedSlash(iconHolder)
            textLeft = 28
        end
        item.label = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        item.label:SetPoint("LEFT", textLeft, 0)
        item.label:SetJustifyH("LEFT")
        item.label:SetWordWrap(false)
        item.label:SetText(
            choice and (BR.GetSpellName(choice.spellIDs[#choice.spellIDs]) or choice.key)
                or L["BuffPanel.Blessing.Clear"]
        )
        item.note = item:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        item.note:SetPoint("RIGHT", -6, 0)
        item.note:SetJustifyH("RIGHT")
        item.choice = choice
        item.textLeft = textLeft
        item:SetScript("OnEnter", function(self)
            BR.PaintGradient(self.bg, "HORIZONTAL", itemColors.hoverLeft, itemColors.hoverRight)
            self.bar:Show()
            BR.SetThemeTextColor(self.label, itemColors.textHover)
        end)
        item:SetScript("OnLeave", function(self)
            self.bg:SetColorTexture(0, 0, 0, 0)
            self.bar:Hide()
            BR.SetThemeTextColor(self.label, self.isCurrent and Theme.cell.check or itemColors.text)
        end)
        item:SetScript("OnClick", function(self)
            local order = RowChoiceOrder(grid, flyout.rowKey)
            SetChoiceSlot(order, flyout.slot, self.choice and self.choice.key)
            flyout:Close()
            WriteRowOrder(grid, flyout.rowKey, order)
        end)
        items[#items + 1] = item
        return item
    end
    for _, choice in ipairs(grid.choices) do
        AddItem(choice)
    end
    local separator = flyout:CreateTexture(nil, "ARTWORK")
    separator:SetHeight(1)
    BR.SetThemeColorTexture(separator, Theme.cell.separator)
    local clearItem = AddItem(nil)

    local wasMouseDown = false
    flyout:SetScript("OnUpdate", function(self)
        local isMouseDown = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
        if isMouseDown and not wasMouseDown and not self:IsMouseOver() then
            if not (self.anchor and self.anchor:IsMouseOver()) then
                self:Close()
            end
        end
        wasMouseDown = isMouseDown
    end)
    flyout:EnableKeyboard(true)
    flyout:SetScript("OnKeyDown", function(self, keyPressed)
        if keyPressed == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            self:Close()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    function flyout:Close()
        self.anchor = nil
        self:Hide()
    end

    function flyout:Open(anchor, rowKey, slot)
        self.anchor, self.rowKey, self.slot = anchor, rowKey, slot
        local order = RowChoiceOrder(grid, rowKey)
        local width = 0
        for _, item in ipairs(items) do
            local note
            item.isCurrent = false
            if item.choice then
                local learned = isLearned(item.choice)
                PaintLearned(item.icon, item.slash, learned)
                item.isCurrent = order[slot] == item.choice.key
                for i, key in ipairs(order) do
                    if key == item.choice.key and i ~= slot then
                        note = i == 1 and inMainNote or inBackupNote
                    end
                end
                note = note or (not learned and L["BuffPanel.Blessing.NotLearnedShort"]) or nil
            end
            BR.SetThemeTextColor(item.label, item.isCurrent and Theme.cell.check or itemColors.text)
            item.note:SetText(note or "")
            item.bg:SetColorTexture(0, 0, 0, 0)
            item.bar:Hide()
            local noteW = note and item.note:GetStringWidth() + 12 or 0
            width = math.max(width, item.textLeft + item.label:GetStringWidth() + noteW + 10)
        end
        local hasClear = slot <= #order
        local y = -FLYOUT_PAD
        for _, item in ipairs(items) do
            if item == clearItem then
                item:SetShown(hasClear)
                if hasClear then
                    separator:ClearAllPoints()
                    separator:SetPoint("TOPLEFT", 6, y - 3)
                    separator:SetPoint("TOPRIGHT", -6, y - 3)
                    y = y - 7
                end
                separator:SetShown(hasClear)
            end
            if item:IsShown() then
                item:ClearAllPoints()
                item:SetPoint("TOPLEFT", 1, y)
                item:SetPoint("TOPRIGHT", -1, y)
                y = y - FLYOUT_ITEM_H
            end
        end
        self:SetSize(math.max(140, math.ceil(width)), -y + FLYOUT_PAD)
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
        self:SetFrameLevel(anchor:GetFrameLevel() + 50)
        wasMouseDown = IsMouseButtonDown("LeftButton")
        BR.HideTooltip()
        self:Show()
    end

    return flyout
end

---@class ChoiceOrderSpec
---@field ownerClass string The class that casts the choices
---@field rowLabel fun(rowKey: string): string
---@field rowColor? fun(rowKey: string): table? A color with GetRGB
---@field selfOnly? fun(): boolean Only the row of ownerClass applies
---@field hint string
---@field mainHeader string
---@field inMainNote string Flyout note of a choice that the main slot holds
---@field mainTip string Format with the row label
---@field notLearned string Format with the name of the next learned choice
---@field none string
---@field noneDesc string
---@field defaultsReason string

-- One row per grid row: the main choice, then the backups. A backup applies when
-- another caster already gives the choice before it.
---@param layout table
---@param grid ChoiceOrderGrid
---@param spec ChoiceOrderSpec
local function AddChoiceOrderGrid(layout, grid, spec)
    local ownerClass = spec.ownerClass
    local hint = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetWidth(bodyW)
    hint:SetJustifyH("LEFT")
    hint:SetText(spec.hint)
    layout:AddText(hint, math.max(12, math.ceil(hint:GetStringHeight())), GRID_GAP + 2)

    -- The spellbook of another class tells nothing, so there every choice reads as learned.
    local _, playerClass = UnitClass("player")
    local function IsLearned(choice)
        return playerClass ~= ownerClass or grid.castID(choice) ~= nil
    end
    local function ChoiceName(key)
        for _, choice in ipairs(grid.choices) do
            if choice.key == key then
                return BR.GetSpellName(choice.spellIDs[#choice.spellIDs]) or key, choice
            end
        end
        return key
    end

    local names = {}
    for i, rowKey in ipairs(grid.rows) do
        names[i] = spec.rowLabel(rowKey)
    end
    local labelW = Components.MeasureSharedLabelWidth(names, "GameFontHighlightSmall", 60)
    local mainX = CHOICE_DOT_W + labelW
    local backupX = mainX + CHOICE_MAIN_W + CHOICE_ARROW_W
    local resetX = backupX + (grid.slots - 1) * CHOICE_BACKUP_W + 4
    local clusterEnds = grid.clusterEnds

    local height = CHOICE_HEADER_H + #grid.rows * CHOICE_ROW_H
    for _, rowKey in ipairs(grid.rows) do
        if clusterEnds and clusterEnds[rowKey] then
            height = height + CHOICE_CLUSTER_GAP
        end
    end
    local holder = CreateFrame("Frame", nil, body)
    holder:SetSize(bodyW, height)
    local flyout = CreateChoiceFlyout(grid, IsLearned, spec.inMainNote)

    local giveHead = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    giveHead:SetPoint("TOP", holder, "TOPLEFT", mainX + CHOICE_MAIN_W / 2, 0)
    giveHead:SetText(spec.mainHeader)
    BR.ApplyNoteColor(giveHead)
    local backupHead = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    backupHead:SetPoint("TOP", holder, "TOPLEFT", backupX + (grid.slots - 1) * CHOICE_BACKUP_W / 2, 0)
    backupHead:SetText(L["BuffPanel.Blessing.IfTaken"])
    BR.ApplyNoteColor(backupHead)

    local rows = {}

    local function PaintSlot(slot)
        local hovered = slot.hovered and slot:IsMouseEnabled()
        local color = slot.edge
        if hovered then
            color = slot.isAdd and Theme.cell.addHover or Theme.cell.hover
        end
        if slot.isAdd then
            slot.dashes = slot.dashes or AddDashedEdge(slot, slot.size)
            PaintParts(slot.dashes, color)
            slot:SetBackdropBorderColor(0, 0, 0, 0)
        else
            slot:SetBackdropBorderColor(unpack(color))
        end
        if slot.dashes then
            for _, dash in ipairs(slot.dashes) do
                dash:SetShown(slot.isAdd)
            end
        end
        BR.SetThemeTextColor(slot.plus, hovered and Theme.cell.addHover or Theme.cell.add)
    end

    local function UpdateRowHover(row)
        local over = row:IsMouseOver()
        row.reset:SetShown(row.changed and not row.dimmed and over)
        if row.dimmed and over then
            BR.ShowTooltip(row, L["Component.DisabledReason.Title"], L["DisabledReason.BlessSelfOnly"], "ANCHOR_TOP")
        elseif row.dimmed then
            BR.HideTooltip()
        end
    end

    local function SlotTooltip(slot)
        local row = slot.row
        local order = row.order
        local key = order[slot.index]
        if not key then
            if slot.index == 1 then
                BR.ShowTooltip(slot, spec.none, spec.noneDesc, "ANCHOR_TOP")
            else
                BR.ShowTooltip(slot, L["BuffPanel.Blessing.AddBackup"], nil, "ANCHOR_TOP")
            end
            return
        end
        local title, choice = ChoiceName(key)
        local desc
        if choice and not IsLearned(choice) then
            local nextName
            for i = slot.index + 1, #order do
                local nextTitle, nextChoice = ChoiceName(order[i])
                if not nextName and nextChoice and IsLearned(nextChoice) then
                    nextName = nextTitle
                end
            end
            desc = nextName and string.format(spec.notLearned, nextName) or L["BuffPanel.Blessing.NotLearnedNone"]
        elseif slot.index == 1 then
            desc = string.format(spec.mainTip, row.labelText)
        else
            desc = string.format(L["BuffPanel.Blessing.BackupTip"], (ChoiceName(order[slot.index - 1])))
        end
        BR.ShowTooltip(slot, title, desc .. "\n" .. L["BuffPanel.Blessing.ClickToChange"], "ANCHOR_TOP")
    end

    local y = -CHOICE_HEADER_H
    for r, rowKey in ipairs(grid.rows) do
        local row = CreateFrame("Frame", nil, holder)
        row:SetPoint("TOPLEFT", 0, y)
        row:SetSize(bodyW, CHOICE_ROW_H)
        row:EnableMouse(true)
        row.key = rowKey
        row.labelText = names[r]
        row:SetScript("OnEnter", UpdateRowHover)
        row:SetScript("OnLeave", UpdateRowHover)

        row.dot = row:CreateTexture(nil, "ARTWORK")
        row.dot:SetSize(5, 5)
        row.dot:SetPoint("CENTER", row, "LEFT", CHOICE_DOT_W / 2, 0)
        row.dot:SetTexture(DOT_TEXTURE)
        local dotColor = Theme.cell.changed
        row.dot:SetVertexColor(dotColor[1], dotColor[2], dotColor[3], dotColor[4] or 1)

        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.label:SetPoint("LEFT", CHOICE_DOT_W, 0)
        row.label:SetWidth(labelW)
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(false)
        row.label:SetText(names[r])
        local color = spec.rowColor and spec.rowColor(rowKey)
        if color then
            row.label:SetTextColor(color:GetRGB())
        end

        local arrow = row:CreateTexture(nil, "ARTWORK")
        arrow:SetSize(10, 10)
        arrow:SetPoint("CENTER", row, "LEFT", mainX + CHOICE_MAIN_W + CHOICE_ARROW_W / 2, 0)
        arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
        local arrowColor = Theme.cell.arrow
        arrow:SetVertexColor(arrowColor[1], arrowColor[2], arrowColor[3], arrowColor[4] or 1)

        row.slots = {}
        for s = 1, grid.slots do
            local size = CHOICE_SLOT_SIZES[s]
            local slot = CreateFrame("Button", nil, row, "BackdropTemplate")
            slot:SetSize(size, size)
            slot.size = size
            local colX = s == 1 and mainX + (CHOICE_MAIN_W - size) / 2
                or backupX + (s - 2) * CHOICE_BACKUP_W + (CHOICE_BACKUP_W - size) / 2
            slot:SetPoint("LEFT", colX, 0)
            slot:SetBackdrop({ bgFile = WHITE8, edgeFile = WHITE8, edgeSize = 1 })
            slot:SetBackdropColor(unpack(Theme.cell.well))
            slot.icon = BR.CreateBuffIcon(slot, size - 2)
            slot.icon:SetPoint("CENTER")
            slot.slash = AddNotLearnedSlash(slot)
            slot.plus = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            slot.plus:SetPoint("CENTER", 0, 1)
            slot.plus:SetText("+")
            slot.row = row
            slot.index = s
            slot:SetScript("OnClick", function(self)
                if flyout:IsShown() and flyout.anchor == self then
                    flyout:Close()
                else
                    flyout:Open(self, rowKey, s)
                end
            end)
            slot:SetScript("OnEnter", function(self)
                self.hovered = true
                PaintSlot(self)
                UpdateRowHover(row)
                if not flyout:IsShown() then
                    SlotTooltip(self)
                end
            end)
            slot:SetScript("OnLeave", function(self)
                self.hovered = false
                PaintSlot(self)
                BR.HideTooltip()
                UpdateRowHover(row)
            end)
            row.slots[s] = slot
        end

        row.reset = CreateFrame("Button", nil, row)
        row.reset:SetSize(CHOICE_RESET_W, CHOICE_RESET_W)
        row.reset:SetPoint("LEFT", resetX, 0)
        row.reset.glyph = AddResetGlyph(row.reset)
        PaintParts(row.reset.glyph, Theme.cell.reset)
        row.reset:Hide()
        row.reset:SetScript("OnClick", function()
            BR.HideTooltip()
            WriteRowOrder(grid, rowKey, DefaultChoiceOrder(grid, rowKey))
        end)
        row.reset:SetScript("OnEnter", function(self)
            PaintParts(self.glyph, Theme.cell.resetHover)
            BR.ShowTooltip(self, L["BuffPanel.Blessing.ResetRow"], nil, "ANCHOR_TOP")
        end)
        row.reset:SetScript("OnLeave", function(self)
            PaintParts(self.glyph, Theme.cell.reset)
            BR.HideTooltip()
            UpdateRowHover(row)
        end)

        rows[r] = row
        y = y - CHOICE_ROW_H
        if clusterEnds and clusterEnds[rowKey] then
            y = y - CHOICE_CLUSTER_GAP
        end
    end

    local function AnyRowChanged()
        for _, rowKey in ipairs(grid.rows) do
            if not SameOrder(RowChoiceOrder(grid, rowKey), DefaultChoiceOrder(grid, rowKey)) then
                return true
            end
        end
        return false
    end

    local resetRow = CreateFrame("Frame", nil, body)
    resetRow:SetSize(bodyW, 22)
    local resetAll = CreateButton(resetRow, L["Options.ResetToDefaults"], function()
        flyout:Close()
        WriteChoiceRows(grid, function(rowKey)
            return DefaultChoiceOrder(grid, rowKey)
        end)
        Components.RefreshAll()
    end)
    resetAll:SetPoint("LEFT")
    resetAll:SetDisabledReason(spec.defaultsReason)
    resetAll:BindEnabled(AnyRowChanged)
    tinsert(bodyHolders, resetAll)
    local selfNote = resetRow:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    selfNote:SetPoint("LEFT", resetAll, "RIGHT", 8, 0)
    selfNote:SetPoint("RIGHT", resetRow, "RIGHT")
    selfNote:SetJustifyH("LEFT")
    selfNote:SetText(L["BuffPanel.Blessing.SelfOnlyNote"])

    function holder:Refresh()
        local dimOthers = spec.selfOnly ~= nil and spec.selfOnly()
        selfNote:SetShown(dimOthers)
        for _, row in ipairs(rows) do
            local order = RowChoiceOrder(grid, row.key)
            row.order = order
            row.changed = not SameOrder(order, DefaultChoiceOrder(grid, row.key))
            row.dimmed = dimOthers and row.key ~= ownerClass
            row:SetAlpha(row.dimmed and CHOICE_DIM_ALPHA or 1)
            row.dot:SetShown(row.changed)
            row.label:SetAlpha(#order == 0 and 0.5 or 1)
            for s, slot in ipairs(row.slots) do
                local key = order[s]
                local _, choice = ChoiceName(key)
                local isAdd = not key and s == #order + 1
                slot.isAdd = isAdd
                slot.icon:SetShown(choice ~= nil)
                slot.plus:SetShown(isAdd)
                slot.slash:SetShown(false)
                if choice then
                    slot.icon:SetTexture(C_Spell.GetSpellTexture(choice.spellIDs[#choice.spellIDs]))
                    PaintLearned(slot.icon, slot.slash, IsLearned(choice))
                    slot.edge = s == 1 and Theme.cell.selected or Theme.cell.edge
                    slot:SetAlpha(CHOICE_SLOT_ALPHA[s])
                elseif isAdd then
                    slot.edge = Theme.cell.add
                    slot:SetAlpha(1)
                else
                    slot.edge = Theme.cell.wellEdge
                    slot:SetAlpha(1)
                end
                slot:EnableMouse(not row.dimmed and (choice ~= nil or isAdd))
                PaintSlot(slot)
            end
            row.reset:SetShown(row.changed and not row.dimmed and row:IsMouseOver())
        end
    end

    holder:Refresh()
    tinsert(BR.RefreshableComponents, holder)
    tinsert(bodyHolders, holder)
    layout:Add(holder, height, GRID_GAP + 2)
    layout:Add(resetRow, 22, COMPONENT_GAP)
end

local function AddPlaceAtPlayerCheckbox(layout)
    AddSpecialCheckbox(layout, {
        label = L["Options.PlaceAtPlayer"],
        get = function()
            return BR.Config.Get("defaults.placeAtPlayer") ~= false
        end,
        tooltip = { title = L["Options.PlaceAtPlayer"], desc = L["Options.PlaceAtPlayer.Desc"] },
        onChange = function(checked)
            BR.Config.Set("defaults.placeAtPlayer", checked)
        end,
    })
end

-- `build(layout)` appends this buff's extra controls to the panel body. A
-- section too big for the drawer names an `editor` module instead: the drawer
-- shows a door to the focused editor, which renders that module inline.
local SPECIAL_SECTIONS = {
    healthstone = {
        build = function(layout)
            AddSpecialCheckbox(layout, {
                label = L["Options.Healthstone.LowStock"],
                get = function()
                    return BR.Config.Get("defaults.healthstoneLowStock")
                end,
                tooltip = { title = L["Options.Healthstone.LowStock"], desc = L["Options.Healthstone.LowStock.Desc"] },
                onChange = function(checked)
                    BR.Config.Set("defaults.healthstoneLowStock", checked)
                    Components.RefreshAll()
                end,
            })
            local thresholdHolder = Components.Slider(body, {
                label = L["Options.Healthstone.Threshold"],
                labelWidth = 110,
                min = 1,
                max = 2,
                step = 1,
                get = function()
                    return BR.Config.Get("defaults.healthstoneThreshold")
                end,
                enabled = function()
                    return BR.Config.Get("defaults.healthstoneLowStock")
                end,
                disabledReason = L["DisabledReason.HealthstoneThreshold"],
                tooltip = { title = L["Options.Healthstone.Threshold"], desc = L["Options.Healthstone.Threshold.Desc"] },
                onChange = function(val)
                    BR.Config.Set("defaults.healthstoneThreshold", val)
                end,
            })
            tinsert(bodyHolders, thresholdHolder)
            layout:Add(thresholdHolder, nil, COMPONENT_GAP)
        end,
    },

    rune = {
        build = function(layout)
            AddSpecialCheckbox(layout, {
                label = L["Options.PreferReusableRunes"],
                get = function()
                    return BR.Config.Get("defaults.preferReusableRunes") == true
                end,
                tooltip = {
                    title = L["Options.PreferReusableRunes.Title"],
                    desc = L["Options.PreferReusableRunes.Desc"],
                },
                onChange = function(checked)
                    BR.Config.Set("defaults.preferReusableRunes", checked)
                end,
            })
        end,
    },

    repairGear = {
        build = function(layout)
            local thresholdHolder = Components.Slider(body, {
                label = L["Options.Repair.Threshold"],
                labelWidth = 110,
                min = 5,
                max = 95,
                step = 5,
                suffix = "%",
                get = function()
                    return BR.Config.Get("defaults.repairThreshold") or 20
                end,
                tooltip = { title = L["Options.Repair.Threshold"], desc = L["Options.Repair.Threshold.Desc"] },
                onChange = function(val)
                    BR.Config.Set("defaults.repairThreshold", val)
                end,
            })
            tinsert(bodyHolders, thresholdHolder)
            layout:Add(thresholdHolder, nil, COMPONENT_GAP)
            AddSpecialCheckbox(layout, {
                label = L["Options.RepairHideInCombat"],
                get = function()
                    return BR.Config.Get("defaults.repairHideInCombat") ~= false
                end,
                tooltip = { title = L["Options.RepairHideInCombat"], desc = L["Options.RepairHideInCombat.Desc"] },
                onChange = function(checked)
                    BR.Config.Set("defaults.repairHideInCombat", checked)
                end,
            })
        end,
    },

    lowReagents = {
        build = function(layout)
            local thresholdHolder = Components.Slider(body, {
                label = L["Options.Reagent.Threshold"],
                labelWidth = 110,
                min = 1,
                max = 20,
                step = 1,
                get = function()
                    return BR.Config.Get("defaults.reagentThreshold") or 5
                end,
                tooltip = { title = L["Options.Reagent.Threshold"], desc = L["Options.Reagent.Threshold.Desc"] },
                onChange = function(val)
                    BR.Config.Set("defaults.reagentThreshold", val)
                end,
            })
            tinsert(bodyHolders, thresholdHolder)
            layout:Add(thresholdHolder, nil, COMPONENT_GAP)
            AddSpecialCheckbox(layout, {
                label = L["Options.Reagent.RestedOnly"],
                get = function()
                    return BR.Config.Get("defaults.reagentRestedOnly") ~= false
                end,
                tooltip = { title = L["Options.Reagent.RestedOnly"], desc = L["Options.Reagent.RestedOnly.Desc"] },
                onChange = function(checked)
                    BR.Config.Set("defaults.reagentRestedOnly", checked)
                end,
            })
        end,
    },

    camp = {
        build = function(layout)
            AddSpecialCheckbox(layout, {
                label = L["Options.Camp.LightFire"],
                get = function()
                    return BR.Config.Get("defaults.campLightFire") ~= false
                end,
                tooltip = { title = L["Options.Camp.LightFire"], desc = L["Options.Camp.LightFire.Desc"] },
                onChange = function(checked)
                    BR.Config.Set("defaults.campLightFire", checked)
                end,
            })
        end,
    },

    lowAmmo = {
        build = function(layout)
            local thresholdHolder = Components.Slider(body, {
                label = L["Options.Ammo.Threshold"],
                labelWidth = 110,
                min = 1,
                max = 10,
                step = 1,
                get = function()
                    return BR.Config.Get("defaults.ammoThresholdStacks") or 1
                end,
                tooltip = { title = L["Options.Ammo.Threshold"], desc = L["Options.Ammo.Threshold.Desc"] },
                onChange = function(val)
                    BR.Config.Set("defaults.ammoThresholdStacks", val)
                end,
            })
            tinsert(bodyHolders, thresholdHolder)
            layout:Add(thresholdHolder, nil, COMPONENT_GAP)
            local shotsHolder = Components.Slider(body, {
                label = L["Options.Ammo.Shots"],
                labelWidth = 110,
                min = 5,
                max = 200,
                step = 5,
                get = function()
                    return BR.Config.Get("defaults.ammoThresholdShots") or 20
                end,
                tooltip = { title = L["Options.Ammo.Shots"], desc = L["Options.Ammo.Shots.Desc"] },
                onChange = function(val)
                    BR.Config.Set("defaults.ammoThresholdShots", val)
                end,
            })
            tinsert(bodyHolders, shotsHolder)
            layout:Add(shotsHolder, nil, COMPONENT_GAP)
        end,
    },

    soulstone = {
        build = function(layout)
            AddSpecialCheckbox(layout, {
                label = L["Options.Soulstone.HideCooldown"],
                get = function()
                    return BR.Config.Get("defaults.soulstoneHideCooldown")
                end,
                tooltip = {
                    title = L["Options.Soulstone.HideCooldown"],
                    desc = L["Options.Soulstone.HideCooldown.Desc"],
                },
                onChange = function(checked)
                    BR.Config.Set("defaults.soulstoneHideCooldown", checked)
                end,
            })
            local pinHolder = Components.TextInput(body, {
                label = L["Options.Soulstone.PinnedTarget"],
                width = 120,
                get = function()
                    return BR.Config.Get("defaults.soulstonePinnedTarget") or ""
                end,
                onChange = function(text)
                    -- Strip macro-structural characters: the name is spliced into
                    -- macrotext and must never break out of the [@...] conditional
                    text = strtrim(((text or ""):gsub("[%[%]\r\n]", "")))
                    BR.Config.Set("defaults.soulstonePinnedTarget", text ~= "" and text or nil)
                    Components.RefreshAll()
                end,
            })
            pinHolder.editBox:SetMaxLetters(48)
            tinsert(bodyHolders, pinHolder)
            layout:Add(pinHolder, nil, COMPONENT_GAP)
        end,
    },

    bronze = {
        build = function(layout)
            AddSpecialCheckbox(layout, {
                label = L["Options.BronzeHideInCombat"],
                get = function()
                    return BR.profile.bronzeHideInCombat == true
                end,
                tooltip = { title = L["Options.BronzeHideInCombat"], desc = L["Options.BronzeHideInCombat.Desc"] },
                onChange = function(checked)
                    BR.Config.Set("bronzeHideInCombat", checked)
                end,
            })
        end,
    },

    druidWrongForm = {
        build = function(layout)
            if DRUID_FORM_GRID then
                AddStanceGrid(layout, DRUID_FORM_GRID)
            end
            AddSpecialCheckbox(layout, {
                label = L["Options.DruidIgnoreTravelForm"],
                get = function()
                    return BR.profile.druidIgnoreTravelForm ~= false
                end,
                tooltip = {
                    title = L["Options.DruidIgnoreTravelForm"],
                    desc = L["Options.DruidIgnoreTravelForm.Desc"],
                },
                onChange = function(checked)
                    BR.Config.Set("druidIgnoreTravelForm", checked)
                end,
            })
        end,
        warn = DRUID_FORM_GRID and function()
            return BR.StateHelpers.IsBuffEnabled("druidWrongForm") and StanceGridNeedsSetup(DRUID_FORM_GRID)
        end,
    },

    righteousFury = {
        build = function(layout)
            local drop = Components.Dropdown(body, {
                label = L["BuffPanel.RighteousFuryShow"],
                labelWidth = DRAWER_LABEL_W,
                width = DRAWER_FIELD_W,
                options = {
                    { label = L["BuffPanel.RighteousFuryShow.Tank"], value = "tank" },
                    { label = L["BuffPanel.RighteousFuryShow.Always"], value = "always" },
                },
                get = function()
                    return BR.Config.Get("defaults.righteousFuryShow", "tank")
                end,
                tooltip = { title = L["BuffPanel.RighteousFuryShow"], desc = L["BuffPanel.RighteousFuryShow.Desc"] },
                onChange = function(val)
                    BR.Config.Set("defaults.righteousFuryShow", val)
                end,
            })
            tinsert(bodyHolders, drop)
            layout:Add(drop, 26, COMPONENT_GAP)
        end,
    },

    mageArmor = {
        build = function(layout)
            local drop = Components.Dropdown(body, {
                label = L["BuffPanel.MageArmor"],
                labelWidth = DRAWER_LABEL_W,
                width = DRAWER_FIELD_W,
                options = {
                    { label = L["BuffPanel.MageArmor.Mage"], value = "mage" },
                    { label = L["BuffPanel.MageArmor.Ice"], value = "ice" },
                },
                get = function()
                    return BR.Config.Get("defaults.mageArmorPreference", "mage")
                end,
                tooltip = { title = L["BuffPanel.MageArmor"], desc = L["BuffPanel.MageArmor.Desc"] },
                onChange = function(val)
                    BR.Config.Set("defaults.mageArmorPreference", val)
                end,
            })
            tinsert(bodyHolders, drop)
            layout:Add(drop, 26, COMPONENT_GAP)
        end,
    },

    thorns = {
        build = function(layout)
            AddSpecialCheckbox(layout, {
                label = L["BuffPanel.ThornsRequest"],
                get = function()
                    return BR.Config.Get("defaults.thornsRequest") == true
                end,
                tooltip = { title = L["BuffPanel.ThornsRequest"], desc = L["BuffPanel.ThornsRequest.Desc"] },
                onChange = function(checked)
                    BR.Config.Set("defaults.thornsRequest", checked)
                end,
            })
        end,
    },

    warriorWrongStance = WARRIOR_STANCE_GRID and {
        build = function(layout)
            AddStanceGrid(layout, WARRIOR_STANCE_GRID)
        end,
        warn = function()
            return BR.StateHelpers.IsBuffEnabled("warriorWrongStance") and StanceGridNeedsSetup(WARRIOR_STANCE_GRID)
        end,
    },

    petPassive = {
        build = function(layout)
            AddSpecialCheckbox(layout, {
                label = L["Options.PetPassiveCombat"],
                get = function()
                    return BR.profile.petPassiveOnlyInCombat == true
                end,
                tooltip = { title = L["Options.PetPassiveCombat"], desc = L["Options.PetPassiveCombat.Desc"] },
                onChange = function(checked)
                    BR.Config.Set("petPassiveOnlyInCombat", checked)
                end,
            })
        end,
    },

    pets = {
        build = function(layout)
            AddClassHeader(layout, "WARLOCK")
            AddSpecialCheckbox(layout, {
                label = L["Options.FelDomination"],
                get = function()
                    return BR.Config.Get("defaults.useFelDomination")
                end,
                tooltip = { title = L["Options.FelDomination.Title"], desc = L["Options.FelDomination.Desc"] },
                onChange = function(checked)
                    BR.Config.Set("defaults.useFelDomination", checked)
                end,
            })
            AddWarlockDemonGrid(layout)
            AddSpecialCheckbox(layout, {
                label = L["BuffPanel.WarlockDemon.Warn"],
                get = function()
                    return BR.Config.Get("defaults.warlockWrongDemon") ~= false
                end,
                tooltip = { title = L["BuffPanel.WarlockDemon.Warn"], desc = L["BuffPanel.WarlockDemon.Warn.Desc"] },
                onChange = function(checked)
                    BR.Config.Set("defaults.warlockWrongDemon", checked)
                end,
            })
        end,
    },

    food = {
        build = AddPlaceAtPlayerCheckbox,
    },

    flask = {
        build = AddPlaceAtPlayerCheckbox,
    },

    delveFood = {
        build = function(layout)
            AddSpecialCheckbox(layout, {
                label = L["Options.DelveFoodTimer"],
                get = function()
                    return BR.Config.Get("defaults.delveFoodTimer") == true
                end,
                tooltip = { title = L["Options.DelveFoodTimer"], desc = L["Options.DelveFoodTimer.Desc"] },
                onChange = function(checked)
                    BR.Config.Set("defaults.delveFoodTimer", checked)
                end,
            })
        end,
    },

    mageFood = {
        build = function(layout)
            local drop = Components.Dropdown(body, {
                label = L["BuffPanel.MageFoodContent"],
                labelWidth = DRAWER_LABEL_W,
                width = DRAWER_FIELD_W,
                options = {
                    { label = L["BuffPanel.MageFoodContent.All"], value = "all" },
                    { label = L["BuffPanel.MageFoodContent.Dungeon"], value = "dungeon" },
                    { label = L["BuffPanel.MageFoodContent.Raid"], value = "raid" },
                },
                get = function()
                    return BR.Config.Get("defaults.mageFoodContent", "all")
                end,
                onChange = function(val)
                    BR.Config.Set("defaults.mageFoodContent", val)
                    Components.RefreshAll()
                end,
            })
            tinsert(bodyHolders, drop)
            layout:Add(drop, 26, COMPONENT_GAP)
        end,
    },

    shamanImbue = {
        build = function(layout)
            local options = {}
            for _, imbue in ipairs({
                { value = "windfury", spellID = 8232, fallback = L["Buff.WindfuryWeapon"] },
                { value = "flametongue", spellID = 8024, fallback = L["Buff.FlametongueWeapon"] },
                { value = "rockbiter", spellID = 8017, fallback = L["Buff.RockbiterWeapon"] },
                { value = "frostbrand", spellID = 8033, fallback = L["Buff.FrostbrandWeapon"] },
            }) do
                tinsert(options, { label = BR.GetSpellName(imbue.spellID) or imbue.fallback, value = imbue.value })
            end
            local drop = Components.Dropdown(body, {
                label = L["BuffPanel.ShamanImbue"],
                labelWidth = DRAWER_LABEL_W,
                width = DRAWER_FIELD_W,
                options = options,
                tooltip = { title = L["BuffPanel.ShamanImbue"], desc = L["BuffPanel.ShamanImbue.Desc"] },
                get = function()
                    return BR.Config.Get("defaults.shamanImbue", "windfury")
                end,
                onChange = function(val)
                    BR.Config.Set("defaults.shamanImbue", val)
                end,
            })
            tinsert(bodyHolders, drop)
            layout:Add(drop, 26, COMPONENT_GAP)
        end,
    },

    warlockStone = {
        build = function(layout)
            local drop = Components.Dropdown(body, {
                label = L["BuffPanel.WarlockStone"],
                labelWidth = DRAWER_LABEL_W,
                width = DRAWER_FIELD_W,
                options = {
                    { label = BR.GetSpellName(1237152) or L["Buff.Spellstone"], value = "spellstone" },
                    { label = BR.GetSpellName(758) or L["Buff.Firestone"], value = "firestone" },
                },
                tooltip = { title = L["BuffPanel.WarlockStone"], desc = L["BuffPanel.WarlockStone.Desc"] },
                get = function()
                    return BR.Config.Get("defaults.warlockStone", "spellstone")
                end,
                onChange = function(val)
                    BR.Config.Set("defaults.warlockStone", val)
                end,
            })
            tinsert(bodyHolders, drop)
            layout:Add(drop, 26, COMPONENT_GAP)
        end,
    },

    driveByBuffs = {
        build = function(layout, relayout)
            local function GreetingMode()
                return BR.Config.Get("defaults.driveByGreeting", "none")
            end
            local function EmoteChoice()
                return BR.Config.Get("defaults.driveByEmote", "WAVE")
            end
            -- The chat server rejects a message with an escape sequence. nil keeps the localized default.
            local function CleanGreetingText(text, defaultText)
                text = strtrim(((text or ""):gsub("|", "")))
                if text == "" or text == defaultText then
                    return nil
                end
                return text
            end
            AddSpecialCheckbox(layout, {
                label = L["BuffPanel.DriveBy.AllowPvP"],
                get = function()
                    return BR.Config.Get("defaults.driveByAllowPvP") == true
                end,
                tooltip = { title = L["BuffPanel.DriveBy.AllowPvP"], desc = L["BuffPanel.DriveBy.AllowPvP.Desc"] },
                onChange = function(checked)
                    BR.Config.Set("defaults.driveByAllowPvP", checked)
                end,
            })
            local greeting = Components.Dropdown(body, {
                label = L["BuffPanel.DriveBy.Greeting"],
                labelWidth = DRAWER_LABEL_W,
                width = DRAWER_FIELD_W,
                options = {
                    { label = L["BuffPanel.DriveBy.Greeting.None"], value = "none" },
                    { label = L["BuffPanel.DriveBy.Greeting.Whisper"], value = "whisper" },
                    { label = L["BuffPanel.DriveBy.Greeting.Emote"], value = "emote" },
                },
                get = GreetingMode,
                tooltip = { title = L["BuffPanel.DriveBy.Greeting"], desc = L["BuffPanel.DriveBy.Greeting.Desc"] },
                onChange = function(val)
                    BR.Config.Set("defaults.driveByGreeting", val)
                    Components.RefreshAll()
                end,
            })
            tinsert(bodyHolders, greeting)
            layout:Add(greeting, 26, COMPONENT_GAP)

            -- One slot holds the detail control of the selected mode.
            local slot = CreateFrame("Frame", nil, body)
            slot:SetSize(bodyW, 26)
            local whisper = Components.TextInput(slot, {
                label = L["BuffPanel.DriveBy.Whisper"],
                labelWidth = DRAWER_LABEL_W,
                width = DRAWER_FIELD_W,
                get = function()
                    return BR.Config.Get("defaults.driveByWhisper") or L["DriveBy.WhisperDefault"]
                end,
                onChange = function(text)
                    BR.Config.Set("defaults.driveByWhisper", CleanGreetingText(text, L["DriveBy.WhisperDefault"]))
                end,
            })
            whisper.editBox:SetMaxLetters(200)
            whisper:SetPoint("TOPLEFT")
            tinsert(bodyHolders, whisper)
            local emote = Components.Dropdown(slot, {
                label = L["BuffPanel.DriveBy.Emote"],
                labelWidth = DRAWER_LABEL_W,
                width = DRAWER_FIELD_W,
                options = {
                    { label = L["BuffPanel.DriveBy.Emote.Wave"], value = "WAVE" },
                    { label = L["BuffPanel.DriveBy.Emote.Hello"], value = "HELLO" },
                    { label = L["BuffPanel.DriveBy.Emote.Bow"], value = "BOW" },
                    { label = L["BuffPanel.DriveBy.Emote.Salute"], value = "SALUTE" },
                    { label = L["BuffPanel.DriveBy.Emote.Smile"], value = "SMILE" },
                    { label = L["BuffPanel.DriveBy.Emote.Cheer"], value = "CHEER" },
                    { label = L["BuffPanel.DriveBy.Emote.Custom"], value = "CUSTOM" },
                },
                get = EmoteChoice,
                onChange = function(val)
                    BR.Config.Set("defaults.driveByEmote", val)
                    Components.RefreshAll()
                end,
            })
            emote:SetPoint("TOPLEFT")
            tinsert(bodyHolders, emote)
            local emoteText = Components.TextInput(slot, {
                label = L["BuffPanel.DriveBy.Whisper"],
                labelWidth = DRAWER_LABEL_W,
                width = DRAWER_FIELD_W,
                get = function()
                    return BR.Config.Get("defaults.driveByEmoteText") or L["DriveBy.EmoteDefault"]
                end,
                onChange = function(text)
                    BR.Config.Set("defaults.driveByEmoteText", CleanGreetingText(text, L["DriveBy.EmoteDefault"]))
                end,
            })
            emoteText.editBox:SetMaxLetters(200)
            emoteText:SetPoint("TOPLEFT", 0, -(26 + COMPONENT_GAP))
            tinsert(bodyHolders, emoteText)

            local function CustomEmote()
                return GreetingMode() == "emote" and EmoteChoice() == "CUSTOM"
            end
            local function SlotHeight()
                local mode = GreetingMode()
                if mode == "none" then
                    return 0
                end
                return CustomEmote() and 2 * (26 + COMPONENT_GAP) or 26 + COMPONENT_GAP
            end
            local shownHeight
            function slot:Refresh()
                local mode = GreetingMode()
                whisper:SetShown(mode == "whisper")
                emote:SetShown(mode == "emote")
                emoteText:SetShown(CustomEmote())
                local height = SlotHeight()
                slot:SetHeight(math.max(height - COMPONENT_GAP, 1))
                if shownHeight ~= nil and shownHeight ~= height and relayout then
                    relayout()
                end
                shownHeight = height
            end
            slot:Refresh()
            tinsert(BR.RefreshableComponents, slot)
            tinsert(bodyHolders, slot)
            layout:AddDynamic(slot, SlotHeight)
        end,
    },

    tracking = {
        build = function(layout)
            local scope = Components.Dropdown(body, {
                label = L["BuffPanel.Tracking.Scope"],
                labelWidth = DRAWER_LABEL_W,
                width = DRAWER_FIELD_W,
                options = {
                    { label = L["BuffPanel.Tracking.Scope.Gathering"], value = "gathering" },
                    { label = L["BuffPanel.Tracking.Scope.All"], value = "all" },
                },
                get = function()
                    return BR.Config.Get("defaults.trackingScope", "gathering")
                end,
                tooltip = { title = L["BuffPanel.Tracking.Scope"], desc = L["BuffPanel.Tracking.Scope.Desc"] },
                onChange = function(val)
                    BR.Config.Set("defaults.trackingScope", val)
                end,
            })
            tinsert(bodyHolders, scope)
            layout:Add(scope, 26, COMPONENT_GAP)
        end,
    },

    dkRunes = {
        editor = "Runeforge",
    },

    roguePoisons = {
        warn = PoisonNeedsSetup,
        editor = "RoguePoison",
    },
}

local function IsRaidClickable()
    return BR.Config.GetCategorySetting("raid", "clickable") == true
end

---@param buff RaidBuff
---@param desc? string Tooltip text. nil = the generic group cast text
---@return table section
local function MakeGroupCastSection(buff, desc)
    local key = buff.key
    local function IsGroupCastOn()
        local groupCast = BR.profile.groupCast
        return groupCast ~= nil and groupCast[key] == true
    end
    return {
        build = function(layout)
            AddSpecialCheckbox(layout, {
                label = L["BuffPanel.GroupCast"],
                get = IsGroupCastOn,
                enabled = IsRaidClickable,
                disabledReason = L["DisabledReason.RaidClickToCast"],
                tooltip = { title = L["BuffPanel.GroupCast"], desc = desc or L["BuffPanel.GroupCast.Desc"] },
                onChange = function(checked)
                    BR.Config.Set("groupCast." .. key, checked or nil)
                    Components.RefreshAll()
                end,
            })
            local minHolder = Components.Slider(body, {
                label = L["BuffPanel.GroupCastMin"],
                labelWidth = 96,
                sliderWidth = 80,
                min = 2,
                max = 5,
                step = 1,
                suffix = L["BuffPanel.GroupCastMin.Suffix"],
                get = function()
                    return BR.Config.Get("defaults.groupCastMin") or 2
                end,
                enabled = function()
                    return IsRaidClickable() and IsGroupCastOn()
                end,
                disabledReason = function()
                    if not IsRaidClickable() then
                        return L["DisabledReason.RaidClickToCast"]
                    end
                    return L["DisabledReason.GroupCast"]
                end,
                tooltip = { title = L["BuffPanel.GroupCastMin"], desc = L["BuffPanel.GroupCastMin.Desc"] },
                onChange = function(val)
                    BR.Config.Set("defaults.groupCastMin", val)
                end,
            })
            tinsert(bodyHolders, minHolder)
            layout:Add(minHolder, nil, COMPONENT_GAP)
        end,
    }
end

-- Buffs with group ranks get the group cast section. Their definitions belong to
-- the active client, so the sections build at load time from its buff table.
-- A classChoices buff keeps its group ranks on each choice.
for _, buff in ipairs(BR.BuffData.buffTables.raid) do
    local grid = buff.classChoices
    if grid then
        local groupCast = MakeGroupCastSection(buff, L["BuffPanel.GroupCast.Blessing.Desc"])
        SPECIAL_SECTIONS[buff.key] = {
            build = function(layout)
                local function IsSelfOnly()
                    return BR.Config.Get("defaults.paladinBlessingScope") == "self"
                end
                AddChoiceOrderGrid(layout, grid, {
                    ownerClass = buff.class,
                    rowLabel = function(class)
                        return LOCALIZED_CLASS_NAMES_MALE[class] or class
                    end,
                    rowColor = C_ClassColor.GetClassColor,
                    selfOnly = IsSelfOnly,
                    hint = L["BuffPanel.PaladinBlessing.Hint"],
                    mainHeader = L["BuffPanel.Blessing.Give"],
                    inMainNote = L["BuffPanel.Blessing.InGive"],
                    mainTip = L["BuffPanel.Blessing.MainTip"],
                    notLearned = L["BuffPanel.Blessing.NotLearned"],
                    none = L["BuffPanel.Blessing.None"],
                    noneDesc = L["BuffPanel.Blessing.None.Desc"],
                    defaultsReason = L["DisabledReason.BlessingDefaults"],
                })
                AddSpecialCheckbox(layout, {
                    label = L["BuffPanel.BlessSelfOnly"],
                    get = IsSelfOnly,
                    tooltip = { title = L["BuffPanel.BlessSelfOnly"], desc = L["BuffPanel.BlessSelfOnly.Desc"] },
                    onChange = function(checked)
                        BR.Config.Set("defaults.paladinBlessingScope", checked and "self" or "group")
                        Components.RefreshAll()
                    end,
                })
                groupCast.build(layout)
            end,
            warn = function()
                return BR.StateHelpers.IsBuffEnabled(buff.key) and ChoiceOrderNeedsSetup(grid)
            end,
        }
    elseif buff.groupCast and not SPECIAL_SECTIONS[buff.key] then
        SPECIAL_SECTIONS[buff.key] = MakeGroupCastSection(buff)
    end
end

-- An empty presence row accepts any choice, so the grid never needs setup.
local CONTENT_ROW_LABELS = {}
for _, row in ipairs(GRID_ROWS) do
    CONTENT_ROW_LABELS[row.key] = row.label
end
for _, buff in ipairs(BR.BuffData.buffTables.presence) do
    local grid = buff.choiceOrder
    if grid then
        SPECIAL_SECTIONS[buff.key] = {
            build = function(layout)
                AddChoiceOrderGrid(layout, grid, {
                    ownerClass = buff.class,
                    rowLabel = function(rowKey)
                        return CONTENT_ROW_LABELS[rowKey] or rowKey
                    end,
                    hint = L["BuffPanel.PaladinAura.Hint"],
                    mainHeader = L["BuffPanel.PaladinAura.Run"],
                    inMainNote = L["BuffPanel.PaladinAura.InRun"],
                    mainTip = L["BuffPanel.PaladinAura.MainTip"],
                    notLearned = L["BuffPanel.PaladinAura.NotLearned"],
                    none = L["BuffPanel.PaladinAura.None"],
                    noneDesc = L["BuffPanel.PaladinAura.None.Desc"],
                    defaultsReason = L["DisabledReason.AuraDefaults"],
                })
            end,
        }
    end
end

-- The low-stock warning counts charges, so a healthstone without charges has no section.
for _, buff in ipairs(BR.BuffData.buffTables.consumable) do
    if buff.key == "healthstone" and not buff.itemMaxCharges then
        SPECIAL_SECTIONS.healthstone = nil
    end
end

---Editor module of a section, or nil when the section builds inline or the
---client does not load the module. The section holds the module name, not the
---table, so a load-order change cannot break the link.
---@param section table
---@return table? module
local function EditorModule(section)
    return section.editor and BR.Options.Dialogs[section.editor] or nil
end

---Render a section into the current body: the module's editor, or the
---section's own inline controls.
---@param section table
---@param layout table
---@param relayout? fun() Fits the surface after an :AddDynamic block changes height
local function BuildSpecial(section, layout, relayout)
    local module = EditorModule(section)
    if module then
        AddInlineEditor(layout, module.BuildInline)
    elseif section.build then
        section.build(layout, relayout)
    end
end

-- ============================================================================
-- DRAWER + EDITOR
-- ============================================================================

-- ---- Shared row builders (write into the active `body` surface) ---------------

---The drawer takes a sound model rather than a buff key, so the Externals rows
---can reuse the row with their own storage.
---@param key string
---@return table
local function MakeBuffSoundModel(key)
    return {
        get = function()
            local sounds = BR.profile.buffSounds
            return sounds and sounds[key]
        end,
        set = function(value)
            -- Shipped storage holds a name or nothing, never the sentinel.
            BR.Helpers.SetBuffSound(key, value ~= Sounds.NO_SOUND and value or nil)
        end,
    }
end

local function AddShowRow(layout, info)
    local key = info.key
    local showModelFactory = SHOW_MODELS[key]
    local showModel
    if showModelFactory then
        showModel = showModelFactory(info)
    elseif info.readyCheckOnly and not info.freeConsumable then
        showModel = MakePerBuffShowModel(key)
    end
    if not showModel then
        return
    end

    local descLines = {}
    for i, option in ipairs(showModel.options) do
        descLines[i] = option.label .. ": " .. option.desc
    end
    local drop = Components.Dropdown(body, {
        label = L["BuffPanel.Show"],
        labelWidth = DRAWER_LABEL_W,
        width = DRAWER_FIELD_W,
        options = showModel.options,
        get = showModel.get,
        tooltip = { title = L["BuffPanel.Show"], desc = table.concat(descLines, "\n") },
        onChange = showModel.set,
    })
    tinsert(bodyHolders, drop)
    layout:Add(drop, 26, COMPONENT_GAP)

    if showModel.note then
        local note = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        note:SetWidth(bodyW - DRAWER_LABEL_W - 4)
        note:SetJustifyH("LEFT")
        note:SetText(showModel.note)
        layout:SetX(DRAWER_LABEL_W + 4)
        layout:AddText(note, math.max(12, math.ceil(note:GetStringHeight())), COMPONENT_GAP)
        layout:SetX(0)
    end
end

---One sound control. `model.override` is optional: with it the row gains an
---Override checkbox, and while the override is off the dropdown shows the
---inherited sound, dimmed.
---@param layout table
---@param model table { get, set, override? = { isOn, setOn, desc, effective } }
local function AddSoundRow(layout, model)
    local override = model.override
    local function effectiveValue()
        if override and not override.isOn() then
            return override.effective()
        end
        return model.get()
    end

    if override then
        BR.Options.Helpers.AddOverrideRow(body, layout, {
            get = override.isOn,
            desc = override.desc,
            onChange = function(checked)
                override.setOn(checked)
                Components.RefreshAll()
            end,
        })
    end

    local soundRow = CreateFrame("Frame", nil, body)
    soundRow:SetSize(bodyW, 24)
    local soundLabel = soundRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    soundLabel:SetPoint("LEFT", 0, 0)
    soundLabel:SetWidth(DRAWER_LABEL_W)
    soundLabel:SetJustifyH("LEFT")
    soundLabel:SetText(L["BuffPanel.Sound"])

    local soundDrop = Components.Dropdown(soundRow, {
        label = "",
        labelWidth = 0,
        width = DRAWER_FIELD_W,
        maxItems = 15,
        options = Sounds.BuildOptions(),
        enabled = override and override.isOn or nil,
        disabledReason = override and L["DisabledReason.SoundOverride"] or nil,
        get = function()
            return effectiveValue() or Sounds.NO_SOUND
        end,
        onChange = function(val)
            -- The raw value: each model decides whether the sentinel is stored.
            model.set(val)
            -- Repaint the row that opened the drawer so its sound glyph follows.
            Components.RefreshAll()
        end,
    })
    -- Dropdown puts its button 5 px after the label, so this matches the drawer dropdowns with a label.
    soundDrop:SetPoint("LEFT", soundRow, "LEFT", DRAWER_LABEL_W, 0)
    tinsert(bodyHolders, soundDrop)

    local playBtn = BR.Options.Helpers.SoundPreviewButton(soundRow, effectiveValue)
    playBtn:SetPoint("LEFT", soundDrop, "RIGHT", 8, 0)
    layout:Add(soundRow, 24, COMPONENT_GAP)
end

local function AddDetachRow(layout, key)
    local detachRow = CreateFrame("Frame", nil, body)
    detachRow:SetSize(bodyW, 22)
    local detachHolder = Components.Checkbox(detachRow, {
        label = L["BuffPanel.Detached"],
        get = function()
            return BR.Helpers.IsIconDetached(key)
        end,
        tooltip = { title = L["BuffPanel.Detached"], desc = L["BuffPanel.Detached.Desc"] },
        onChange = function(checked)
            if checked then
                BR.Helpers.DetachIcon(key)
            else
                BR.Helpers.ReattachIcon(key)
            end
            BR.Display.Update()
            Components.RefreshAll()
        end,
    })
    detachHolder:SetPoint("LEFT", 0, 0)
    tinsert(bodyHolders, detachHolder)

    local resetPosBtn = CreateButton(detachRow, L["DetachedIcons.ResetPos"], function()
        BR.Helpers.ResetDetachedPosition(key)
    end)
    resetPosBtn:SetPoint("LEFT", detachHolder.infoIcon or detachHolder.label, "RIGHT", 8, 0)
    resetPosBtn:BindEnabled(function()
        return BR.Helpers.IsIconDetached(key)
    end)
    resetPosBtn:SetDisabledReason(L["DisabledReason.NotDetached"])
    tinsert(bodyHolders, resetPosBtn)
    layout:Add(detachRow, 22, COMPONENT_GAP)
end

-- ---- Focused editor (poison / runeforge) --------------------------------------

local EditorDialog = BR.Options.Helpers.CreateDialog({
    name = "BuffRemindersBuffEditor",
    width = PANEL_W,
    height = 200,
    level = 220,
    icon = true,
    bodyInset = { x = EDITOR_BODY_X, y = EDITOR_BODY_TOP },
    onTearDown = function()
        for _, holder in ipairs(editorHolders) do
            Components.Unregister(holder)
        end
        wipe(editorHolders)
        editorBody = nil
    end,
})

local function OpenEditor(info)
    local key = info.key
    local section = SPECIAL_SECTIONS[key]
    local module = EditorModule(section)
    local panelW = module and module.Width or PANEL_W

    editorBody = EditorDialog:Open(BR.TITLE_COLOR_CODE .. (info.displayName or key) .. "|r")
    editor = EditorDialog.dialog
    EditorDialog:SetIcon(info.icons and info.icons[1] or 134400)

    -- The width varies per section, so the body is resized after Open sized it
    -- from the configured default.
    editor:SetWidth(panelW)
    bodyW = panelW - EDITOR_BODY_X * 2
    editorBody:SetWidth(bodyW)
    body = editorBody
    bodyHolders = editorHolders

    local layout = Components.VerticalLayout(editorBody, { x = 0, y = 0 })
    BuildSpecial(section, layout)

    local h = math.abs(layout:GetY())
    editorBody:SetHeight(h)
    editor:SetHeight(EDITOR_BODY_TOP + h + 16)
    BR.ApplyDialogScale(editor)
    editor:Show()
    Components.RefreshAll()
end

-- ---- Drawer (quick-settings popover) ------------------------------------------

local function HideDrawer()
    if drawer then
        drawer:Hide()
    end
end

local function TearDownDrawerBody()
    for _, holder in ipairs(drawerHolders) do
        Components.Unregister(holder)
    end
    wipe(drawerHolders)
    if drawerBody then
        drawerBody:Hide()
        drawerBody:SetParent(nil)
        drawerBody = nil
        Components.PruneEditBoxes()
    end
end

local function EnsureDrawer()
    if drawer then
        return
    end
    -- Click-away catcher: a transparent full-screen frame just under the drawer.
    -- A click anywhere outside the drawer lands here and dismisses it. Kept at
    -- the default (low) frame level so the sound dropdown's menu, which opens at
    -- a higher level, stays clickable.
    catcher = CreateFrame("Frame", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:EnableMouse(true)
    catcher:Hide()
    catcher:SetScript("OnMouseDown", HideDrawer)

    drawer = CreateFrame("Frame", "BuffRemindersBuffDrawer", UIParent)
    drawer._br_optionsSurface = true
    drawer:SetSize(DRAWER_W, 100)
    drawer:SetFrameStrata("FULLSCREEN_DIALOG")
    drawer:SetFrameLevel(230)
    drawer:SetClampedToScreen(true)
    drawer:EnableMouse(true)
    -- The drawer constants are written in screen pixels, not in panel units.
    BR.RegisterScaledDialog(drawer, 1)

    for i = 1, 4 do
        local outset = 5 - i
        local shadow = drawer:CreateTexture(nil, "BACKGROUND", nil, -8 + i)
        shadow:SetPoint("TOPLEFT", -outset, outset)
        shadow:SetPoint("BOTTOMRIGHT", outset, -outset)
        shadow:SetColorTexture(0, 0, 0, 0.05 + (i - 1) * 0.05)
    end

    local inset = BR.AddShell(drawer, Theme.shell.drawer)
    local stripe = drawer:CreateTexture(nil, "ARTWORK")
    stripe:SetPoint("TOPLEFT", inset, -inset)
    stripe:SetPoint("BOTTOMLEFT", inset, inset)
    stripe:SetWidth(Theme.drawerStripe.width)
    BR.SetThemeColorTexture(stripe, Theme.drawerStripe.color)

    drawerIcon = BR.CreateBuffIcon(drawer, 16)
    drawerIcon:SetPoint("TOPLEFT", DRAWER_BODY_X, -9)
    drawerTitle = drawer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    drawerTitle:SetPoint("RIGHT", drawer, "RIGHT", -10, 0)
    drawerTitle:SetJustifyH("LEFT")
    drawerTitle:SetWordWrap(false)

    local headSep = drawer:CreateTexture(nil, "ARTWORK")
    headSep:SetHeight(1)
    headSep:SetPoint("TOPLEFT", DRAWER_BODY_X, -30)
    headSep:SetPoint("TOPRIGHT", -10, -30)
    BR.AddGroove(headSep, Theme.groove.drawer)

    -- Modeless ESC-to-dismiss. Other keys propagate, so the drawer does not
    -- block keyboard input.
    drawer:EnableKeyboard(true)
    drawer:SetScript("OnKeyDown", function(self, keyPressed)
        if keyPressed == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            self:Hide()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    drawer:HookScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        if catcher then
            catcher:Hide()
        end
        -- Release on close, not on the next open: the drawer opens from every
        -- buff row, so a deferred teardown holds one dead body per click.
        TearDownDrawerBody()
    end)
end

---Open the drawer with a body built by `fill`. Header, sizing and the slide-in
---are the same for every caller; only the body differs.
---@param title string
---@param icon number|string|nil
---@param anchor? table Frame to anchor the drawer beside
---@param fill fun(layout: table, body: table, width: number, relayout: fun())
---@param width? number Card width; defaults to the one the per-buff cards use
local function OpenDrawer(title, icon, anchor, fill, width)
    EnsureDrawer()
    TearDownDrawerBody()

    -- The drawer covers the widget that opened it. That widget gets no OnLeave,
    -- so its tooltip stays over the drawer until the pointer crosses the row.
    BR.HideTooltip()

    drawer:SetWidth(width or DRAWER_W)

    drawerTitle:SetText(BR.TITLE_COLOR_CODE .. title .. "|r")

    -- With no icon, the title moves into the icon position. -17 is the header
    -- strip midpoint, where the icon centers.
    drawerIcon:SetShown(icon ~= nil)
    drawerTitle:SetPoint("LEFT", drawer, "TOPLEFT", icon and DRAWER_BODY_X + 23 or DRAWER_BODY_X, -17)
    if icon then
        drawerIcon:SetTexture(icon)
    end

    bodyW = (width or DRAWER_W) - DRAWER_BODY_X * 2
    drawerBody = CreateFrame("Frame", nil, drawer)
    drawerBody:SetPoint("TOPLEFT", DRAWER_BODY_X, -DRAWER_BODY_TOP)
    drawerBody:SetSize(bodyW, 100)
    body = drawerBody
    bodyHolders = drawerHolders

    local layout = Components.VerticalLayout(drawerBody, { x = 0, y = 0 })
    local function FitHeight()
        local h = math.abs(layout:GetY())
        drawerBody:SetHeight(h)
        drawer:SetHeight(DRAWER_BODY_TOP + h + 12)
        -- The height decides the scale clamp, and a reopen on an already-shown
        -- drawer skips OnShow.
        BR.ApplyDialogScale(drawer)
    end
    fill(layout, drawerBody, bodyW, function()
        layout:Reflow()
        FitHeight()
    end)
    FitHeight()

    drawer:ClearAllPoints()
    catcher:Show()
    drawer:Show()

    if anchor then
        local restX, dy = 8, 8
        local elapsed = 0
        drawer:SetAlpha(0)
        drawer:SetPoint("TOPLEFT", anchor, "TOPRIGHT", restX, dy)
        drawer:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            local t = elapsed / 0.13
            if t > 1 then
                t = 1
            end
            local e = 1 - (1 - t) * (1 - t)
            self:SetAlpha(e)
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", anchor, "TOPRIGHT", restX - 12 * (1 - e), dy)
            if t >= 1 then
                self:SetScript("OnUpdate", nil)
            end
        end)
    else
        drawer:SetAlpha(1)
        drawer:SetPoint("CENTER")
    end

    Components.RefreshAll()
end

---Open the quick-settings drawer for a buff, anchored beside the row link.
---@param info table { key, displayName, icons, readyCheckOnly, freeConsumable }
---@param anchor? table Frame to anchor the drawer beside (the row's link)
local function Show(info, anchor)
    local key = info.key
    OpenDrawer(info.displayName or key, info.icons and info.icons[1], anchor, function(layout, _, _, relayout)
        local special = SPECIAL_SECTIONS[key]
        if special then
            local module = EditorModule(special)
            if module then
                local editBtn = CreateButton(
                    drawerBody,
                    string.format(L["BuffPanel.EditOption"], module.Name or key),
                    function()
                        HideDrawer()
                        OpenEditor(info)
                    end
                )
                editBtn:SetSize(bodyW, 24)
                layout:Add(editBtn, 24, COMPONENT_GAP)
            else
                BuildSpecial(special, layout, relayout)
            end
            layout:Space(4)
            local sep = drawerBody:CreateTexture(nil, "ARTWORK")
            sep:SetSize(bodyW, 1)
            sep:SetColorTexture(0.4, 0.32, 0.05, 0.6)
            layout:Add(sep, 0, 8)
        end

        AddShowRow(layout, info)
        AddSoundRow(layout, MakeBuffSoundModel(key))
        AddDetachRow(layout, key)
    end)
end

---Open a sound-only drawer. Used by the Externals rows, whose entries have no
---other per-entry setting.
---@param info table { title, icon, model }
---@param anchor? table Frame to anchor the drawer beside (the row's glyph)
local function ShowSound(info, anchor)
    OpenDrawer(info.title, info.icon, anchor, function(layout)
        AddSoundRow(layout, info.model)
    end)
end

BR.Options.Dialogs.BuffPanel = {
    Show = Show,
    ShowSound = ShowSound,
    ---Open the drawer with a body of the caller's own. The Externals page uses this
    ---for its custom entries, whose drawer holds more than a sound.
    OpenDrawer = OpenDrawer,
    HideDrawer = HideDrawer,
    ---Add the shared sound row to a drawer body. Valid only inside an OpenDrawer
    ---fill callback, which is what points the shared build surface at that body.
    AddSoundRow = AddSoundRow,
    ---Label and field widths of the drawer body, so a caller's rows line up.
    LABEL_WIDTH = DRAWER_LABEL_W,
    FIELD_WIDTH = DRAWER_FIELD_W,
    ---Whether a buff has its own options (a special section), and whether that
    ---option still needs setup. Drives the All Buffs row trailing link: a gold
    ---"Extras" (orange when isWarning) against the plain gray "Settings".
    ---@return boolean isSpecial, boolean? isWarning
    GetSpecialState = function(key)
        local special = SPECIAL_SECTIONS[key]
        if not special then
            return false
        end
        return true, special.warn ~= nil and special.warn()
    end,
    Hide = function()
        if drawer then
            drawer:Hide()
        end
        EditorDialog:Close()
    end,
}

BR.Options.WhatsNew.Register({ cohort = "6.8.2", pageId = "allBuffs", key = "food" })
