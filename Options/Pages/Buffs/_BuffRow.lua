local _, BR = ...

-- ============================================================================
-- BUFF ROW FACTORY (shared)
-- ============================================================================
-- One row per tracked buff: checkbox with icon + optional ready-check toggle +
-- optional gear icon (opens per-buff dialog) + detach pin. Used by the All
-- Buffs page (single 2-column control panel) — extracted out of the per-buff
-- section module so both surfaces render identical rows.
--
-- Group dedup: buffs sharing a `groupId` collapse into a single row whose
-- spell list / icon set is the union of the group members. Non-grouped buffs
-- get one row keyed by `buff.key`.

local L = BR.L
local Components = BR.Components

local BuffGroups = BR.BuffGroups

local GetBuffTexture = BR.Helpers.GetBuffTexture

local UpdateDisplay = BR.Display.Update

local CreateDetachPin = BR.Options.Helpers.CreateDetachPin
local ResolveBuffIcons = BR.Options.Helpers.ResolveBuffIcons

local ITEM_HEIGHT = BR.Options.Constants.ITEM_HEIGHT

local tinsert = table.insert

BR.Options.BuffRow = BR.Options.BuffRow or {}

-- Buff-specific gear icon → dialog map. Built lazily so BR.L is populated.
local function GetSettingsActions()
    return {
        healthstone = {
            tooltip = L["Options.HealthstoneSettings"],
            note = L["Options.HealthstoneSettings.Note"],
            onClick = function()
                BR.Options.Dialogs.Healthstone.Show()
            end,
        },
        soulstone = {
            tooltip = L["Options.SoulstoneSettings"],
            note = L["Options.SoulstoneSettings.Note"],
            onClick = function()
                BR.Options.Dialogs.Soulstone.Show()
            end,
        },
        dkRunes = {
            tooltip = L["Options.RuneforgePreferences"],
            note = L["Options.RuneforgeNote"],
            onClick = function()
                BR.Options.Dialogs.Runeforge.Show()
            end,
        },
        roguePoisons = {
            tooltip = L["Options.RoguePoisonPreferences"],
            note = L["Options.RoguePoisonNote"],
            onClick = function()
                BR.Options.Dialogs.RoguePoison.Show()
            end,
        },
        petPassive = {
            tooltip = L["Options.PetPassiveSettings"],
            note = L["Options.PetPassiveSettings.Note"],
            onClick = function()
                BR.Options.Dialogs.PetPassive.Show()
            end,
        },
        pets = {
            tooltip = L["Options.PetSummonSettings"],
            note = L["Options.PetSummonSettings.Note"],
            onClick = function()
                BR.Options.Dialogs.PetSummon.Show()
            end,
        },
        delveFood = {
            tooltip = L["Options.DelveFoodSettings"],
            note = L["Options.DelveFoodSettings.Note"],
            onClick = function()
                BR.Options.Dialogs.DelveFood.Show()
            end,
        },
        bronze = {
            tooltip = L["Options.BronzeSettings"],
            note = L["Options.BronzeSettings.Note"],
            onClick = function()
                BR.Options.Dialogs.Bronze.Show()
            end,
        },
    }
end

