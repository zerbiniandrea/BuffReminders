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
-- Regular readyCheckOnly buffs store their override in
-- readyCheckOnlyOverrides[key] (nil = ready-check-only, false = always).
-- Healthstone/Soulstone store a three-value mode in defaults.*Visibility;
-- the caster checkbox covers the middle value.

local function MakeOverrideShowModel(key)
    return {
        isReadyCheck = function()
            local overrides = BR.profile.readyCheckOnlyOverrides
            return not overrides or overrides[key] ~= false
        end,
        setReadyCheck = function(checked)
            -- `checked and nil or false` cannot replace this branch: the idiom always
            -- yields false, because the true-branch value (nil) is itself falsy.
            local override
            if not checked then
                override = false
            end
            BR.Config.Set("readyCheckOnlyOverrides." .. key, override)
        end,
    }
end

local function MakeVisibilityShowModel(configKey)
    local path = "defaults." .. configKey
    local model
    model = {
        isReadyCheck = function()
            return BR.Config.Get(path) ~= "always"
        end,
        setReadyCheck = function(checked)
            if not checked then
                BR.Config.Set(path, "always")
            elseif model.isCasterAlways() then
                BR.Config.Set(path, "casterOnly")
            else
                BR.Config.Set(path, "readyCheck")
            end
        end,
        isCasterAlways = function()
            return BR.Config.Get(path) == "casterOnly"
        end,
        setCasterAlways = function(checked)
            BR.Config.Set(path, checked and "casterOnly" or "readyCheck")
        end,
        hasCasterOption = true,
    }
    return model
end

local SHOW_MODELS = {
    healthstone = function()
        return MakeVisibilityShowModel("healthstoneVisibility")
    end,
    soulstone = function()
        return MakeVisibilityShowModel("soulstoneVisibility")
    end,
    manaGem = function()
        local model = MakeVisibilityShowModel("healthstoneVisibility")
        model.hasCasterOption = false
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
    { key = "dungeon", label = L["BuffPanel.WarlockDemon.Dungeon"], desc = BR.CONTENT_GRID_DUNGEON_DESC },
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
---@param single? boolean A row holds at most one choice
local function AddContentGrid(layout, setting, hintText, choices, single)
    local IsContentChoiceAllowed = BR.StateHelpers.IsContentChoiceAllowed
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
                local rowPath = "defaults." .. setting .. "." .. row.key .. "."
                if single then
                    -- Every key gets an explicit value, so that a code default cannot
                    -- add a second choice to the row.
                    local changes = {}
                    for _, other in ipairs(choices) do
                        changes[rowPath .. other.key] = false
                    end
                    changes[rowPath .. choice.key] = not allowed
                    BR.Config.SetMulti(changes)
                else
                    BR.Config.Set(rowPath .. choice.key, not allowed)
                end
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

-- True when neither poison category has an enabled entry, so no reminder can
-- fire. GetSpecialState colors the All Buffs row link orange for it.
local function PoisonNeedsSetup()
    local prefs = BR.profile.roguePoisonPreferences
    local function noneEnabled(cat)
        local list = prefs and prefs[cat]
        if not list then
            return true
        end
        for _, entry in ipairs(list) do
            if entry.enabled and entry.spellID then
                return false
            end
        end
        return true
    end
    return noneEnabled("lethal") and noneEnabled("nonLethal")
end

-- Stance grids of the client. A client with spec-based stance rules has none.
local WARRIOR_STANCE_GRID = BR.STANCE_RULES.WARRIOR.grid
local DRUID_FORM_GRID = BR.STANCE_RULES.DRUID.grid

---True when no row of the stance grid allows a choice, so no reminder can fire.
---@param grid StanceGrid
---@return boolean
local function StanceGridNeedsSetup(grid)
    for _, row in ipairs(GRID_ROWS) do
        for _, choice in ipairs(grid.choices) do
            if BR.StateHelpers.IsContentChoiceAllowed(grid.setting, row.key, choice.key) then
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
    AddContentGrid(layout, grid.setting, grid.hint, choices, grid.single)
end

---@param choice StanceChoice
---@return boolean
local function KnowsChoice(choice)
    for _, id in ipairs(choice.spellIDs) do
        if BR.StateHelpers.IsPlayerSpellCached(id) then
            return true
        end
    end
    return false
end

---True when no row chooses a buff, or a row chooses one that this character of the
---buff's class does not know. Either way a row stays silent. A character who knows
---no choice yet is not flagged.
---@param buff RaidBuff
---@return boolean
local function ChoiceGridNeedsSetup(buff)
    local grid = buff.choiceGrid --[[@as StanceGrid]]
    if StanceGridNeedsSetup(grid) then
        return true
    end
    local _, playerClass = UnitClass("player")
    if playerClass ~= buff.class then
        return false
    end
    local knowsAny = false
    for _, choice in ipairs(grid.choices) do
        knowsAny = knowsAny or KnowsChoice(choice)
    end
    if not knowsAny then
        return false
    end
    for _, row in ipairs(GRID_ROWS) do
        for _, choice in ipairs(grid.choices) do
            if
                BR.StateHelpers.IsContentChoiceAllowed(grid.setting, row.key, choice.key) and not KnowsChoice(choice)
            then
                return true
            end
        end
    end
    return false
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

    dkRunes = {
        editor = "Runeforge",
    },

    roguePoisons = {
        warn = PoisonNeedsSetup,
        editor = "RoguePoison",
    },
}

