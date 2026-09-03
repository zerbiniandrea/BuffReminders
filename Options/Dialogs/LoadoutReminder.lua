local _, BR = ...

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local CreatePanel = BR.CreatePanel
local StyleEditBox = BR.StyleEditBox

local UpdateDisplay = BR.Display.Update
local ValidateSpellID = BR.Helpers.ValidateSpellID

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local SECTION_GAP = BR.Options.Constants.SECTION_GAP

local BORDER_R, BORDER_G, BORDER_B = unpack(BR.Colors.Border)

local wipe = wipe

local DIALOG_WIDTH = 396
local CONTENT_LEFT = 18
local CONTENT_W = DIALOG_WIDTH - CONTENT_LEFT * 2
-- Shared label column so every labeled row lines its control up at the same x.
local LABEL_W = 100
local DROPDOWN_W = 180
-- Fixed-height slot that holds all three requirement targets (gear / talent /
-- loadout); only one is shown at a time, so the form below it never reflows.
local TARGET_SLOT_H = 44
local BUTTON_BAR = 40

local TLX_SOURCE = BR.Loadouts.TLX_SOURCE
local WOW_SOURCE = "wow"

-- The loadout picker merges WoW loadouts and Talent Loadout Ex loadouts into one
-- list, so an entry id tags the name or configID with its source. A numeric WoW
-- configID and a TLEx name can otherwise collide.
local function LoadoutEntryId(source, key)
    return source .. ":" .. tostring(key)
end

local loadoutDialog = nil

local LOADOUT_SCOPES = BR.Options.LoadoutScopes

-- Per-session counter in the key. time() has one-second resolution, so two rules
-- of the same require type in the same second can collide without it.
local keyCounter = 0
local function GenerateKey(suffix)
    keyCounter = keyCounter + 1
    return "lr_" .. tostring(suffix or "x") .. "_" .. time() .. "_" .. keyCounter
end

local function LayoutSectionHeader(layout, parent, text)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetText("|cffffcc00" .. text .. "|r")
    layout:AddText(header, 14, COMPONENT_GAP)
    return header
end

local function LayoutSeparator(layout, parent)
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetColorTexture(BORDER_R, BORDER_G, BORDER_B, 0.6)
    layout:Add(sep, 1, COMPONENT_GAP)
    sep:SetWidth(CONTENT_W)
end

