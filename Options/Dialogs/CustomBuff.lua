local _, BR = ...

-- ============================================================================
-- CUSTOM BUFF DIALOG
-- ============================================================================
-- One dialog for creating and editing. Creating is the empty state: no Delete
-- button, and Save stays disabled until one spell ID resolves.
--
-- The shell never changes size. A pinned header and footer sandwich a scrolling
-- body, so no control can reach the footer and no spell row can grow the window.
--
-- Every control that owns a value writes it to ctx.draft and reads it back
-- through `get`. Components.RefreshAll re-reads `get`, so a control that read
-- the saved buff directly would revert the user's edit on every refresh.

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
local ceil, floor, max = math.ceil, math.floor, math.max

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local BEFORE_HEADER_GAP = 16
local AFTER_HEADER_GAP = 8

-- Shell metrics. CreatePanel draws its title separator at -32, so the body
-- starts one pixel below that.
local DIALOG_W = 432
local DIALOG_H = 408
local TITLE_H = 33
local HEADER_H = 58
local TAB_STRIP_H = 26
local FOOTER_H = 42
local MARGIN = 16
local SCROLLBAR_W = 24
local BODY_W = DIALOG_W - MARGIN * 2
local CONTENT_W = BODY_W - SCROLLBAR_W
local BODY_H = DIALOG_H - TITLE_H - HEADER_H - TAB_STRIP_H - FOOTER_H

-- The row grid. Every label starts at x 0 and every field at FIELD_X, because
-- Slider, Dropdown and TextInput all place their field at `label RIGHT + 5`.
-- Their holders disagree on height (Dropdown 26, the rest 20), so AddControl
-- centres each one in a ROW_H slot instead of stacking raw holder heights.
local LABEL_W = 82
local FIELD_GAP = 5
local FIELD_X = LABEL_W + FIELD_GAP
local FIELD_W = 136
local FIELD_H = 18
local ID_FIELD_W = 70
local SPEC_LABEL_W = 34
local LABEL_H = 12
local ICON_SIZE = 18
local ICON_GAP = 8
local NAME_GAP = ICON_GAP + ICON_SIZE + 6
local REMOVE_W = 20
local ROW_H = 26
local ROW_GAP = 4
local ROW_PITCH = ROW_H + ROW_GAP
local PREVIEW_SIZE = 42
local TAB_BOTTOM_PAD = 12

local SEPARATOR = "  |cff5a5a68-|r  "
local LOOKUP_DELAY = 0.3

-- The class dropdown and the header summary both resolve a token through this
-- map, so a raw token never reaches the UI.
local CLASS_TOKENS = {
    "DEATHKNIGHT",
    "DEMONHUNTER",
    "DRUID",
    "EVOKER",
    "HUNTER",
    "MAGE",
    "MONK",
    "PALADIN",
    "PRIEST",
    "ROGUE",
    "SHAMAN",
    "WARLOCK",
    "WARRIOR",
}
local CLASS_LABEL_KEYS = {
    DEATHKNIGHT = "Class.DeathKnight",
    DEMONHUNTER = "Class.DemonHunter",
    DRUID = "Class.Druid",
    EVOKER = "Class.Evoker",
    HUNTER = "Class.Hunter",
    MAGE = "Class.Mage",
    MONK = "Class.Monk",
    PALADIN = "Class.Paladin",
    PRIEST = "Class.Priest",
    ROGUE = "Class.Rogue",
    SHAMAN = "Class.Shaman",
    WARLOCK = "Class.Warlock",
    WARRIOR = "Class.Warrior",
}

local customBuffDialog = nil

-- ============================================================================
-- LAYOUT HELPERS
-- ============================================================================

---Place a control centred in one ROW_H slot and advance a full row pitch, so
---the gap between two rows never depends on which widgets they hold.
---@param layout table
---@param holder table
---@param x? number Left offset (default 0; pass FIELD_X for a label-less control)
local function AddControl(layout, holder, x)
    local height = (holder.GetHeight and holder:GetHeight()) or ROW_H
    local pad = max(0, floor((ROW_H - height) / 2))
    layout:Space(pad)
    if x and x ~= 0 then
        layout:AddRow({ { holder, x } }, 0)
    else
        layout:Add(holder, height, 0)
    end
    layout:Space(ROW_H - height - pad + ROW_GAP)
    return holder
end

local function SectionHeader(layout, parent, text)
    layout._sections = (layout._sections or 0) + 1
    if layout._sections > 1 then
        layout:Space(BEFORE_HEADER_GAP)
    end

    local container = CreateFrame("Frame", nil, parent)
    -- GameFontNormal, matching Helpers.LayoutSectionHeader. The Small variant
    -- renders gold caps at 10px, where the font's drop shadow reads as grain.
    local header = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetWordWrap(false)
    header:SetText("|cffffcc00" .. text .. "|r")

    local headerH = ceil(header:GetStringHeight())
    if headerH < 14 then
        headerH = 14
    end

    local sep = container:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", 0, -(headerH + 4))
    sep:SetPoint("TOPRIGHT", 0, -(headerH + 4))
    sep:SetColorTexture(0.4, 0.32, 0.05, 0.55)

    container:SetSize(CONTENT_W, headerH + 5)
    layout:Add(container, headerH + 5, AFTER_HEADER_GAP)
    return header
end

local function SectionNote(layout, parent, text, x)
    local note = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetWidth(CONTENT_W - (x or 0))
    note:SetJustifyH("LEFT")
    note:SetWordWrap(true)
    note:SetText(text)
    local h = ceil(note:GetStringHeight())
    local prevX = layout:GetX()
    layout:SetX(x or prevX)
    layout:AddText(note, h, COMPONENT_GAP)
    layout:SetX(prevX)
    return note