local function IsRaidClickable()
    local cs = BR.profile.categorySettings
    return cs ~= nil and cs.raid ~= nil and cs.raid.clickable == true
end

---@param buff RaidBuff
---@param desc? string Tooltip text. nil = the generic group cast text
---@return table section
local function MakeGroupCastSection(buff, desc)
    local key = buff.key
    return {
        build = function(layout)
            AddSpecialCheckbox(layout, {
                label = L["BuffPanel.GroupCast"],
                get = function()
                    local groupCast = BR.profile.groupCast
                    return groupCast ~= nil and groupCast[key] == true
                end,
                enabled = IsRaidClickable,
                disabledReason = L["DisabledReason.RaidClickToCast"],
                tooltip = { title = L["BuffPanel.GroupCast"], desc = desc or L["BuffPanel.GroupCast.Desc"] },
                onChange = function(checked)
                    BR.Config.Set("groupCast." .. key, checked or nil)
                end,
            })
        end,
    }
end

local function IsBlessingGroupScope()
    return BR.Config.Get("defaults.paladinBlessingScope", "group") ~= "self"
end

---@param layout table
---@param grid StanceGrid
local function AddBlessingControls(layout, grid)
    local scope = Components.Dropdown(body, {
        label = L["BuffPanel.BlessingScope"],
        labelWidth = DRAWER_LABEL_W,
        width = DRAWER_FIELD_W,
        options = {
            { label = L["BuffPanel.BlessingScope.Group"], value = "group" },
            { label = L["BuffPanel.BlessingScope.Self"], value = "self" },
        },
        get = function()
            return BR.Config.Get("defaults.paladinBlessingScope", "group")
        end,
        tooltip = { title = L["BuffPanel.BlessingScope"], desc = L["BuffPanel.BlessingScope.Desc"] },
        onChange = function(val)
            BR.Config.Set("defaults.paladinBlessingScope", val)
            Components.RefreshAll()
        end,
    })
    tinsert(bodyHolders, scope)
    layout:Add(scope, 26, COMPONENT_GAP)

    local hint = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetWidth(bodyW)
    hint:SetJustifyH("LEFT")
    hint:SetText(L["BuffPanel.BlessingPriority.Hint"])
    layout:AddText(hint, math.max(12, math.ceil(hint:GetStringHeight())), COMPONENT_GAP)

    local options = {}
    for i, choice in ipairs(grid.choices) do
        options[i] = { label = BR.GetSpellName(choice.spellIDs[#choice.spellIDs]) or choice.key, value = choice.key }
    end
    local function Priority()
        local list = {}
        for i, key in ipairs(BR.Config.Get("defaults.paladinBlessingPriority") or {}) do
            list[i] = key
        end
        return list
    end
    for slot = 1, #grid.choices do
        local drop = Components.Dropdown(body, {
            label = L["BuffPanel.BlessingPriority." .. slot],
            labelWidth = DRAWER_LABEL_W,
            width = DRAWER_FIELD_W,
            options = options,
            get = function()
                return Priority()[slot]
            end,
            enabled = IsBlessingGroupScope,
            disabledReason = L["DisabledReason.BlessingPriority"],
            onChange = function(val)
                -- The list stays a permutation: the old slot of the value takes the replaced key.
                local list = Priority()
                for other = 1, #grid.choices do
                    if list[other] == val then
                        list[other] = list[slot]
                    end
                end
                list[slot] = val
                BR.Config.Set("defaults.paladinBlessingPriority", list)
                Components.RefreshAll()
            end,
        })
        tinsert(bodyHolders, drop)
        layout:Add(drop, 26, COMPONENT_GAP)
    end
end

-- Buffs with group ranks get the group cast section. Their definitions belong to
-- the active client, so the sections build at load time from its buff table.
-- A choice-grid buff keeps its group ranks on each choice.
for _, buff in ipairs(BR.BUFF_TABLES.raid) do
    if buff.choiceGrid then
        local groupCast = MakeGroupCastSection(buff, L["BuffPanel.GroupCast.Blessing.Desc"])
        SPECIAL_SECTIONS[buff.key] = {
            build = function(layout)
                AddStanceGrid(layout, buff.choiceGrid)
                groupCast.build(layout)
                if buff.fallbackChoices then
                    AddBlessingControls(layout, buff.choiceGrid)
                end
            end,
            warn = function()
                return BR.StateHelpers.IsBuffEnabled(buff.key) and ChoiceGridNeedsSetup(buff)
            end,
        }
    elseif buff.groupCast and not SPECIAL_SECTIONS[buff.key] then
        SPECIAL_SECTIONS[buff.key] = MakeGroupCastSection(buff)
    end
end

-- A presence grid row with no choice accepts any choice, so the grid never needs setup.
for _, buff in ipairs(BR.BUFF_TABLES.presence) do
    if buff.choiceGrid then
        SPECIAL_SECTIONS[buff.key] = {
            build = function(layout)
                AddStanceGrid(layout, buff.choiceGrid)
            end,
        }
    end
end

-- The low-stock warning counts charges, so a healthstone without charges has no section.
for _, buff in ipairs(BR.BUFF_TABLES.consumable) do
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
        showModel = showModelFactory()
    elseif info.readyCheckOnly and not info.freeConsumable then
        showModel = MakeOverrideShowModel(key)
    end
    if not showModel then
        return
    end

    local function ToggleLabel(checked)
        return checked and L["Options.ReadyCheck"] or L["Options.Always"]
    end
    local showRow = CreateFrame("Frame", nil, body)
    showRow:SetSize(bodyW, 22)
    local showLabel = showRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    showLabel:SetPoint("LEFT", 0, 0)
    showLabel:SetWidth(DRAWER_LABEL_W)
    showLabel:SetJustifyH("LEFT")
    showLabel:SetText(L["BuffPanel.Show"])

    local toggle
    toggle = Components.Toggle(showRow, {
        label = ToggleLabel(showModel.isReadyCheck()),
        get = showModel.isReadyCheck,
        onChange = function(checked)
            showModel.setReadyCheck(checked)
            toggle.label:SetText(ToggleLabel(checked))
            Components.RefreshAll()
        end,
    })
    toggle:SetPoint("LEFT", showRow, "LEFT", DRAWER_LABEL_W + 4, 0)
    local origToggleRefresh = toggle.Refresh
    function toggle:Refresh()
        origToggleRefresh(self)
        self.label:SetText(ToggleLabel(showModel.isReadyCheck()))
    end
    tinsert(bodyHolders, toggle)
    layout:Add(showRow, 22, COMPONENT_GAP)

    if showModel.note then
        local note = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        note:SetWidth(bodyW - DRAWER_LABEL_W - 4)
        note:SetJustifyH("LEFT")
        note:SetText(showModel.note)
        layout:SetX(DRAWER_LABEL_W + 4)
        layout:AddText(note, math.max(12, math.ceil(note:GetStringHeight())), COMPONENT_GAP)
        layout:SetX(0)
    end

    if showModel.hasCasterOption then
        layout:SetX(DRAWER_LABEL_W + 4)
        local casterHolder = Components.Checkbox(body, {
            label = L["BuffPanel.CasterAlways"],
            get = showModel.isCasterAlways,
            enabled = showModel.isReadyCheck,
            disabledReason = L["DisabledReason.CasterAlways"],
            tooltip = { title = L["BuffPanel.CasterAlways"], desc = L["BuffPanel.CasterAlways.Desc"] },
            onChange = function(checked)
                showModel.setCasterAlways(checked)
            end,
        })
        tinsert(bodyHolders, casterHolder)
        layout:Add(casterHolder, nil, COMPONENT_GAP)
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
    soundDrop:SetPoint("LEFT", soundRow, "LEFT", DRAWER_LABEL_W + 4, 0)
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