StaticPopupDialogs["BUFFREMINDERS_DELETE_LOADOUT"] = {
    text = L["Dialog.DeleteLoadout"],
    button1 = L["Options.Delete"],
    button2 = L["Dialog.Cancel"],
    OnAccept = function(_, data)
        if data and data.key then
            BR.profile.loadoutReminders[data.key] = nil
            BR.profile.enabledBuffs[data.key] = nil
            BR.LoadoutReminders.Remove(data.key)
            if data.refreshPanel then
                data.refreshPanel()
            end
            UpdateDisplay()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function Show(existingKey, refreshPanelCallback)
    if loadoutDialog then
        loadoutDialog:Hide()
    end

    ---@type LoadoutRule?
    local editingRule = existingKey and BR.profile.loadoutReminders[existingKey] or nil

    local dialog = CreatePanel("BuffRemindersLoadoutDialog", DIALOG_WIDTH, 360, {
        level = 200,
        dialog = true,
    })
    loadoutDialog = dialog

    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText(editingRule and L["Loadout.Edit"] or L["Loadout.Add"])

    BR.Options.Helpers.AddCloseButton(dialog)

    -- ---- editable state (read on save) ----------------------------------
    local requireType = (editingRule and editingRule.require) or "gear"

    -- gear
    local sets = BR.Loadouts.ListEquipmentSets()
    local selectedSetID = editingRule and editingRule.gear and editingRule.gear.setID

    local specID = BR.Loadouts.GetCurrentSpecID()
    local loadoutEntries = {}
    for _, lo in ipairs(BR.Loadouts.ListLoadouts(specID)) do
        loadoutEntries[#loadoutEntries + 1] = {
            id = LoadoutEntryId(WOW_SOURCE, lo.configID),
            source = WOW_SOURCE,
            configID = lo.configID,
            name = lo.name,
        }
    end
    for _, lo in ipairs(BR.TalentLoadoutEx.ListLoadouts()) do
        loadoutEntries[#loadoutEntries + 1] =
            { id = LoadoutEntryId(TLX_SOURCE, lo.name), source = TLX_SOURCE, name = lo.name, icon = lo.icon }
    end

    local selected = editingRule and editingRule.loadout
    ---@diagnostic disable-next-line: undefined-field
    local selectedSource = (selected and selected.source) or WOW_SOURCE
    local selectedLoadoutId = selected and LoadoutEntryId(selectedSource, selected.configID or selected.name or "")

    -- scope / readyCheck / instances
    local prevWhen = editingRule and editingRule.when or nil
    local scope = (prevWhen and prevWhen.scope) or "dungeon"
    local readyCheckOnly = (prevWhen and prevWhen.readyCheckOnly) or false
    local instances = {}
    if prevWhen and prevWhen.instances then
        for _, inst in ipairs(prevWhen.instances) do
            instances[#instances + 1] = { id = inst.id, mapID = inst.mapID, name = inst.name, kind = inst.kind }
        end
    end
    local instancesExpanded = #instances > 0

    local allInstances = BR.Loadouts.ListCurrentInstances()
    local function InstancesForScope()
        local kind = (scope == "raid") and "raid" or (scope == "dungeon" and "dungeon") or nil
        if not kind then
            return {}
        end
        local out = {}
        for _, inst in ipairs(allInstances) do
            if inst.kind == kind then
                out[#out + 1] = inst
            end
        end
        return out
    end
    local function FindInstanceIndex(inst)
        for idx, stored in ipairs(instances) do
            if stored.name == inst.name and stored.kind == inst.kind then
                return idx
            end
        end
        return nil
    end

    local layout = Components.VerticalLayout(dialog, { x = CONTENT_LEFT, y = -44 })

    -- Name
    local nameHolder = Components.TextInput(dialog, {
        label = L["Loadout.Name"],
        value = editingRule and editingRule.name or "",
        width = 260,
        labelWidth = LABEL_W,
    })
    layout:Add(nameHolder, 20, COMPONENT_GAP)
    local nameBox = nameHolder.editBox

    -- ---- EXPECT: requirement type + target -------------------------------
    LayoutSectionHeader(layout, dialog, L["Loadout.Expect"])

    local UpdateTargetVisibility -- forward decl

    local requireDropdown = Components.Dropdown(dialog, {
        label = L["Loadout.Requirement"],
        labelWidth = LABEL_W,
        width = DROPDOWN_W,
        options = {
            { value = "gear", label = L["Loadout.Require.Gear"] },
            { value = "talent", label = L["Loadout.Require.TalentOption"] },
            { value = "loadout", label = L["Loadout.Require.Loadout"] },
        },
        get = function()
            return requireType
        end,
        onChange = function(val)
            requireType = val
            if UpdateTargetVisibility then
                UpdateTargetVisibility()
            end
        end,
    })
    layout:Add(requireDropdown, nil, COMPONENT_GAP)

    local targetSlot = CreateFrame("Frame", nil, dialog)
    targetSlot:SetSize(CONTENT_W, TARGET_SLOT_H)
    layout:Add(targetSlot, TARGET_SLOT_H, COMPONENT_GAP)

    local function NewNote(text)
        local note = targetSlot:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        note:SetPoint("TOPLEFT", 0, 0)
        note:SetWidth(targetSlot:GetWidth())
        note:SetJustifyH("LEFT")
        note:SetText(text)
        return note
    end

    -- gear target
    local gearWidget
    if #sets > 0 then
        local options = {}
        for _, s in ipairs(sets) do
            options[#options + 1] = { value = s.setID, label = s.name }
        end
        gearWidget = Components.Dropdown(targetSlot, {
            label = L["Loadout.EquipmentSet"],
            labelWidth = LABEL_W,
            width = DROPDOWN_W,
            options = options,
            get = function()
                return selectedSetID
            end,
            onChange = function(val)
                selectedSetID = val
            end,
        })
        gearWidget:SetPoint("TOPLEFT", 0, 0)
    else
        gearWidget = NewNote(L["Loadout.NoSets"])
    end

    -- loadout target
    local loadoutWidget
    if #loadoutEntries > 0 then
        local options = {}
        for _, e in ipairs(loadoutEntries) do
            -- Tag TLEx entries so users can tell the two loadout sources apart when a
            -- WoW loadout and a TLEx loadout share a name.
            local label = (e.source == TLX_SOURCE) and (e.name .. "  " .. L["Loadout.TLXTag"]) or e.name
            options[#options + 1] = { value = e.id, label = label }
        end
        loadoutWidget = Components.Dropdown(targetSlot, {
            label = L["Loadout.Require.Loadout"],
            labelWidth = LABEL_W,
            width = DROPDOWN_W,
            options = options,
            get = function()
                return selectedLoadoutId
            end,
            onChange = function(val)
                selectedLoadoutId = val
            end,
        })
        loadoutWidget:SetPoint("TOPLEFT", 0, 0)
    else
        loadoutWidget = NewNote(L["Loadout.NoLoadouts"])
    end

    -- talent target (label sits in the shared label column; input aligns with the dropdowns)
    local talentLabel = targetSlot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    talentLabel:SetPoint("TOPLEFT", 0, -2)
    talentLabel:SetWidth(LABEL_W)
    talentLabel:SetJustifyH("LEFT")
    talentLabel:SetText(L["Loadout.TalentSpell"])
    local talentEditBox = CreateFrame("EditBox", nil, targetSlot)
    talentEditBox:SetFontObject("GameFontHighlightSmall")
    talentEditBox:SetAutoFocus(false)
    talentEditBox:SetNumeric(true)
    local talentContainer = StyleEditBox(talentEditBox)
    talentContainer:SetSize(90, 20)
    talentContainer:SetPoint("TOPLEFT", targetSlot, "TOPLEFT", LABEL_W, -2)
    if editingRule and editingRule.spellID then
        talentEditBox:SetText(tostring(editingRule.spellID))
    end

    function UpdateTargetVisibility()
        gearWidget:Hide()
        loadoutWidget:Hide()
        talentLabel:Hide()
        talentContainer:Hide()
        if requireType == "gear" then
            gearWidget:Show()
        elseif requireType == "loadout" then
            loadoutWidget:Show()
        elseif requireType == "talent" then
            talentLabel:Show()
            talentContainer:Show()
        end
    end
    UpdateTargetVisibility()

    -- ---- APPLIES TO: content scope + dynamic difficulty / instances ------
    layout:Space(SECTION_GAP)
    LayoutSeparator(layout, dialog)
    layout:Space(8)
    LayoutSectionHeader(layout, dialog, L["Loadout.Applies"])

    local RenderDynamic, RecomputeHeight -- forward decls

    local contentOpts = {}
    for _, tier in ipairs(LOADOUT_SCOPES) do
        contentOpts[#contentOpts + 1] = { value = tier.value, label = L[tier.labelKey] }
    end
    local contentDropdown = Components.Dropdown(dialog, {
        label = L["Loadout.Content"],
        labelWidth = LABEL_W,
        width = DROPDOWN_W,
        options = contentOpts,
        get = function()
            return scope
        end,
        onChange = function(val)
            scope = val
            wipe(instances)
            instancesExpanded = false
            RenderDynamic()
            RecomputeHeight()
        end,
    })
    layout:Add(contentDropdown, nil, COMPONENT_GAP)

    -- Everything below the content dropdown is rebuilt when the scope changes, so the
    -- difficulty row and instance list always match the selected content. The container
    -- is created once at build time and only its children are swapped; a frame created
    -- at runtime here renders nothing.
    local dynTopY = layout:GetY()
    local dynFrame = CreateFrame("Frame", nil, dialog)
    dynFrame:SetPoint("TOPLEFT", CONTENT_LEFT, dynTopY)
    dynFrame:SetSize(CONTENT_W, 1)
    local dynChildren = {}

    -- Ready-check filter: independent of content scope, so it lives outside the
    -- rebuilt region. Anchored to the dynamic frame's bottom edge, it rides along
    -- as the difficulty / instance content grows and shrinks.
    local readyToggle = Components.Toggle(dialog, {
        label = L["CustomBuff.ReadyCheckOnly"],
        checked = readyCheckOnly,
        onChange = function(checked)
            readyCheckOnly = checked
        end,
    })
    readyToggle:SetPoint("TOPLEFT", dynFrame, "BOTTOMLEFT", 0, -SECTION_GAP)
    local READY_H = readyToggle:GetHeight()

    RenderDynamic = function()
        for _, w in ipairs(dynChildren) do
            -- Drop auto-registered holders (instance checkboxes have a `get`) from the
            -- global refresh registry. If they stay, RefreshAll calls their :Refresh()
            -- forever and keeps the closed dialog alive.
            Components.Unregister(w)
            w:Hide()
            if w.SetParent then
                w:SetParent(nil)
            end
        end
        wipe(dynChildren)

        local dl = Components.VerticalLayout(dynFrame, { x = 0, y = 0 })
        local function track(w)
            dynChildren[#dynChildren + 1] = w
            return w
        end

        -- Specific-instance narrowing (raid / dungeon only). If the toggle is off, the
        -- rule matches any instance of the selected content.
        local instOpts = InstancesForScope()
        if #instOpts > 0 then
            local limitLabel = (scope == "raid") and L["Loadout.LimitRaids"] or L["Loadout.LimitDungeons"]
            local limitToggle = track(Components.Toggle(dynFrame, {
                label = limitLabel,
                holderWidth = CONTENT_W,
                labelWidth = CONTENT_W - 40,
                checked = instancesExpanded,
                onChange = function(checked)
                    instancesExpanded = checked
                    if not checked then
                        wipe(instances)
                    end
                    RenderDynamic()
                    RecomputeHeight()
                end,
            }))
            dl:Add(limitToggle, limitToggle:GetHeight(), COMPONENT_GAP)

            if instancesExpanded then
                local INDENT = 18
                local COL_W = (CONTENT_W - INDENT) / 2
                for idx = 1, #instOpts, 2 do
                    local row = {}
                    for col = 0, 1 do
                        local inst = instOpts[idx + col]
                        if inst then
                            local cb = track(Components.Checkbox(dynFrame, {
                                label = inst.name,
                                holderWidth = COL_W,
                                labelWidth = COL_W - 22,
                                get = function()
                                    return FindInstanceIndex(inst) ~= nil
                                end,
                                onChange = function(checked)
                                    local fidx = FindInstanceIndex(inst)
                                    if checked and not fidx then
                                        instances[#instances + 1] =
                                            { id = inst.id, mapID = inst.mapID, name = inst.name, kind = inst.kind }
                                    elseif not checked and fidx then
                                        table.remove(instances, fidx)
                                    end
                                end,
                            }))
                            row[#row + 1] = { cb, INDENT + col * COL_W }
                        end
                    end
                    dl:AddRow(row, COMPONENT_GAP)
                end
            end
        end

        local consumed = -dl:GetY()
        dynFrame:SetHeight(consumed > 0 and consumed or 1)
        dynFrame.consumedHeight = consumed
        dynFrame:Show()
    end

    RecomputeHeight = function()
        dialog:SetHeight(-dynTopY + (dynFrame.consumedHeight or 0) + SECTION_GAP + READY_H + BUTTON_BAR)
        BR.ApplyDialogScale(dialog)
    end

    RenderDynamic()
    RecomputeHeight()

    -- ---- bottom buttons -------------------------------------------------
    local cancelBtn = CreateButton(dialog, L["Dialog.Cancel"], function()
        dialog:Hide()
    end)
    cancelBtn:SetSize(90, 22)

    local saveBtn = CreateButton(dialog, L["CustomBuff.Save"], function()
        local typedName = nameBox:GetText()
        typedName = typedName and typedName:gsub("^%s*(.-)%s*$", "%1") or ""

        -- Scope is always set (no "anywhere" tier), so `when` always carries the
        -- content gate plus the optional instance narrowing / ready-check filter.
        local whenToStore = {
            scope = scope,
            readyCheckOnly = readyCheckOnly or nil,
            instances = (#instances > 0) and instances or nil,
        }

        local key = existingKey or GenerateKey(requireType)
        local rule = {
            key = key,
            require = requireType,
            when = whenToStore,
            clickToFix = true,
            class = select(2, UnitClass("player")), -- class token; colors the binding label in the list
        }

        if requireType == "gear" then
            if not selectedSetID then
                UIErrorsFrame:AddMessage(L["Loadout.NoSetSelected"], 1, 0.3, 0.3)
                return
            end
            local setName, setIcon
            for _, s in ipairs(sets) do
                if s.setID == selectedSetID then
                    setName, setIcon = s.name, s.icon
                    break
                end
            end
            rule.gear = { setID = selectedSetID, name = setName }
            rule.character = BR.Loadouts.GetCurrentCharacterKey() -- setID is per-character
            rule.icon = setIcon
            rule.name = typedName ~= "" and typedName or setName or L["Category.LoadoutReminders"]
            rule.overlayText = setName or rule.name
        elseif requireType == "loadout" then
            local entry
            for _, e in ipairs(loadoutEntries) do
                if e.id == selectedLoadoutId then
                    entry = e
                    break
                end
            end
            if not entry then
                UIErrorsFrame:AddMessage(L["Loadout.NoLoadoutSelected"], 1, 0.3, 0.3)
                return
            end
            rule.specID = specID > 0 and specID or nil -- 0 (no spec) is truthy in Lua; store nil
            local _, _, _, specIcon = GetSpecializationInfoByID(specID)
            if entry.source == TLX_SOURCE then
                -- TLEx loadouts are account-wide by class + spec, so bind by spec only
                -- (no character anchor); detection matches on name via TLEx's API.
                rule.loadout = { name = entry.name, source = TLX_SOURCE }
                rule.icon = entry.icon or specIcon
            else
                rule.character = BR.Loadouts.GetCurrentCharacterKey() -- configID is per-character per-spec
                rule.loadout = { name = entry.name, configID = entry.configID }
                rule.icon = specIcon
            end
            rule.name = typedName ~= "" and typedName or entry.name or L["Category.LoadoutReminders"]
            rule.overlayText = entry.name or rule.name
        elseif requireType == "talent" then
            local spellID = tonumber(talentEditBox:GetText())
            local valid, spellName, spellIcon = false, nil, nil
            if spellID then
                valid, spellName, spellIcon = ValidateSpellID(spellID)
            end
            if not valid then
                UIErrorsFrame:AddMessage(L["Loadout.InvalidSpell"], 1, 0.3, 0.3)
                return
            end
            rule.spellID = spellID
            rule.specID = specID > 0 and specID or nil -- talents live in a spec tree; bind the rule to it (0 = no spec -> nil)
            rule.icon = spellIcon
            rule.name = typedName ~= "" and typedName or spellName or L["Loadout.Require.Talent"]
            rule.overlayText = spellName or L["Loadout.Require.Talent"]
        end

        BR.profile.loadoutReminders[key] = rule
        if BR.profile.enabledBuffs[key] == nil then
            BR.profile.enabledBuffs[key] = true
        end

        -- Recreate the frame so the new def / icon take effect.
        if existingKey then
            BR.LoadoutReminders.Remove(key)
        end
        BR.LoadoutReminders.CreateRuntime(rule)

        dialog:Hide()
        if refreshPanelCallback then
            refreshPanelCallback()
        end
        UpdateDisplay()
    end)
    saveBtn:SetSize(90, 22)
    saveBtn:SetPoint("BOTTOMRIGHT", -CONTENT_LEFT, 14)
    cancelBtn:SetPoint("RIGHT", saveBtn, "LEFT", -10, 0)

    if existingKey then
        local deleteBtn = CreateButton(dialog, L["Options.Delete"], function()
            dialog:Hide()
            StaticPopup_Show("BUFFREMINDERS_DELETE_LOADOUT", (editingRule and editingRule.name) or existingKey, nil, {
                key = existingKey,
                refreshPanel = refreshPanelCallback,
            })
        end)
        deleteBtn:SetSize(90, 22)
        deleteBtn:SetPoint("BOTTOMLEFT", CONTENT_LEFT, 14)
    end

    dialog:Show()
end

BR.Options.Dialogs.LoadoutReminder = { Show = Show }