end

---Bare ID entry box. The spell and item fields need the icon and the resolved
---name anchored beside them, which Components.TextInput does not offer.
local function IdField(ctx, parent, width, initial)
    local editBox = CreateFrame("EditBox", nil, parent)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetAutoFocus(false)
    editBox:SetNumeric(true)
    local container = StyleEditBox(editBox)
    container:SetSize(width, 18)
    if initial then
        editBox:SetText(tostring(initial))
    end
    editBox:SetScript("OnEnterPressed", editBox.ClearFocus)
    tinsert(ctx.editBoxes, editBox)
    return container, editBox
end

---Run fn once the field stops changing. Validating on every keystroke reports
---"Not found" for each prefix of an ID the user is still typing.
local function Debounce(owner, fn)
    owner._lookupToken = (owner._lookupToken or 0) + 1
    local token = owner._lookupToken
    C_Timer.After(LOOKUP_DELAY, function()
        if owner._lookupToken == token then
            fn()
        end
    end)
end

local function Track(ctx, holder)
    tinsert(ctx.holders, holder)
    return holder
end

-- ============================================================================
-- DELETE CONFIRMATION
-- ============================================================================

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

-- ============================================================================
-- BUFF TAB
-- ============================================================================

-- ============================================================================
-- BUFF TAB
-- ============================================================================

