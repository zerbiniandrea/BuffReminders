local _, BR = ...

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local CreatePanel = BR.CreatePanel
local CreateBuffIcon = BR.CreateBuffIcon
local StyleEditBox = BR.StyleEditBox

local UpdateDisplay = BR.Display.Update
local ValidateSpellID = BR.Helpers.ValidateSpellID
local ValidateItemID = BR.Helpers.ValidateItemID
local GenerateCustomBuffKey = BR.Helpers.GenerateCustomBuffKey

local CreateCustomBuffFrameRuntime = BR.CustomBuffs.CreateRuntime
local RemoveCustomBuffFrame = BR.CustomBuffs.Remove
local UpdateCustomBuffFrame = BR.CustomBuffs.UpdateFrame

local tinsert = table.insert
local tremove = table.remove

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local SECTION_GAP = BR.Options.Constants.SECTION_GAP

local customBuffDialog = nil

-- Layout-aware section header (uses VerticalLayout instead of manual Y tracking)
local function LayoutSectionHeader(layout, parent, text)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetText("|cffffcc00" .. text .. "|r")
    layout:AddText(header, 14, COMPONENT_GAP)
    return header
end

-- Delete confirmation dialog for custom buffs
StaticPopupDialogs["BUFFREMINDERS_DELETE_CUSTOM"] = {
    text = L["Dialog.DeleteCustomBuff"],
    button1 = L["Options.Delete"],
    button2 = L["Dialog.Cancel"],
    OnAccept = function(_, data)
        if data and data.key then
            BR.profile.customBuffs[data.key] = nil
            BR.profile.enabledBuffs[data.key] = nil
            RemoveCustomBuffFrame(data.key)
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
    if customBuffDialog then
        customBuffDialog:Hide()
    end

    local DIALOG_WIDTH = 520
    local DROPDOWN_LABEL_W = 80
    local DROPDOWN_W = 150
    local BASE_HEIGHT = 706
    local ROW_HEIGHT = 26
    local CONTENT_LEFT = 20
    local ROWS_START_Y = -60
    local editingBuff = existingKey and BR.profile.customBuffs[existingKey] or nil
    local noop = function() end

    local existingSpellIDs = {}
    if editingBuff then
        if type(editingBuff.spellID) == "table" then
            for _, id in ipairs(editingBuff.spellID) do
                tinsert(existingSpellIDs, id)
            end
        else
            tinsert(existingSpellIDs, editingBuff.spellID)
        end
    end

    local dialog = CreatePanel("BuffRemindersCustomBuffDialog", DIALOG_WIDTH, BASE_HEIGHT, {
        level = 200,
        dialog = true,
    })

    local spellRows, nameBox, overlayBox
    local castSpellEditBox, castItemEditBox, macroEditBox, requireItemEditBox, requireItemModeDropdown

    dialog:SetScript("OnHide", function()
        if spellRows then
            for _, rowData in ipairs(spellRows) do
                if rowData.editBox then
                    rowData.editBox:ClearFocus()
                end
            end
        end
        if nameBox then
            nameBox:ClearFocus()
        end
        if overlayBox then
            overlayBox:ClearFocus()
        end
        if castSpellEditBox then
            castSpellEditBox:ClearFocus()
        end
        if castItemEditBox then
            castItemEditBox:ClearFocus()
        end
        if macroEditBox then
            macroEditBox:ClearFocus()
        end
        if requireItemEditBox then
            requireItemEditBox:ClearFocus()
        end
    end)

    local dialogTitle = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    dialogTitle:SetPoint("TOP", 0, -12)
    dialogTitle:SetText(editingBuff and L["CustomBuff.Edit"] or L["CustomBuff.Add"])

    local dialogCloseBtn = CreateButton(dialog, "x", function()
        dialog:Hide()
    end)
    dialogCloseBtn:SetSize(22, 22)
    dialogCloseBtn:SetPoint("TOPRIGHT", -5, -5)

    local spellIdsLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    spellIdsLabel:SetPoint("TOPLEFT", CONTENT_LEFT, -40)
    spellIdsLabel:SetText(L["CustomBuff.SpellIDs"])

    spellRows = {}

    local addSpellBtn, sectionsFrame
    local showIconToggle
    local glowModeDropdown, requireSpellKnownToggle
    local classDropdownHolder
    local specDropdownHolder
    local actionTypeDropdown
    local actionInputHolder

    local function UpdateLayout()
        local rowCount = #spellRows

        for i, rowData in ipairs(spellRows) do
            rowData.frame:ClearAllPoints()
            rowData.frame:SetPoint("TOPLEFT", dialog, "TOPLEFT", CONTENT_LEFT, ROWS_START_Y - ((i - 1) * ROW_HEIGHT))
            if rowCount > 1 then
                rowData.removeBtn:Show()
            else
                rowData.removeBtn:Hide()
            end
        end

        local addBtnY = ROWS_START_Y - (rowCount * ROW_HEIGHT) - 4
        addSpellBtn:ClearAllPoints()
        addSpellBtn:SetPoint("TOPLEFT", dialog, "TOPLEFT", CONTENT_LEFT, addBtnY)

        sectionsFrame:ClearAllPoints()
        sectionsFrame:SetPoint("TOPLEFT", dialog, "TOPLEFT", CONTENT_LEFT, addBtnY - 28)

        local extraRows = math.max(0, rowCount - 1)
        dialog:SetHeight(BASE_HEIGHT + (extraRows * ROW_HEIGHT))
    end

    local function CreateSpellRow(initialSpellID)
        local rowFrame = CreateFrame("Frame", nil, dialog)
        rowFrame:SetSize(DIALOG_WIDTH - 40, ROW_HEIGHT - 2)

        local editBox = CreateFrame("EditBox", nil, rowFrame)
        editBox:SetFontObject("GameFontHighlightSmall")
        editBox:SetAutoFocus(false)
        local editContainer = StyleEditBox(editBox)
        editContainer:SetSize(70, 20)
        editContainer:SetPoint("LEFT", 0, 0)
        if initialSpellID then
            editBox:SetText(tostring(initialSpellID))
        end

        local doLookup -- forward declare for onClick
        local lookupBtn = CreateButton(rowFrame, L["CustomBuff.Lookup"], function()
            doLookup()
        end)
        lookupBtn:SetSize(55, 20)
        lookupBtn:SetPoint("LEFT", editContainer, "RIGHT", 5, 0)

        local icon = CreateBuffIcon(rowFrame, 18)
        icon:SetPoint("LEFT", lookupBtn, "RIGHT", 8, 0)
        icon:Hide()

        local nameText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameText:SetPoint("LEFT", icon, "RIGHT", 5, 0)
        nameText:SetPoint("RIGHT", rowFrame, "RIGHT", -28, 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetWordWrap(false)

        local removeBtn = CreateButton(rowFrame, "-", nil)
        removeBtn:SetSize(22, 20)
        removeBtn:SetPoint("RIGHT", 0, 0)
        removeBtn:Hide()

        local rowData = {
            frame = rowFrame,
            editBox = editBox,
            icon = icon,
            nameText = nameText,
            removeBtn = removeBtn,
            validated = false,
            spellID = nil,
            spellName = nil,
        }

        removeBtn:SetScript("OnClick", function()
            for i, rd in ipairs(spellRows) do
                if rd == rowData then
                    rowData.frame:Hide()
                    tremove(spellRows, i)
                    UpdateLayout()
                    break
                end
            end
        end)

        doLookup = function()
            local spellID = tonumber(editBox:GetText())
            if not spellID then
                icon:Hide()
                nameText:SetText("|cffff4d4d" .. L["CustomBuff.InvalidID"] .. "|r")
                rowData.validated, rowData.spellID, rowData.spellName = false, nil, nil
                return
            end

            local valid, name, iconID = ValidateSpellID(spellID)
            if valid then
                icon:SetTexture(iconID)
                icon:Show()
                nameText:SetText(name or "")
                rowData.validated, rowData.spellID, rowData.spellName = true, spellID, name
            else
                icon:Hide()
                nameText:SetText("|cffff4d4d" .. L["CustomBuff.NotFound"] .. "|r")
                rowData.validated, rowData.spellID, rowData.spellName = false, nil, nil
            end
        end

        tinsert(spellRows, rowData)

        if initialSpellID then
            doLookup()
        end

        return rowData
    end

    addSpellBtn = CreateButton(dialog, L["CustomBuff.AddSpellID"], function()
        CreateSpellRow(nil)
        UpdateLayout()
    end)

    -- Sections frame (always visible, below add-spell button)
    sectionsFrame = CreateFrame("Frame", nil, dialog)
    sectionsFrame:SetSize(DIALOG_WIDTH - 40, 526)

    local secLayout = Components.VerticalLayout(sectionsFrame, { x = 0, y = 0 })

    local function LayoutSeparator()
        local line = sectionsFrame:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", 0, secLayout:GetY())
        line:SetPoint("RIGHT", 0, 0)
        line:SetColorTexture(0.25, 0.25, 0.25, 0.8)
        secLayout:Space(1)
    end

    -- Appearance section
    LayoutSeparator()
    secLayout:Space(8)
    LayoutSectionHeader(secLayout, sectionsFrame, L["CustomBuff.Appearance"])

    local nameHolder = Components.TextInput(sectionsFrame, {
        label = L["CustomBuff.Name"],
        value = editingBuff and editingBuff.name or "",
        width = 280,
        labelWidth = 50,
    })
    secLayout:Add(nameHolder, 20, COMPONENT_GAP)
    nameBox = nameHolder.editBox

    local overlayHolder = Components.TextInput(sectionsFrame, {
        label = L["CustomBuff.Text"],
        value = editingBuff and editingBuff.overlayText and editingBuff.overlayText:gsub("\n", "\\n") or "",
        width = 280,
        labelWidth = 50,
    })
    secLayout:Add(overlayHolder, 20, SECTION_GAP)
    overlayBox = overlayHolder.editBox

    local overlayHint = sectionsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    overlayHint:SetPoint("LEFT", overlayHolder, "RIGHT", 5, 0)
    overlayHint:SetPoint("RIGHT", sectionsFrame, "RIGHT", 0, 0)
    overlayHint:SetWordWrap(false)
    overlayHint:SetText(L["CustomBuff.LineBreakHint"])

    -- Buff tracking section
    secLayout:Space(SECTION_GAP)
    LayoutSeparator()
    secLayout:Space(8)
    LayoutSectionHeader(secLayout, sectionsFrame, L["CustomBuff.BuffTracking"])

    showIconToggle = Components.Toggle(sectionsFrame, {
        label = editingBuff and editingBuff.showWhenPresent and L["CustomBuff.WhenActive"]
            or L["CustomBuff.WhenMissing"],
        checked = editingBuff and editingBuff.showWhenPresent or false,
        onChange = function(isChecked)
            if isChecked then
                showIconToggle.label:SetText(L["CustomBuff.WhenActive"])
            else
                showIconToggle.label:SetText(L["CustomBuff.WhenMissing"])
            end
            Components.RefreshAll()
        end,
    })
    secLayout:Add(showIconToggle, nil, COMPONENT_GAP)

    local expirationThresholdHolder = Components.Slider(sectionsFrame, {
        label = L["Options.Expiration"],
        labelWidth = DROPDOWN_LABEL_W,
        min = 0,
        max = 45,
        step = 5,
        get = function()
            if editingBuff and editingBuff.expirationThreshold then
                return editingBuff.expirationThreshold
            end
            return 15
        end,
        formatValue = function(val)
            return val == 0 and L["Options.Off"] or (val .. " " .. L["Options.Min"])
        end,
        enabled = function()
            return not showIconToggle:GetChecked()
        end,
        onChange = noop,
    })
    secLayout:Add(expirationThresholdHolder, nil, COMPONENT_GAP)

    -- Requirements section
    secLayout:Space(SECTION_GAP)
    LayoutSeparator()
    secLayout:Space(8)
    LayoutSectionHeader(secLayout, sectionsFrame, L["CustomBuff.Requirements"])

    local classOptions = {
        { value = nil, label = L["Class.Any"] },
        { value = "DEATHKNIGHT", label = L["Class.DeathKnight"] },
        { value = "DEMONHUNTER", label = L["Class.DemonHunter"] },
        { value = "DRUID", label = L["Class.Druid"] },
        { value = "EVOKER", label = L["Class.Evoker"] },
        { value = "HUNTER", label = L["Class.Hunter"] },
        { value = "MAGE", label = L["Class.Mage"] },
        { value = "MONK", label = L["Class.Monk"] },
        { value = "PALADIN", label = L["Class.Paladin"] },
        { value = "PRIEST", label = L["Class.Priest"] },
        { value = "ROGUE", label = L["Class.Rogue"] },
        { value = "SHAMAN", label = L["Class.Shaman"] },
        { value = "WARLOCK", label = L["Class.Warlock"] },
        { value = "WARRIOR", label = L["Class.Warrior"] },
    }

    local classRowY = secLayout:GetY()

    local function CreateSpecDropdown(classToken, selectedSpecId)
        if specDropdownHolder then
            specDropdownHolder:Hide()
            specDropdownHolder = nil
        end
        if not classToken then
            return
        end
        local specOptions = BR.CLASS_SPEC_OPTIONS[classToken]
        if not specOptions then
            return
        end
        specDropdownHolder = Components.Dropdown(sectionsFrame, {
            label = L["CustomBuff.Spec"],
            options = specOptions,
            selected = selectedSpecId,
            width = DROPDOWN_W,
            labelWidth = 50,
            onChange = noop,
        })
        specDropdownHolder:SetPoint("TOPLEFT", sectionsFrame, "TOPLEFT", 250, classRowY)
    end

    classDropdownHolder = Components.Dropdown(sectionsFrame, {
        label = L["CustomBuff.Class"],
        options = classOptions,
        selected = editingBuff and editingBuff.class or nil,
        width = DROPDOWN_W,
        labelWidth = DROPDOWN_LABEL_W,
        maxItems = 10,
        onChange = function(value)
            CreateSpecDropdown(value, nil)
        end,
    }, "BuffRemindersCustomClassDropdown")
    secLayout:Add(classDropdownHolder, nil, COMPONENT_GAP)

    -- Initialize spec dropdown for editing existing buff
    if editingBuff and editingBuff.class then
        CreateSpecDropdown(editingBuff.class, editingBuff.requireSpecId)
    end

    requireSpellKnownToggle = Components.Toggle(sectionsFrame, {
        label = L["CustomBuff.OnlyIfSpellKnown"],
        checked = editingBuff and editingBuff.requireSpellKnown or false,
        onChange = noop,
    })
    secLayout:Add(requireSpellKnownToggle, nil, COMPONENT_GAP)

    -- Require item (item gate)
    local requireItemLabel = sectionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    requireItemLabel:SetText(L["CustomBuff.RequireItem"])
    requireItemLabel:SetWidth(DROPDOWN_LABEL_W)
    requireItemLabel:SetJustifyH("LEFT")
    secLayout:AddText(requireItemLabel, 14, COMPONENT_GAP)

    requireItemEditBox = CreateFrame("EditBox", nil, sectionsFrame)
    requireItemEditBox:SetFontObject("GameFontHighlightSmall")
    requireItemEditBox:SetAutoFocus(false)
    local requireItemContainer = StyleEditBox(requireItemEditBox)
    requireItemContainer:SetSize(70, 20)
    requireItemContainer:SetPoint("LEFT", requireItemLabel, "RIGHT", 5, 0)
    if editingBuff and editingBuff.requireItemID then
        requireItemEditBox:SetText(tostring(editingBuff.requireItemID))
    end

    local requireItemModeOptions = {
        { value = "owned", label = L["CustomBuff.RequireItem.EquippedBags"] },
        { value = "equipped", label = L["CustomBuff.RequireItem.Equipped"] },
        { value = "bags", label = L["CustomBuff.RequireItem.InBags"] },
    }
    local currentRequireItemMode = editingBuff and editingBuff.requireItemMode or "owned"
    requireItemModeDropdown = Components.Dropdown(sectionsFrame, {
        label = "",
        labelWidth = 0,
        options = requireItemModeOptions,
        selected = currentRequireItemMode,
        width = DROPDOWN_W,
        onChange = noop,
    })
    requireItemModeDropdown:SetPoint("LEFT", requireItemContainer, "RIGHT", 5, 0)

    local requireItemHint = sectionsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    requireItemHint:SetPoint("LEFT", requireItemModeDropdown, "RIGHT", 5, 0)
    requireItemHint:SetPoint("RIGHT", sectionsFrame, "RIGHT", 0, 0)
    requireItemHint:SetWordWrap(false)
    requireItemHint:SetText(L["CustomBuff.RequireItem.Hint"])

    local itemCooldownOptions = {
        { value = nil, label = L["CustomBuff.ItemCooldown.Any"] },
        { value = "offCooldown", label = L["CustomBuff.ItemCooldown.OffCooldown"] },
        { value = "onCooldown", label = L["CustomBuff.ItemCooldown.OnCooldown"] },
    }
    local currentItemCooldown = editingBuff and editingBuff.itemCooldownCondition or nil
    local itemCooldownDropdown = Components.Dropdown(sectionsFrame, {
        label = L["CustomBuff.ItemCooldown"],
        labelWidth = DROPDOWN_LABEL_W,
        options = itemCooldownOptions,
        selected = currentItemCooldown,
        width = DROPDOWN_W,
        onChange = noop,
    })
    secLayout:Add(itemCooldownDropdown, nil, COMPONENT_GAP)

    local function UpdateItemFieldsVisibility()
        local hasItem = requireItemEditBox:GetText() ~= ""
        if hasItem then
            requireItemModeDropdown:Show()
            requireItemHint:Show()
            itemCooldownDropdown:Show()
        else
            requireItemModeDropdown:Hide()
            requireItemHint:Hide()
            itemCooldownDropdown:Hide()
        end
    end
    UpdateItemFieldsVisibility()
    requireItemEditBox:HookScript("OnTextChanged", function()
        UpdateItemFieldsVisibility()
    end)

    local glowModeOptions = {
        { value = "whenGlowing", label = L["CustomBuff.BarGlow.WhenGlowing"] },
        { value = "whenNotGlowing", label = L["CustomBuff.BarGlow.WhenNotGlowing"] },
        { value = "disabled", label = L["CustomBuff.BarGlow.Disabled"] },
    }
    local currentGlowMode = editingBuff and editingBuff.glowMode or "disabled"
    glowModeDropdown = Components.Dropdown(sectionsFrame, {
        label = L["CustomBuff.BarGlow"],
        labelWidth = DROPDOWN_LABEL_W,
        options = glowModeOptions,
        selected = currentGlowMode,
        width = DROPDOWN_W,
        tooltip = {
            title = L["CustomBuff.BarGlow.Title"],
            desc = L["CustomBuff.BarGlow.Desc"],
        },
        onChange = noop,
    })
    secLayout:Add(glowModeDropdown, nil, COMPONENT_GAP)

    -- Show In section (per-buff content visibility)
    secLayout:Space(SECTION_GAP)
    LayoutSeparator()
    secLayout:Space(8)
    LayoutSectionHeader(secLayout, sectionsFrame, L["CustomBuff.ShowIn"])

    -- Local state for load conditions (read on save)
    local loadConditions = {}
    if editingBuff and editingBuff.loadConditions then
        for k, v in pairs(editingBuff.loadConditions) do
            if type(v) == "table" then
                loadConditions[k] = {}
                for dk, dv in pairs(v) do
                    loadConditions[k][dk] = dv
                end
            else
                loadConditions[k] = v
            end
        end
    elseif not editingBuff then
        -- New buff defaults: housing off (matches old category-level default)
        loadConditions.housing = false
    end

    -- Reuse VisibilityToggles with a table-backed store instead of DB-backed
    local visToggles = Components.VisibilityToggles(sectionsFrame, {
        store = {
            getContent = function(key)
                return loadConditions[key] ~= false
            end,
            setContent = function(key)
                if loadConditions[key] ~= false then
                    loadConditions[key] = false
                else
                    loadConditions[key] = nil
                end
            end,
            getDiffTable = function(dbKey)
                return loadConditions[dbKey]
            end,
            ensureDiffTable = function(dbKey)
                if not loadConditions[dbKey] then
                    loadConditions[dbKey] = {}
                end
                return loadConditions[dbKey]
            end,
        },
        noAutoRefresh = true,
        onChange = noop,
    })
    secLayout:Add(visToggles, nil, COMPONENT_GAP)

    -- Ready check toggle
    local lcReadyCheckToggle = Components.Toggle(sectionsFrame, {
        label = L["CustomBuff.ReadyCheckOnly"],
        checked = editingBuff and editingBuff.loadConditions and editingBuff.loadConditions.readyCheckOnly or false,
        onChange = function(isChecked)
            loadConditions.readyCheckOnly = isChecked or nil
        end,
    })
    secLayout:Add(lcReadyCheckToggle, nil, COMPONENT_GAP)

    -- Level filter dropdown
    local levelFilterHolder = Components.Dropdown(sectionsFrame, {
        label = L["CustomBuff.Level"],
        labelWidth = DROPDOWN_LABEL_W,
        width = DROPDOWN_W,
        options = {
            { value = "any", label = L["CustomBuff.Level.Any"] },
            { value = "maxLevel", label = L["CustomBuff.Level.Max"] },
            { value = "belowMaxLevel", label = L["CustomBuff.Level.BelowMax"] },
        },
        get = function()
            local lf = loadConditions.levelFilter
            return lf or "any"
        end,
        onChange = function(val)
            loadConditions.levelFilter = (val ~= "any") and val or nil
        end,
    })
    secLayout:Add(levelFilterHolder, nil, COMPONENT_GAP)

    -- Click action section
    secLayout:Space(SECTION_GAP)
    LayoutSeparator()
    secLayout:Space(8)
    LayoutSectionHeader(secLayout, sectionsFrame, L["CustomBuff.ClickAction"])

    -- Determine existing action type
    local existingActionType = "none"
    if editingBuff then
        if editingBuff.castMacro and editingBuff.castMacro ~= "" then
            existingActionType = "macro"
        elseif editingBuff.castItemID then
            existingActionType = "item"
        elseif editingBuff.castSpellID then
            existingActionType = "spell"
        end
    end

    -- Container for the conditional input (spell/item Lookup or macro text)
    actionInputHolder = CreateFrame("Frame", nil, sectionsFrame)
    actionInputHolder:SetSize(DIALOG_WIDTH - 40, 26)

    -- Spell ID input with Lookup
    castSpellEditBox = CreateFrame("EditBox", nil, actionInputHolder)
    castSpellEditBox:SetFontObject("GameFontHighlightSmall")
    castSpellEditBox:SetAutoFocus(false)
    local castSpellContainer = StyleEditBox(castSpellEditBox)
    castSpellContainer:SetSize(70, 20)
    castSpellContainer:SetPoint("LEFT", 0, 0)
    if editingBuff and editingBuff.castSpellID then
        castSpellEditBox:SetText(tostring(editingBuff.castSpellID))
    end

    local castSpellIcon = CreateBuffIcon(actionInputHolder, 18)
    castSpellIcon:SetPoint("LEFT", castSpellContainer, "RIGHT", 68, 0)
    castSpellIcon:Hide()

    local castSpellName = actionInputHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    castSpellName:SetPoint("LEFT", castSpellIcon, "RIGHT", 5, 0)
    castSpellName:SetPoint("RIGHT", actionInputHolder, "RIGHT", 0, 0)
    castSpellName:SetJustifyH("LEFT")
    castSpellName:SetWordWrap(false)

    local castSpellLookupBtn = CreateButton(actionInputHolder, L["CustomBuff.Lookup"], function()
        local id = tonumber(castSpellEditBox:GetText())
        if not id then
            castSpellIcon:Hide()
            castSpellName:SetText("|cffff4d4d" .. L["CustomBuff.InvalidID"] .. "|r")
            return
        end
        local valid, name, iconID = ValidateSpellID(id)
        if valid then
            castSpellIcon:SetTexture(iconID)
            castSpellIcon:Show()
            castSpellName:SetText(name or "")
        else
            castSpellIcon:Hide()
            castSpellName:SetText("|cffff4d4d" .. L["CustomBuff.NotFound"] .. "|r")
        end
    end)
    castSpellLookupBtn:SetSize(55, 20)
    castSpellLookupBtn:SetPoint("LEFT", castSpellContainer, "RIGHT", 5, 0)

    -- Item ID input with Lookup
    castItemEditBox = CreateFrame("EditBox", nil, actionInputHolder)
    castItemEditBox:SetFontObject("GameFontHighlightSmall")
    castItemEditBox:SetAutoFocus(false)
    local castItemContainer = StyleEditBox(castItemEditBox)
    castItemContainer:SetSize(70, 20)
    castItemContainer:SetPoint("LEFT", 0, 0)
    if editingBuff and editingBuff.castItemID then
        castItemEditBox:SetText(tostring(editingBuff.castItemID))
    end

    local castItemIcon = CreateBuffIcon(actionInputHolder, 18)
    castItemIcon:SetPoint("LEFT", castItemContainer, "RIGHT", 68, 0)
    castItemIcon:Hide()

    local castItemName = actionInputHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    castItemName:SetPoint("LEFT", castItemIcon, "RIGHT", 5, 0)
    castItemName:SetPoint("RIGHT", actionInputHolder, "RIGHT", 0, 0)
    castItemName:SetJustifyH("LEFT")
    castItemName:SetWordWrap(false)

    local castItemLookupBtn = CreateButton(actionInputHolder, L["CustomBuff.Lookup"], function()
        local id = tonumber(castItemEditBox:GetText())
        if not id then
            castItemIcon:Hide()
            castItemName:SetText("|cffff4d4d" .. L["CustomBuff.InvalidID"] .. "|r")
            return
        end
        local valid, name, iconID = ValidateItemID(id)
        if valid then
            castItemIcon:SetTexture(iconID)
            castItemIcon:Show()
            castItemName:SetText(name or "")
        else
            castItemIcon:Hide()
            castItemName:SetText("|cffff4d4d" .. L["CustomBuff.NotFoundRetry"] .. "|r")
            -- Request item data load for next lookup attempt
            pcall(C_Item.RequestLoadItemDataByID, id)
        end
    end)
    castItemLookupBtn:SetSize(55, 20)
    castItemLookupBtn:SetPoint("LEFT", castItemContainer, "RIGHT", 5, 0)

    -- Macro text input
    local macroHolder = Components.TextInput(actionInputHolder, {
        label = "",
        value = editingBuff and editingBuff.castMacro or "",
        width = DIALOG_WIDTH - 80,
        labelWidth = 0,
    })
    macroHolder:SetPoint("LEFT", 0, 0)
    macroEditBox = macroHolder.editBox

    local macroHint = actionInputHolder:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    macroHint:SetPoint("TOPLEFT", 0, -24)
    macroHint:SetText(L["CustomBuff.Action.MacroHint"])

    -- Show/hide inputs based on action type
    local function UpdateActionInputVisibility(actionType)
        -- Hide all first
        castSpellContainer:Hide()
        castSpellLookupBtn:Hide()
        castSpellIcon:Hide()
        castSpellName:SetText("")
        castItemContainer:Hide()
        castItemLookupBtn:Hide()
        castItemIcon:Hide()
        castItemName:SetText("")
        macroHolder:Hide()
        macroHint:Hide()

        if actionType == "spell" then
            castSpellContainer:Show()
            castSpellLookupBtn:Show()
            -- Trigger lookup if there's a value
            if castSpellEditBox:GetText() ~= "" then
                local id = tonumber(castSpellEditBox:GetText())
                if id then
                    local valid, name, iconID = ValidateSpellID(id)
                    if valid then
                        castSpellIcon:SetTexture(iconID)
                        castSpellIcon:Show()
                        castSpellName:SetText(name or "")
                    end
                end
            end
        elseif actionType == "item" then
            castItemContainer:Show()
            castItemLookupBtn:Show()
            -- Trigger lookup if there's a value
            if castItemEditBox:GetText() ~= "" then
                local id = tonumber(castItemEditBox:GetText())
                if id then
                    local valid, name, iconID = ValidateItemID(id)
                    if valid then
                        castItemIcon:SetTexture(iconID)
                        castItemIcon:Show()
                        castItemName:SetText(name or "")
                    end
                end
            end
        elseif actionType == "macro" then
            macroHolder:Show()
            macroHint:Show()
        end
    end

    local actionTypeOptions = {
        { value = "none", label = L["CustomBuff.Action.None"] },
        { value = "spell", label = L["CustomBuff.Action.Spell"] },
        { value = "item", label = L["CustomBuff.Action.Item"] },
        { value = "macro", label = L["CustomBuff.Action.Macro"] },
    }
    actionTypeDropdown = Components.Dropdown(sectionsFrame, {
        label = L["CustomBuff.Action.OnClick"],
        labelWidth = DROPDOWN_LABEL_W,
        options = actionTypeOptions,
        selected = existingActionType,
        width = DROPDOWN_W,
        tooltip = {
            title = L["CustomBuff.Action.Title"],
            desc = L["CustomBuff.Action.Desc"],
        },
        onChange = function(value)
            UpdateActionInputVisibility(value)
        end,
    })
    secLayout:Add(actionTypeDropdown, nil, COMPONENT_GAP)
    secLayout:Add(actionInputHolder, 26)

    -- Initialize visibility for the current action type
    UpdateActionInputVisibility(existingActionType)

    local saveError = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    saveError:SetPoint("BOTTOMLEFT", 20, 42)
    saveError:SetWidth(DIALOG_WIDTH - 120)
    saveError:SetJustifyH("LEFT")
    saveError:SetTextColor(1, 0.3, 0.3)

    local cancelBtn = CreateButton(dialog, L["Dialog.Cancel"], function()
        dialog:Hide()
    end)
    cancelBtn:SetPoint("BOTTOMRIGHT", -20, 15)

    -- Delete button (only when editing existing buff)
    if existingKey and editingBuff then
        local buffName = editingBuff.name or existingKey
        local deleteBtn = CreateButton(dialog, L["Options.Delete"], function()
            dialog:Hide()
            StaticPopup_Show("BUFFREMINDERS_DELETE_CUSTOM", buffName, nil, {
                key = existingKey,
                refreshPanel = refreshPanelCallback,
            })
        end)
        deleteBtn:SetPoint("BOTTOMLEFT", 20, 15)
    end

    local saveBtn = CreateButton(dialog, L["CustomBuff.Save"], function()
        local validatedIDs = {}
        local firstName = nil
        for _, rowData in ipairs(spellRows) do
            if rowData.validated and rowData.spellID then
                tinsert(validatedIDs, rowData.spellID)
                if not firstName then
                    firstName = rowData.spellName
                end
            end
        end

        if #validatedIDs == 0 then
            saveError:SetText(L["CustomBuff.ValidateError"])
            return
        end
        saveError:SetText("")

        local spellIDValue = #validatedIDs == 1 and validatedIDs[1] or validatedIDs
        local key = existingKey or GenerateCustomBuffKey(spellIDValue)
        local displayName = nameBox:GetText()
        if displayName == "" then
            displayName = firstName or (L["CustomBuff.Action.Spell"] .. " " .. validatedIDs[1])
        end

        local overlayTextValue = strtrim(overlayBox:GetText())
        if overlayTextValue ~= "" then
            overlayTextValue = overlayTextValue:gsub("\\n", "\n")
        else
            overlayTextValue = nil
        end

        -- Resolve click action fields based on selected action type
        local selectedAction = actionTypeDropdown:GetValue()
        local castSpellIDValue = nil
        local castItemIDValue = nil
        local castMacroValue = nil
        if selectedAction == "spell" then
            castSpellIDValue = tonumber(strtrim(castSpellEditBox:GetText())) or nil
        elseif selectedAction == "item" then
            castItemIDValue = tonumber(strtrim(castItemEditBox:GetText())) or nil
        elseif selectedAction == "macro" then
            local macroText = strtrim(macroEditBox:GetText())
            if macroText ~= "" then
                castMacroValue = macroText
            end
        end

        -- Only persist loadConditions if any value differs from default (all-enabled)
        -- Clean up difficulty sub-tables where all entries are enabled (true/nil)
        for _, diffKey in ipairs({ "dungeonDifficulty", "raidDifficulty" }) do
            local dt = loadConditions[diffKey]
            if dt then
                local anyOff = false
                for _, v in pairs(dt) do
                    if v == false then
                        anyOff = true
                        break
                    end
                end
                if not anyOff then
                    loadConditions[diffKey] = nil
                end
            end
        end

        local savedLoadConditions = nil
        local function hasNonDefault(t)
            for _, v in pairs(t) do
                if type(v) == "table" then
                    if hasNonDefault(v) then
                        return true
                    end
                else
                    return true
                end
            end
            return false
        end
        if hasNonDefault(loadConditions) then
            savedLoadConditions = loadConditions
        end

        local customBuff = {
            spellID = spellIDValue,
            key = key,
            name = displayName,
            overlayText = overlayTextValue,
            class = classDropdownHolder:GetValue(),
            requireSpecId = specDropdownHolder and specDropdownHolder:GetValue() or nil,
            showWhenPresent = showIconToggle:GetChecked() or nil,
            requireSpellKnown = requireSpellKnownToggle:GetChecked() or nil,
            glowMode = glowModeDropdown:GetValue() ~= "disabled" and glowModeDropdown:GetValue() or nil,
            expirationThreshold = not showIconToggle:GetChecked() and expirationThresholdHolder:GetValue() or 0,
            castSpellID = castSpellIDValue,
            castItemID = castItemIDValue,
            castMacro = castMacroValue,
            requireItemID = tonumber(strtrim(requireItemEditBox:GetText())) or nil,
            requireItemMode = requireItemModeDropdown:GetValue() ~= "owned" and requireItemModeDropdown:GetValue()
                or nil,
            itemCooldownCondition = tonumber(strtrim(requireItemEditBox:GetText())) and itemCooldownDropdown:GetValue()
                or nil,
            loadConditions = savedLoadConditions,
        }

        BR.profile.customBuffs[key] = customBuff

        if not existingKey then
            CreateCustomBuffFrameRuntime(customBuff)
        else
            UpdateCustomBuffFrame(key, spellIDValue, displayName)
        end

        dialog:Hide()
        -- requireItemMode may have changed; clear cached item ownership so the new mode is evaluated
        BR.BuffState.InvalidateItemCache()
        if refreshPanelCallback then
            refreshPanelCallback()
        end
        UpdateDisplay()
    end)
    saveBtn:SetPoint("RIGHT", cancelBtn, "LEFT", -10, 0)

    if #existingSpellIDs > 0 then
        for _, spellID in ipairs(existingSpellIDs) do
            CreateSpellRow(spellID)
        end
    else
        CreateSpellRow(nil)
    end

    UpdateLayout()

    customBuffDialog = dialog
    dialog:Show()
end

BR.Options.Dialogs.CustomBuff = { Show = Show }