local function CreateBuffRow(
    parent,
    x,
    y,
    spellIDs,
    key,
    displayName,
    infoTooltip,
    displayIcon,
    readyCheckOnly,
    freeConsumable
)
    local settingsActions = GetSettingsActions()
    local holder = Components.Checkbox(parent, {
        label = displayName,
        icons = ResolveBuffIcons(displayIcon, spellIDs),
        infoTooltip = not readyCheckOnly and infoTooltip or nil,
        get = function()
            return BR.profile.enabledBuffs[key] ~= false
        end,
        onChange = function(checked)
            BR.profile.enabledBuffs[key] = checked
            UpdateDisplay()
            if readyCheckOnly then
                Components.RefreshAll()
            end
        end,
    })
    holder:SetPoint("TOPLEFT", x, y)

    if readyCheckOnly and not freeConsumable and key ~= "soulstone" then
        local function GetReadyCheckOnlyState()
            local overrides = BR.profile.readyCheckOnlyOverrides
            return not overrides or overrides[key] ~= false
        end

        local function ToggleLabel(checked)
            return checked and L["Options.ReadyCheck"] or L["Options.Always"]
        end

        local toggle
        toggle = Components.Toggle(holder, {
            label = ToggleLabel(GetReadyCheckOnlyState()),
            get = GetReadyCheckOnlyState,
            enabled = function()
                return BR.profile.enabledBuffs[key] ~= false
            end,
            onChange = function(checked)
                if checked then
                    BR.Config.Set("readyCheckOnlyOverrides." .. key, nil)
                else
                    BR.Config.Set("readyCheckOnlyOverrides." .. key, false)
                end
                toggle.label:SetText(ToggleLabel(checked))
            end,
        })
        local origRefresh = toggle.Refresh
        function toggle:Refresh()
            origRefresh(self)
            self.label:SetText(ToggleLabel(GetReadyCheckOnlyState()))
        end
        toggle:SetPoint("LEFT", holder.label, "RIGHT", 6, 0)
    end

    local settings = settingsActions[key]
    if settings then
        local gearBtn = CreateFrame("Button", nil, holder)
        gearBtn:SetSize(14, 14)
        gearBtn:SetPoint("LEFT", holder, "RIGHT", 4, 0)
        gearBtn:SetFrameLevel(holder:GetFrameLevel() + 5)
        local gearTex = gearBtn:CreateTexture(nil, "ARTWORK")
        gearTex:SetAllPoints()
        gearTex:SetTexture("Interface\\Buttons\\UI-OptionsButton")
        gearTex:SetVertexColor(0.7, 0.7, 0.7, 0.8)
        gearBtn:SetScript("OnEnter", function(self)
            gearTex:SetVertexColor(1, 1, 1, 1)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(settings.tooltip, 1, 1, 1)
            GameTooltip:AddLine(settings.note, 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        gearBtn:SetScript("OnLeave", function()
            gearTex:SetVertexColor(0.7, 0.7, 0.7, 0.8)
            GameTooltip:Hide()
        end)
        gearBtn:SetScript("OnClick", settings.onClick)
    end

    local detachPin = CreateDetachPin(holder, key)
    detachPin:SetPoint("LEFT", holder, "RIGHT", 22, 0)

    return y - ITEM_HEIGHT
end

local function RenderBuffArray(parent, x, y, buffArray)
    local groupSpells = {}
    local groupDisplaySpells = {}
    local groupIconOverrides = {}
    local groupReadyCheckOnly = {}
    local groupFreeConsumable = {}

    for _, buff in ipairs(buffArray) do
        if buff.groupId then
            groupSpells[buff.groupId] = groupSpells[buff.groupId] or {}
            groupDisplaySpells[buff.groupId] = groupDisplaySpells[buff.groupId] or {}
            if buff.spellID then
                local spellList = type(buff.spellID) == "table" and buff.spellID or { buff.spellID }
                for _, id in ipairs(spellList) do
                    tinsert(groupSpells[buff.groupId], id)
                end
            end
            if buff.displaySpells then
                local displayList = type(buff.displaySpells) == "table" and buff.displaySpells or { buff.displaySpells }
                for _, id in ipairs(displayList) do
                    tinsert(groupDisplaySpells[buff.groupId], id)
                end
            end
            if not groupIconOverrides[buff.groupId] then
                groupIconOverrides[buff.groupId] = {}
                groupIconOverrides[buff.groupId]._seen = {}
            end
            local seen = groupIconOverrides[buff.groupId]._seen
            if buff.displayIcon then
                local overrides = type(buff.displayIcon) == "table" and buff.displayIcon or { buff.displayIcon }
                for _, icon in ipairs(overrides) do
                    if not seen[icon] then
                        seen[icon] = true
                        tinsert(groupIconOverrides[buff.groupId], icon)
                    end
                end
            elseif buff.displaySpells then
                local displayList = type(buff.displaySpells) == "table" and buff.displaySpells or { buff.displaySpells }
                for _, id in ipairs(displayList) do
                    local texture = GetBuffTexture(id)
                    if texture and not seen[texture] then
                        seen[texture] = true
                        tinsert(groupIconOverrides[buff.groupId], texture)
                    end
                end
            elseif buff.spellID then
                local primarySpell = type(buff.spellID) == "table" and buff.spellID[1] or buff.spellID
                if primarySpell and primarySpell > 0 then
                    local texture = GetBuffTexture(primarySpell)
                    if texture and not seen[texture] then
                        seen[texture] = true
                        tinsert(groupIconOverrides[buff.groupId], texture)
                    end
                end
            end
            if buff.readyCheckOnly then
                groupReadyCheckOnly[buff.groupId] = true
            end
            if buff.freeConsumable then
                groupFreeConsumable[buff.groupId] = true
            end
        end
    end

    local seenGroups = {}
    for _, buff in ipairs(buffArray) do
        if buff.groupId then
            if not seenGroups[buff.groupId] then
                seenGroups[buff.groupId] = true
                local groupInfo = BuffGroups[buff.groupId]
                local displayIcon = groupIconOverrides[buff.groupId]
                if displayIcon and #displayIcon == 0 then
                    displayIcon = nil
                end
                local displaySpells = groupDisplaySpells[buff.groupId]
                local spells = (#displaySpells > 0) and displaySpells or groupSpells[buff.groupId]
                if #spells == 0 then
                    spells = nil
                end
                y = CreateBuffRow(
                    parent,
                    x,
                    y,
                    spells,
                    buff.groupId,
                    groupInfo and groupInfo.displayName or buff.name,
                    buff.infoTooltip,
                    displayIcon,
                    groupReadyCheckOnly[buff.groupId],
                    groupFreeConsumable[buff.groupId]
                )
            end
        else
            local displaySpells = buff.displaySpells or buff.spellID
            y = CreateBuffRow(
                parent,
                x,
                y,
                displaySpells,
                buff.key,
                buff.name,
                buff.infoTooltip,
                buff.displayIcon,
                buff.readyCheckOnly,
                buff.freeConsumable
            )
        end
    end

    return y
end

BR.Options.BuffRow.Render = RenderBuffArray
BR.Options.BuffRow.CreateRow = CreateBuffRow