local function BuildBuffTab(ctx, frame)
    local draft = ctx.draft
    local layout = Components.VerticalLayout(frame, { x = 0, y = -6 })

    SectionHeader(layout, frame, L["CustomBuff.Section.Track"])

    -- The rows live in a block whose height changes, and everything after the
    -- block is anchored to its bottom edge, so adding a row pushes the rest
    -- down without a relayout.
    local trackTop = -layout:GetY()
    local trackBlock = CreateFrame("Frame", nil, frame)
    trackBlock:SetSize(CONTENT_W, ROW_PITCH + ROW_H)
    trackBlock:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -trackTop)

    local idsLabel = trackBlock:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    idsLabel:SetPoint("TOPLEFT", 0, -(ROW_H - LABEL_H) / 2)
    idsLabel:SetWidth(LABEL_W)
    idsLabel:SetJustifyH("LEFT")
    idsLabel:SetText(L["CustomBuff.SpellIDs"])

    local addBtn
    local function Relayout()
        local count = #ctx.spellRows
        for i, row in ipairs(ctx.spellRows) do
            row.frame:ClearAllPoints()
            row.frame:SetPoint("TOPLEFT", trackBlock, "TOPLEFT", 0, -((i - 1) * ROW_PITCH))
            row.removeBtn:SetShown(count > 1)
        end
        addBtn:ClearAllPoints()
        addBtn:SetPoint("TOPLEFT", trackBlock, "TOPLEFT", FIELD_X, -(count * ROW_PITCH))
        trackBlock:SetHeight(count * ROW_PITCH + ROW_H)
        ctx.UpdateBuffTabHeight()
    end

    function ctx.AddSpellRow(initialID)
        local rowFrame = CreateFrame("Frame", nil, trackBlock)
        rowFrame:SetSize(CONTENT_W, ROW_H)

        local container, editBox = IdField(ctx, rowFrame, ID_FIELD_W, initialID)
        container:SetPoint("LEFT", FIELD_X, 0)

        local icon = CreateBuffIcon(rowFrame, ICON_SIZE)
        icon:SetPoint("LEFT", container, "RIGHT", ICON_GAP, 0)
        icon:Hide()

        local nameText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameText:SetPoint("LEFT", container, "RIGHT", NAME_GAP, 0)
        nameText:SetPoint("RIGHT", rowFrame, "RIGHT", -(REMOVE_W + ICON_GAP), 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetWordWrap(false)

        local removeBtn = CreateButton(rowFrame, "-", nil)
        removeBtn:SetSize(REMOVE_W, FIELD_H)
        removeBtn:SetPoint("RIGHT", 0, 0)

        local row = { frame = rowFrame, editBox = editBox, removeBtn = removeBtn, validated = false }

        local function Validate()
            local spellID = tonumber(editBox:GetText())
            local valid, name, iconID = false, nil, nil
            if spellID then
                valid, name, iconID = ValidateSpellID(spellID)
            end
            if valid then
                icon:SetTexture(iconID)
                icon:Show()
                nameText:SetText(name or "")
                row.validated, row.spellID, row.spellName, row.iconID = true, spellID, name, iconID
            else
                icon:Hide()
                if editBox:GetText() == "" then
                    nameText:SetText("")
                else
                    nameText:SetText("|cffff4d4d" .. L["CustomBuff.NotFound"] .. "|r")
                end
                row.validated, row.spellID, row.spellName, row.iconID = false, nil, nil, nil
            end
            ctx.Sync()
        end

        editBox:SetScript("OnTextChanged", function()
            Debounce(row, Validate)
        end)

        removeBtn:SetScript("OnClick", function()
            for i, other in ipairs(ctx.spellRows) do
                if other == row then
                    rowFrame:Hide()
                    table.remove(ctx.spellRows, i)
                    break
                end
            end
            Relayout()
            ctx.Sync()
        end)

        tinsert(ctx.spellRows, row)
        if initialID then
            Validate()
        end
        Relayout()
        return row
    end

    addBtn = CreateButton(trackBlock, L["CustomBuff.AddSpellID"], function()
        ctx.AddSpellRow(nil)
    end)
    addBtn:SetSize(110, FIELD_H)

    local rest = CreateFrame("Frame", nil, frame)
    rest:SetSize(CONTENT_W, 10)
    rest:SetPoint("TOPLEFT", trackBlock, "BOTTOMLEFT", 0, -ROW_GAP)

    -- Bar glow closes the Spells section: it answers the same question the IDs
    -- do - how the addon detects the buff - through the action bar instead.
    local restLayout = Components.VerticalLayout(rest, { x = 0, y = 0 })
    restLayout._sections = 1

    AddControl(
        restLayout,
        Track(
            ctx,
            Components.Dropdown(rest, {
                label = L["CustomBuff.BarGlow"],
                labelWidth = LABEL_W,
                width = FIELD_W,
                options = {
                    { value = "whenGlowing", label = L["CustomBuff.BarGlow.WhenGlowing"] },
                    { value = "whenNotGlowing", label = L["CustomBuff.BarGlow.WhenNotGlowing"] },
                    { value = "disabled", label = L["CustomBuff.BarGlow.Disabled"] },
                },
                get = function()
                    return draft.glowMode
                end,
                tooltip = {
                    title = L["CustomBuff.BarGlow.Title"],
                    desc = L["CustomBuff.BarGlow.Desc"],
                },
                onChange = function(value)
                    draft.glowMode = value
                end,
            })
        )
    )

    SectionHeader(restLayout, rest, L["CustomBuff.Section.ShowIcon"])

    AddControl(
        restLayout,
        Track(
            ctx,
            Components.Dropdown(rest, {
                label = L["CustomBuff.ShowWhen"],
                labelWidth = LABEL_W,
                width = FIELD_W,
                options = {
                    { value = "missing", label = L["CustomBuff.WhenMissing"] },
                    { value = "active", label = L["CustomBuff.WhenActive"] },
                },
                get = function()
                    return draft.trigger
                end,
                onChange = function(value)
                    draft.trigger = value
                    Components.RefreshAll()
                    ctx.Sync()
                end,
            })
        )
    )

    AddControl(
        restLayout,
        Track(
            ctx,
            Components.Slider(rest, {
                label = L["Options.Expiration"],
                labelWidth = LABEL_W,
                sliderWidth = FIELD_W - 52,
                min = 0,
                max = 45,
                step = 5,
                get = function()
                    return draft.expiration
                end,
                formatValue = function(val)
                    return val == 0 and L["Options.Off"] or (val .. " " .. L["Options.Min"])
                end,
                enabled = function()
                    return draft.trigger == "missing"
                end,
                disabledReason = L["CustomBuff.Expiration.Disabled"],
                onChange = function(val)
                    draft.expiration = val
                end,
            })
        )
    )

    local overlay = Components.TextInput(rest, {
        label = L["CustomBuff.Text"],
        labelWidth = LABEL_W,
        width = CONTENT_W - FIELD_X,
        value = ctx.editing and ctx.editing.overlayText and ctx.editing.overlayText:gsub("\n", "\\n") or "",
    })
    AddControl(restLayout, overlay)
    ctx.w.overlay = overlay
    tinsert(ctx.editBoxes, overlay.editBox)

    SectionNote(restLayout, rest, L["CustomBuff.LineBreakHint"], FIELD_X)

    local restHeight = -restLayout:GetY()
    rest:SetHeight(restHeight)

    function ctx.UpdateBuffTabHeight()
        frame:SetHeight(trackTop + trackBlock:GetHeight() + ROW_GAP + restHeight + TAB_BOTTOM_PAD)
        if ctx.activeTab == "buff" then
            ctx.scrollFrame:SetContentHeight(frame:GetHeight())
        end
    end
end

-- ============================================================================
-- RULES TAB
-- ============================================================================

local function BuildRulesTab(ctx, frame)
    local draft = ctx.draft
    local lc = ctx.loadConditions
    local layout = Components.VerticalLayout(frame, { x = 0, y = -6 })

    SectionHeader(layout, frame, L["CustomBuff.Section.Who"])

    local classOptions = { { value = nil, label = L["Class.Any"] } }
    for _, token in ipairs(CLASS_TOKENS) do
        classOptions[#classOptions + 1] = { value = token, label = L[CLASS_LABEL_KEYS[token]] }
    end

    local classRow = CreateFrame("Frame", nil, frame)
    classRow:SetSize(CONTENT_W, ROW_H)

    local classDropdown = Track(
        ctx,
        Components.Dropdown(classRow, {
            label = L["CustomBuff.Class"],
            labelWidth = LABEL_W,
            width = FIELD_W,
            maxItems = 10,
            options = classOptions,
            get = function()
                return draft.class
            end,
            onChange = function(value)
                draft.class = value
                draft.specId = nil
                ctx.RebuildSpecDropdown()
                ctx.Sync()
            end,
        })
    )
    classDropdown:SetPoint("LEFT", 0, 0)

    -- The spec list depends on the class, so the dropdown is rebuilt on every
    -- class change rather than repopulated.
    local specHolder
    function ctx.RebuildSpecDropdown()
        if specHolder then
            Components.Unregister(specHolder)
            specHolder:Hide()
            specHolder = nil
        end
        local specOptions = draft.class and BR.CLASS_SPEC_OPTIONS[draft.class]
        if not specOptions then
            return
        end
        specHolder = Track(
            ctx,
            Components.Dropdown(classRow, {
                label = L["CustomBuff.Spec"],
                labelWidth = SPEC_LABEL_W,
                width = CONTENT_W - FIELD_X - FIELD_W - SPEC_LABEL_W - 8,
                options = specOptions,
                get = function()
                    return draft.specId
                end,
                onChange = function(value)
                    draft.specId = value
                    ctx.Sync()
                end,
            })
        )
        specHolder:SetPoint("LEFT", classDropdown, "RIGHT", 10, 0)
        ctx.w.spec = specHolder
    end

    ctx.RebuildSpecDropdown()
    AddControl(layout, classRow)

    AddControl(
        layout,
        Track(
            ctx,
            Components.Toggle(frame, {
                label = L["CustomBuff.OnlyIfSpellKnown"],
                holderWidth = CONTENT_W - FIELD_X,
                get = function()
                    return draft.requireSpellKnown
                end,
                onChange = function(checked)
                    draft.requireSpellKnown = checked
                    ctx.Sync()
                end,
            })
        ),
        FIELD_X
    )

    SectionHeader(layout, frame, L["CustomBuff.Section.Item"])

    local itemRow = CreateFrame("Frame", nil, frame)
    itemRow:SetSize(CONTENT_W, ROW_H)

    local itemLabel = itemRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    itemLabel:SetPoint("LEFT", 0, 0)
    itemLabel:SetWidth(LABEL_W)
    itemLabel:SetJustifyH("LEFT")
    itemLabel:SetText(L["CustomBuff.RequireItem"])

    local itemContainer, itemEditBox = IdField(ctx, itemRow, ID_FIELD_W, ctx.editing and ctx.editing.requireItemID)
    itemContainer:SetPoint("LEFT", FIELD_X, 0)
    ctx.w.itemEditBox = itemEditBox

    local itemIcon = CreateBuffIcon(itemRow, ICON_SIZE)
    itemIcon:SetPoint("LEFT", itemContainer, "RIGHT", ICON_GAP, 0)
    itemIcon:Hide()

    local itemName = itemRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    itemName:SetPoint("LEFT", itemContainer, "RIGHT", NAME_GAP, 0)
    itemName:SetPoint("RIGHT", itemRow, "RIGHT", 0, 0)
    itemName:SetJustifyH("LEFT")
    itemName:SetWordWrap(false)

    local function ValidateItem()
        local itemID = tonumber(itemEditBox:GetText())
        local hadItem = draft.hasItem
        draft.hasItem = itemID ~= nil
        if not itemID then
            itemIcon:Hide()
            itemName:SetText("")
        else
            local valid, name, iconID = ValidateItemID(itemID)
            if valid then
                itemIcon:SetTexture(iconID)
                itemIcon:Show()
                itemName:SetText(name or "")
            else
                itemIcon:Hide()
                itemName:SetText("|cffff4d4d" .. L["CustomBuff.NotFoundRetry"] .. "|r")
                pcall(C_Item.RequestLoadItemDataByID, itemID)
            end
        end
        if hadItem ~= draft.hasItem then
            Components.RefreshAll()
        end
        ctx.Sync()
    end

    itemEditBox:SetScript("OnTextChanged", function()
        Debounce(itemRow, ValidateItem)
    end)

    ValidateItem()
    AddControl(layout, itemRow)

    AddControl(
        layout,
        Track(
            ctx,
            Components.Dropdown(frame, {
                label = L["CustomBuff.RequireItem.Mode"],
                labelWidth = LABEL_W,
                width = FIELD_W,
                options = {
                    { value = "owned", label = L["CustomBuff.RequireItem.EquippedBags"] },
                    { value = "equipped", label = L["CustomBuff.RequireItem.Equipped"] },
                    { value = "bags", label = L["CustomBuff.RequireItem.InBags"] },
                },
                get = function()
                    return draft.requireItemMode
                end,
                enabled = function()
                    return draft.hasItem
                end,
                disabledReason = L["CustomBuff.RequireItem.Disabled"],
                onChange = function(value)
                    draft.requireItemMode = value
                end,
            })
        )
    )

    AddControl(
        layout,
        Track(
            ctx,
            Components.Dropdown(frame, {
                label = L["CustomBuff.ItemCooldown"],
                labelWidth = LABEL_W,
                width = FIELD_W,
                options = {
                    { value = nil, label = L["CustomBuff.ItemCooldown.Any"] },
                    { value = "offCooldown", label = L["CustomBuff.ItemCooldown.OffCooldown"] },
                    { value = "onCooldown", label = L["CustomBuff.ItemCooldown.OnCooldown"] },
                },
                get = function()
                    return draft.itemCooldown
                end,
                enabled = function()
                    return draft.hasItem
                end,
                disabledReason = L["CustomBuff.RequireItem.Disabled"],
                onChange = function(value)
                    draft.itemCooldown = value
                end,
            })
        )
    )

    SectionHeader(layout, frame, L["CustomBuff.Section.Where"])

    local contentRow = CreateFrame("Frame", nil, frame)
    contentRow:SetSize(CONTENT_W, ROW_H)

    local contentLabel = contentRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    contentLabel:SetPoint("LEFT", 0, 0)
    contentLabel:SetWidth(LABEL_W)
    contentLabel:SetJustifyH("LEFT")
    contentLabel:SetText(L["CustomBuff.Content"])

    local visToggles = Track(
        ctx,
        Components.VisibilityToggles(contentRow, {
            store = {
                getContent = function(key)
                    return lc[key] ~= false
                end,
                setContent = function(key)
                    if lc[key] ~= false then
                        lc[key] = false
                    else
                        lc[key] = nil
                    end
                    ctx.Sync()
                end,
                getDiffTable = function(dbKey)
                    return lc[dbKey]
                end,
                ensureDiffTable = function(dbKey)
                    if not lc[dbKey] then
                        lc[dbKey] = {}
                    end
                    return lc[dbKey]
                end,
            },
            noAutoRefresh = true,
            onChange = function()
                ctx.Sync()
            end,
        })
    )
    visToggles:SetPoint("LEFT", FIELD_X, 0)
    AddControl(layout, contentRow)

    AddControl(
        layout,
        Track(
            ctx,
            Components.Dropdown(frame, {
                label = L["CustomBuff.Level"],
                labelWidth = LABEL_W,
                width = FIELD_W,
                options = {
                    { value = "any", label = L["CustomBuff.Level.Any"] },
                    { value = "maxLevel", label = L["CustomBuff.Level.Max"] },
                    { value = "belowMaxLevel", label = L["CustomBuff.Level.BelowMax"] },
                },
                get = function()
                    return lc.levelFilter or "any"
                end,
                onChange = function(value)
                    lc.levelFilter = (value ~= "any") and value or nil
                    ctx.Sync()
                end,
            })
        )
    )

    AddControl(
        layout,
        Track(
            ctx,
            Components.Toggle(frame, {
                label = L["CustomBuff.ReadyCheckOnly"],
                holderWidth = CONTENT_W - FIELD_X,
                get = function()
                    return lc.readyCheckOnly or false
                end,
                onChange = function(checked)
                    lc.readyCheckOnly = checked or nil
                    ctx.Sync()
                end,
            })
        ),
        FIELD_X
    )

    frame:SetHeight(-layout:GetY() + TAB_BOTTOM_PAD)
end

-- ============================================================================
-- CLICK TAB
-- ============================================================================

local function BuildClickTab(ctx, frame)
    local draft = ctx.draft
    local layout = Components.VerticalLayout(frame, { x = 0, y = -6 })

    SectionHeader(layout, frame, L["CustomBuff.Section.OnClick"])

    AddControl(
        layout,
        Track(
            ctx,
            Components.Dropdown(frame, {
                label = L["CustomBuff.Action.OnClick"],
                labelWidth = LABEL_W,
                width = FIELD_W,
                options = {
                    { value = "none", label = L["CustomBuff.Action.None"] },
                    { value = "spell", label = L["CustomBuff.Action.Spell"] },
                    { value = "item", label = L["CustomBuff.Action.Item"] },
                    { value = "macro", label = L["CustomBuff.Action.Macro"] },
                },
                get = function()
                    return draft.action
                end,
                tooltip = {
                    title = L["CustomBuff.Action.Title"],
                    desc = L["CustomBuff.Action.Desc"],
                },
                onChange = function(value)
                    draft.action = value
                    ctx.UpdateActionInputs()
                    ctx.Sync()
                end,
            })
        )
    )

    -- All three inputs share one slot. Nothing is laid out under them, so
    -- swapping which one shows cannot shift the rest of the tab.
    local inputHost = CreateFrame("Frame", nil, frame)
    inputHost:SetSize(CONTENT_W, ROW_H)
    layout:Add(inputHost, ROW_H, ROW_GAP)

    local function BuildLookupRow(labelText, initial, validate)
        local row = CreateFrame("Frame", nil, inputHost)
        row:SetSize(CONTENT_W, ROW_H)
        row:SetPoint("TOPLEFT", 0, 0)

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", 0, 0)
        label:SetWidth(LABEL_W)
        label:SetJustifyH("LEFT")
        label:SetText(labelText)

        local container, editBox = IdField(ctx, row, ID_FIELD_W, initial)
        container:SetPoint("LEFT", FIELD_X, 0)

        local icon = CreateBuffIcon(row, ICON_SIZE)
        icon:SetPoint("LEFT", container, "RIGHT", ICON_GAP, 0)
        icon:Hide()

        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameText:SetPoint("LEFT", container, "RIGHT", NAME_GAP, 0)
        nameText:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetWordWrap(false)

        local function Run()
            local id = tonumber(editBox:GetText())
            if not id then
                icon:Hide()
                nameText:SetText("")
                return
            end
            local valid, name, iconID = validate(id)
            if valid then
                icon:SetTexture(iconID)
                icon:Show()
                nameText:SetText(name or "")
            else
                icon:Hide()
                nameText:SetText("|cffff4d4d" .. L["CustomBuff.NotFoundRetry"] .. "|r")
            end
        end

        editBox:SetScript("OnTextChanged", function()
            Debounce(row, Run)
        end)
        row.Validate = Run
        row.editBox = editBox
        return row
    end

    local spellRow =
        BuildLookupRow(L["CustomBuff.Action.SpellID"], ctx.editing and ctx.editing.castSpellID, ValidateSpellID)
    local itemRow = BuildLookupRow(L["CustomBuff.Action.ItemID"], ctx.editing and ctx.editing.castItemID, function(id)
        local valid, name, iconID = ValidateItemID(id)
        if not valid then
            pcall(C_Item.RequestLoadItemDataByID, id)
        end
        return valid, name, iconID
    end)

    local macroInput = Components.TextInput(inputHost, {
        label = L["CustomBuff.Action.MacroText"],
        labelWidth = LABEL_W,
        width = CONTENT_W - FIELD_X,
        value = ctx.editing and ctx.editing.castMacro or "",
    })
    macroInput:SetPoint("LEFT", 0, 0)
    tinsert(ctx.editBoxes, macroInput.editBox)

    ctx.w.castSpell = spellRow.editBox
    ctx.w.castItem = itemRow.editBox
    ctx.w.castMacro = macroInput.editBox

    local spellHint = SectionNote(layout, frame, L["CustomBuff.Action.SpellHint"], FIELD_X)
    local macroHint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    macroHint:SetPoint("TOPLEFT", spellHint, "TOPLEFT", 0, 0)
    macroHint:SetWidth(CONTENT_W - FIELD_X)
    macroHint:SetJustifyH("LEFT")
    macroHint:SetText(L["CustomBuff.Action.MacroHint"])

    function ctx.UpdateActionInputs()
        spellRow:SetShown(draft.action == "spell")
        itemRow:SetShown(draft.action == "item")
        macroInput:SetShown(draft.action == "macro")
        spellHint:SetShown(draft.action == "spell" or draft.action == "item")
        macroHint:SetShown(draft.action == "macro")
        if draft.action == "spell" then
            spellRow.Validate()
        elseif draft.action == "item" then
            itemRow.Validate()
        end
    end

    ctx.UpdateActionInputs()
    frame:SetHeight(-layout:GetY() + TAB_BOTTOM_PAD)
end

-- ============================================================================
-- SAVE
-- ============================================================================

local function CollectLoadConditions(lc)
    -- A difficulty sub-table with nothing turned off is the default; drop it.
    for _, diffKey in ipairs({ "scenarioDifficulty", "dungeonDifficulty", "raidDifficulty", "pvpType" }) do
        local diffTable = lc[diffKey]
        if diffTable then
            local anyOff = false
            for _, value in pairs(diffTable) do
                if value == false then
                    anyOff = true
                    break
                end
            end
            if not anyOff then
                lc[diffKey] = nil
            end
        end
    end

    local function HasNonDefault(t)
        for _, value in pairs(t) do
            if type(value) == "table" then
                if HasNonDefault(value) then
                    return true
                end
            else
                return true
            end
        end
        return false
    end

    return HasNonDefault(lc) and lc or nil
end

local function SaveBuff(ctx)
    local ids, firstName = {}, nil
    for _, row in ipairs(ctx.spellRows) do
        if row.validated and row.spellID then
            tinsert(ids, row.spellID)
            firstName = firstName or row.spellName
        end
    end
    if #ids == 0 then
        return false
    end

    local draft = ctx.draft
    local spellIDValue = #ids == 1 and ids[1] or ids
    local key = ctx.existingKey or GenerateCustomBuffKey(spellIDValue)

    local displayName = strtrim(ctx.w.nameBox:GetText())
    if displayName == "" then
        displayName = firstName or (L["CustomBuff.Action.Spell"] .. " " .. ids[1])
    end

    local overlayText = strtrim(ctx.w.overlay:GetValue())
    if overlayText ~= "" then
        overlayText = overlayText:gsub("\\n", "\n")
    else
        overlayText = nil
    end

    local castSpellID, castItemID, castMacro
    if draft.action == "spell" then
        castSpellID = tonumber(strtrim(ctx.w.castSpell:GetText()))
    elseif draft.action == "item" then
        castItemID = tonumber(strtrim(ctx.w.castItem:GetText()))
    elseif draft.action == "macro" then
        local text = strtrim(ctx.w.castMacro:GetText())
        castMacro = text ~= "" and text or nil
    end

    local requireItemID = tonumber(strtrim(ctx.w.itemEditBox:GetText()))

    local customBuff = {
        spellID = spellIDValue,
        key = key,
        name = displayName,
        overlayText = overlayText,
        class = draft.class,
        requireSpecId = draft.specId,
        showWhenPresent = draft.trigger == "active" or nil,
        requireSpellKnown = draft.requireSpellKnown or nil,
        glowMode = draft.glowMode ~= "disabled" and draft.glowMode or nil,
        expirationThreshold = draft.trigger == "missing" and draft.expiration or 0,
        castSpellID = castSpellID,
        castItemID = castItemID,
        castMacro = castMacro,
        requireItemID = requireItemID,
        requireItemMode = draft.requireItemMode ~= "owned" and draft.requireItemMode or nil,
        itemCooldownCondition = requireItemID and draft.itemCooldown or nil,
        loadConditions = CollectLoadConditions(ctx.loadConditions),
    }

    BR.profile.customBuffs[key] = customBuff

    if ctx.existingKey then
        UpdateCustomBuffFrame(key, spellIDValue, displayName)
    else
        CreateCustomBuffFrameRuntime(customBuff)
    end

    -- requireItemMode can change on save, so the ownership cache must go.
    BR.BuffState.InvalidateItemCache()
    return true
end

-- ============================================================================
-- DIALOG
-- ============================================================================

local function BuildDraft(editing)
    local action = "none"
    if editing then
        if editing.castMacro and editing.castMacro ~= "" then
            action = "macro"
        elseif editing.castItemID then
            action = "item"
        elseif editing.castSpellID then
            action = "spell"
        end
    end

    return {
        trigger = editing and editing.showWhenPresent and "active" or "missing",
        expiration = editing and editing.expirationThreshold or 15,
        glowMode = editing and editing.glowMode or "disabled",
        class = editing and editing.class or nil,
        specId = editing and editing.requireSpecId or nil,
        requireSpellKnown = editing and editing.requireSpellKnown or false,
        requireItemMode = editing and editing.requireItemMode or "owned",
        itemCooldown = editing and editing.itemCooldownCondition or nil,
        hasItem = editing and editing.requireItemID ~= nil or false,
        action = action,
    }
end

local function CopyLoadConditions(editing)
    local lc = {}
    if editing and editing.loadConditions then
        for key, value in pairs(editing.loadConditions) do
            if type(value) == "table" then
                lc[key] = {}
                for subKey, subValue in pairs(value) do
                    lc[key][subKey] = subValue
                end
            else
                lc[key] = value
            end
        end
    elseif not editing then
        -- Housing is off by default, so a new buff needs an explicit false.
        lc.housing = false
    end
    return lc
end

local function Show(existingKey, refreshPanelCallback)
    if customBuffDialog then
        customBuffDialog:Hide()
    end

    local editing = existingKey and BR.profile.customBuffs[existingKey] or nil

    local ctx = {
        existingKey = existingKey,
        editing = editing,
        draft = BuildDraft(editing),
        loadConditions = CopyLoadConditions(editing),
        spellRows = {},
        holders = {},
        editBoxes = {},
        w = {},
    }

    local dialog = CreatePanel("BuffRemindersCustomBuffDialog", DIALOG_W, DIALOG_H, {
        level = BR.Options.Constants.DIALOG_LEVEL,
        dialog = true,
    })

    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -11)
    title:SetText(editing and L["CustomBuff.Edit"] or L["CustomBuff.Add"])

    BR.Options.Helpers.AddCloseButton(dialog)

    -- ---- header: preview + name ------------------------------------------
    local header = CreateFrame("Frame", nil, dialog)
    header:SetPoint("TOPLEFT", 2, -TITLE_H)
    header:SetPoint("TOPRIGHT", -2, -TITLE_H)
    header:SetHeight(HEADER_H)

    local band = header:CreateTexture(nil, "BACKGROUND")
    band:SetAllPoints()
    band:SetColorTexture(1, 1, 1, 0.025)

    local headerLine = header:CreateTexture(nil, "ARTWORK")
    headerLine:SetHeight(1)
    headerLine:SetPoint("BOTTOMLEFT", 0, 0)
    headerLine:SetPoint("BOTTOMRIGHT", 0, 0)
    headerLine:SetColorTexture(unpack(BR.Colors.Border))

    local preview = CreateFrame("Frame", nil, header, "BackdropTemplate")
    preview:SetSize(PREVIEW_SIZE, PREVIEW_SIZE)
    preview:SetPoint("LEFT", MARGIN - 2, 0)
    preview:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    preview:SetBackdropColor(0.05, 0.05, 0.07, 1)
    preview:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)

    local previewIcon = CreateBuffIcon(preview, PREVIEW_SIZE - 2)
    previewIcon:SetPoint("CENTER")
    previewIcon:Hide()

    local previewMark = preview:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
    previewMark:SetPoint("CENTER")
    previewMark:SetText("?")

    local previewCount = preview:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    previewCount:SetPoint("BOTTOMRIGHT", 1, 0)
    previewCount:Hide()

    local nameX = MARGIN - 2 + PREVIEW_SIZE + 12
    local nameBox = CreateFrame("EditBox", nil, header)
    nameBox:SetFontObject("GameFontNormal")
    nameBox:SetAutoFocus(false)
    local nameContainer = StyleEditBox(nameBox)
    nameContainer:SetSize(DIALOG_W - nameX - MARGIN, 22)
    nameContainer:SetPoint("TOPLEFT", nameX, -9)
    nameBox:SetText(editing and editing.name or "")
    nameBox:SetScript("OnEnterPressed", nameBox.ClearFocus)
    tinsert(ctx.editBoxes, nameBox)
    ctx.w.nameBox = nameBox

    local namePlaceholder = nameContainer:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    namePlaceholder:SetPoint("LEFT", nameContainer, "LEFT", 6, 0)
    namePlaceholder:SetText(L["CustomBuff.NamePlaceholder"])

    local subtitle = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    subtitle:SetPoint("TOPLEFT", nameX + 1, -35)
    subtitle:SetPoint("TOPRIGHT", header, "TOPRIGHT", -MARGIN, -35)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetWordWrap(false)

    -- ---- body ------------------------------------------------------------
    local scrollFrame = Components.ScrollableContainer(dialog, {
        width = BODY_W,
        scrollbarWidth = SCROLLBAR_W,
        contentHeight = BODY_H,
    })
    scrollFrame:SetPoint("TOPLEFT", MARGIN, -(TITLE_H + HEADER_H + TAB_STRIP_H))
    scrollFrame:SetHeight(BODY_H)
    local content = scrollFrame:GetContentFrame()
    ctx.scrollFrame = scrollFrame

    local tabFrames = {}
    for _, id in ipairs({ "buff", "rules", "click" }) do
        local frame = CreateFrame("Frame", nil, content)
        frame:SetPoint("TOPLEFT", 0, 0)
        frame:SetSize(CONTENT_W, BODY_H)
        frame:Hide()
        tabFrames[id] = frame
    end

    -- ---- footer ----------------------------------------------------------
    local saveBtn = CreateButton(dialog, L["CustomBuff.Save"], function()
        if SaveBuff(ctx) then
            dialog:Hide()
            if refreshPanelCallback then
                refreshPanelCallback()
            end
            UpdateDisplay()
        end
    end)
    saveBtn:SetPoint("BOTTOMRIGHT", -MARGIN, 12)
    saveBtn:SetDisabledReason(L["CustomBuff.ValidateError"])

    local cancelBtn = CreateButton(dialog, L["Dialog.Cancel"], function()
        dialog:Hide()
    end)
    cancelBtn:SetPoint("RIGHT", saveBtn, "LEFT", -8, 0)

    local saveHint = dialog:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    saveHint:SetPoint("RIGHT", cancelBtn, "LEFT", -10, 0)
    saveHint:SetWidth(210)
    saveHint:SetJustifyH("RIGHT")
    saveHint:SetWordWrap(false)
    saveHint:SetTextColor(0.85, 0.64, 0.31)

    if existingKey and editing then
        local buffName = editing.name or existingKey
        local deleteBtn = CreateButton(dialog, L["Options.Delete"], function()
            dialog:Hide()
            StaticPopup_Show("BUFFREMINDERS_DELETE_CUSTOM", buffName, nil, {
                key = existingKey,
                refreshPanel = refreshPanelCallback,
            })
        end)
        deleteBtn:SetPoint("BOTTOMLEFT", MARGIN, 12)

        -- Exports what is saved, not what the open dialog holds.
        local exportBtn = CreateButton(dialog, L["CustomBuff.Share.Export"], function()
            BR.Options.Dialogs.CustomBuffShare.ShowExport(existingKey)
        end)
        exportBtn:SetPoint("LEFT", deleteBtn, "RIGHT", 8, 0)

        -- The hint reaches this far left in a locale with a long string, and it
        -- does not wrap. Bound it so it truncates instead of covering the button.
        saveHint:SetPoint("LEFT", exportBtn, "RIGHT", 8, 0)
    end

    -- ---- tabs ------------------------------------------------------------
    -- No badge marks a tab that holds settings: the panel's dot already means
    -- "unacknowledged new feature", and a second meaning reads as an alert.
    -- The header summary carries the rules worth seeing from any tab.
    local tabs = {}
    local TAB_IDS = { "buff", "rules", "click" }
    local TAB_LABELS = {
        buff = L["CustomBuff.Tab.Buff"],
        rules = L["CustomBuff.Tab.Rules"],
        click = L["CustomBuff.Tab.Click"],
    }

    local function Activate(id)
        ctx.activeTab = id
        for _, tabID in ipairs(TAB_IDS) do
            tabs[tabID]:SetActive(tabID == id)
            tabFrames[tabID]:SetShown(tabID == id)
        end
        scrollFrame:SetVerticalScroll(0)
        scrollFrame:SetContentHeight(tabFrames[id]:GetHeight())
    end

    local prevTab, firstTab
    for _, id in ipairs(TAB_IDS) do
        local tab = Components.Tab(dialog, { name = id, label = TAB_LABELS[id], width = 64 })
        tab:SetScript("OnClick", function()
            Activate(id)
        end)
        if prevTab then
            tab:SetPoint("LEFT", prevTab, "RIGHT", 4, 0)
        else
            tab:SetPoint("TOPLEFT", MARGIN, -(TITLE_H + HEADER_H + 2))
            firstTab = tab
        end

        tabs[id] = tab
        prevTab = tab
    end
    Components.TabBaseline(dialog, firstTab, BODY_W)

    -- ---- live state ------------------------------------------------------
    function ctx.Sync()
        local validCount, first = 0, nil
        for _, row in ipairs(ctx.spellRows) do
            if row.validated then
                validCount = validCount + 1
                first = first or row
            end
        end

        if first then
            previewIcon:SetTexture(first.iconID)
            previewIcon:Show()
            previewMark:Hide()
        else
            previewIcon:Hide()
            previewMark:Show()
        end
        previewCount:SetShown(validCount > 1)
        if validCount > 1 then
            previewCount:SetText(validCount)
        end

        namePlaceholder:SetShown(nameBox:GetText() == "")

        -- The summary carries only what the open tab does not already show.
        -- The spell ID sits one row below on the Buff tab, so it stays out.
        if first then
            local parts = {
                ctx.draft.trigger == "active" and L["CustomBuff.WhenActive"] or L["CustomBuff.WhenMissing"],
            }
            local classKey = ctx.draft.class and CLASS_LABEL_KEYS[ctx.draft.class]
            if classKey then
                parts[#parts + 1] = L[classKey]
            end
            if ctx.loadConditions.levelFilter then
                parts[#parts + 1] = ctx.loadConditions.levelFilter == "maxLevel" and L["CustomBuff.Level.Max"]
                    or L["CustomBuff.Level.BelowMax"]
            end
            subtitle:SetText(table.concat(parts, SEPARATOR))
        else
            subtitle:SetText(L["CustomBuff.NoSpellYet"])
        end

        saveBtn:SetEnabled(validCount > 0)
        saveHint:SetText(validCount > 0 and "" or L["CustomBuff.ValidateError"])
    end

    nameBox:SetScript("OnTextChanged", function()
        namePlaceholder:SetShown(nameBox:GetText() == "")
    end)

    BuildBuffTab(ctx, tabFrames.buff)
    BuildRulesTab(ctx, tabFrames.rules)
    BuildClickTab(ctx, tabFrames.click)

    if editing then
        local saved = editing.spellID
        if type(saved) == "table" then
            for _, spellID in ipairs(saved) do
                ctx.AddSpellRow(spellID)
            end
        else
            ctx.AddSpellRow(saved)
        end
    else
        ctx.AddSpellRow(nil)
    end

    dialog:SetScript("OnHide", function()
        for _, editBox in ipairs(ctx.editBoxes) do
            editBox:ClearFocus()
        end
        for _, holder in ipairs(ctx.holders) do
            Components.Unregister(holder)
        end
        if customBuffDialog == dialog then
            customBuffDialog = nil
        end
    end)

    -- Components read their enabled state through Refresh, so the item and
    -- expiration controls need one pass before the dialog is visible.
    Components.RefreshAll()
    ctx.Sync()
    Activate("buff")

    customBuffDialog = dialog
    dialog:Show()
end

BR.Options.Dialogs.CustomBuff = { Show = Show }
