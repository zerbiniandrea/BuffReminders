local _, BR = ...

-- ============================================================================
-- LOADOUT REMINDERS PAGE
-- ============================================================================
-- List of user-defined loadout reminders (one row per rule: enabled checkbox,
-- icon, name, summary, edit + delete). Add / edit open
-- BR.Options.Dialogs.LoadoutReminder.Show. Mirrors the Custom Buffs page; the
-- shared Layout / CustomAppearance sections below configure how the loadout
-- category as a whole renders.
--
-- The rule list lives in a fixed-height bordered scroll box (same chrome as
-- the Detached Icons page) so a long list scrolls internally instead of
-- pushing the Layout / CustomAppearance config off the page. The Add button
-- sits in a footer below the list.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton

local UpdateDisplay = BR.Display.Update

local LayoutSectionHeader = BR.Options.Helpers.LayoutSectionHeader
local LayoutSectionNote = BR.Options.Helpers.LayoutSectionNote

local TEXCOORD_INSET = BR.TEXCOORD_INSET

local SECTION_GAP = BR.Options.Constants.SECTION_GAP
local COL_PADDING = BR.Options.Constants.COL_PADDING

local tinsert = table.insert
local tsort = table.sort
local abs = math.abs
local C_ClassColor = C_ClassColor

local ROW_HEIGHT = 28
local ICON_SIZE = 20
local ACTION_BUTTON_WIDTH = 60
local ACTION_BUTTON_HEIGHT = 22
local ACTION_BUTTON_GAP = 8
local DEFAULT_ICON_TEXTURE = 134400

-- Fixed visible height of the rule list. Tuned so the list + footer + the
-- Layout / CustomAppearance sections all fit the 920x640 panel comfortably;
-- the list scrolls internally past this many rows.
local LIST_ROWS_VISIBLE = 11
local LIST_HEIGHT = LIST_ROWS_VISIBLE * ROW_HEIGHT
local LIST_TO_FOOTER_GAP = 8

-- Inner padding between the bordered list edge and its scroll child. Must
-- match Components.BorderedList's default inset, since the render math below
-- sizes content against it.
local LIST_INSET = 2

local REQUIRE_LABELS = {
    gear = "Loadout.Require.Gear",
    talent = "Loadout.Require.Talent",
    loadout = "Loadout.Require.Loadout",
}

local SCOPE_LABELS = {
    raid = "Loadout.Scope.Raid",
    dungeon = "Loadout.Scope.Dungeon",
    arena = "Loadout.Scope.Arena",
    battleground = "Loadout.Scope.Battleground",
}

---One-line summary of a rule: requirement target + where it applies.
local function FormatSummary(rule)
    local kind = L[REQUIRE_LABELS[rule.require] or "Loadout.Require.Gear"]
    local target
    if rule.require == "gear" then
        target = rule.gear and rule.gear.name
    elseif rule.require == "loadout" then
        target = rule.loadout and rule.loadout.name
    elseif rule.require == "talent" then
        if rule.spellID then
            local ok, name = pcall(C_Spell.GetSpellName, rule.spellID)
            target = (ok and name) or tostring(rule.spellID)
        end
    end
    local summary = target and (kind .. " · " .. target) or kind

    -- Where it applies: a specific instance, else the content scope.
    local when = rule.when
    local instances = when and when.instances
    if instances and #instances > 0 then
        summary = summary
            .. " · "
            .. (#instances == 1 and instances[1].name or string.format(L["Loadout.Instances"], #instances))
    elseif when and when.scope and SCOPE_LABELS[when.scope] then
        summary = summary .. " · " .. L[SCOPE_LABELS[when.scope]]
    end

    return summary
end

---What this rule was saved on (spec / character it's bound to), class-colored.
---Rendered right-aligned on the name line, separate from the summary, so the
---long "Name - Realm · Spec" string doesn't compete with the requirement text.
local function FormatBinding(rule)
    local binding, classToken = BR.Loadouts.GetBindingLabel(rule)
    if not binding then
        return nil
    end
    local color = classToken and C_ClassColor and C_ClassColor.GetClassColor(classToken)
    if color then
        binding = color:WrapTextInColorCode(binding)
    end
    return binding
end

local function CreateRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)

    local hover = row:CreateTexture(nil, "BACKGROUND")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0)
    row.hover = hover

    row:SetScript("OnEnter", function(self)
        self.hover:SetColorTexture(1, 1, 1, 0.04)
    end)
    row:SetScript("OnLeave", function(self)
        self.hover:SetColorTexture(1, 1, 1, 0)
    end)
    row:EnableMouse(true)

    return row
end

local function FillRowBody(body, key, rule, onEdit, onDelete)
    local checkbox = Components.Checkbox(body, {
        label = "",
        holderWidth = 18,
        get = function()
            return BR.profile.enabledBuffs[key] ~= false
        end,
        onChange = function(checked)
            BR.profile.enabledBuffs[key] = checked
            UpdateDisplay()
        end,
    })
    checkbox:SetPoint("LEFT", 0, 0)

    local iconTex = body:CreateTexture(nil, "ARTWORK")
    iconTex:SetSize(ICON_SIZE, ICON_SIZE)
    iconTex:SetPoint("LEFT", checkbox, "RIGHT", 6, 0)
    -- Resolve live (set/spec may have been re-iconed since save); GetRuleIcon
    -- always returns a usable texture, falling back to rule.icon then a default.
    local tex = BR.Loadouts.GetRuleIcon(rule)
    if tex then
        iconTex:SetTexture(tex)
        iconTex:SetTexCoord(TEXCOORD_INSET, 1 - TEXCOORD_INSET, TEXCOORD_INSET, 1 - TEXCOORD_INSET)
    else
        iconTex:SetTexture(DEFAULT_ICON_TEXTURE)
    end

    local deleteBtn = CreateButton(body, L["Options.Delete"], onDelete)
    deleteBtn:SetSize(ACTION_BUTTON_WIDTH, ACTION_BUTTON_HEIGHT)
    deleteBtn:SetPoint("RIGHT", 0, 0)

    local editBtn = CreateButton(body, L["CustomBuff.EditShort"], onEdit)
    editBtn:SetSize(ACTION_BUTTON_WIDTH, ACTION_BUTTON_HEIGHT)
    editBtn:SetPoint("RIGHT", deleteBtn, "LEFT", -ACTION_BUTTON_GAP, 0)

    local summaryLine = FormatSummary(rule)
    local hasSummary = summaryLine ~= ""
    local nameY = hasSummary and 6 or 0

    -- Class-colored binding, right-aligned on the name line. Sizes to its own
    -- text (single right anchor), so the name truncates against its left edge.
    local bindingLine = FormatBinding(rule)
    local nameRightAnchor, nameRightY = editBtn, nameY
    if bindingLine then
        local bindingText = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        bindingText:SetPoint("RIGHT", editBtn, "LEFT", -8, nameY)
        bindingText:SetJustifyH("RIGHT")
        bindingText:SetWordWrap(false)
        bindingText:SetText(bindingLine)
        -- bindingText already sits at nameY, so the name anchors to it at y=0.
        nameRightAnchor, nameRightY = bindingText, 0
    end

    local nameText = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameText:SetPoint("LEFT", iconTex, "RIGHT", 6, nameY)
    nameText:SetPoint("RIGHT", nameRightAnchor, "LEFT", -8, nameRightY)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    nameText:SetText(rule.name or key)

    if hasSummary then
        local summaryText = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        summaryText:SetPoint("LEFT", iconTex, "RIGHT", 6, -6)
        summaryText:SetPoint("RIGHT", editBtn, "LEFT", -8, -6)
        summaryText:SetJustifyH("LEFT")
        summaryText:SetWordWrap(false)
        summaryText:SetText(summaryLine)
    end
end

local function Build(content, scrollFrame)
    local contentWidth = scrollFrame:GetContentWidth()
    local layout = Components.VerticalLayout(content, { x = COL_PADDING, y = -16 })

    LayoutSectionHeader(layout, content, L["Category.LoadoutReminders"])
    LayoutSectionNote(layout, content, L["Category.LoadoutNote"])

    -- Fixed-height bordered list, nested under the section accent line.
    local listX = layout:GetX()
    local listWidth = contentWidth - listX - COL_PADDING
    local listWrapper, listScroll = Components.BorderedList(content, {
        width = listWidth,
        height = LIST_HEIGHT,
    })
    layout:Add(listWrapper, LIST_HEIGHT, LIST_TO_FOOTER_GAP)

    local listContent = listScroll:GetContentFrame()
    local rowPool = {}
    local rowCount = 0

    local emptyText = listContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("TOPLEFT", 8, -8)
    emptyText:SetJustifyH("LEFT")
    emptyText:SetText(L["Loadout.Empty"])
    emptyText:Hide()

    local Render -- forward decl; FillRowBody callbacks reference it

    local function AcquireRow(index)
        local row = rowPool[index]
        if not row then
            row = CreateRow(listContent)
            rowPool[index] = row
        end
        row:SetWidth(listScroll:GetContentWidth())
        row:Show()
        return row
    end

    Render = function()
        for i = 1, rowCount do
            rowPool[i]:Hide()
        end
        rowCount = 0

        local rules = BR.profile.loadoutReminders or {}

        local sortedKeys = {}
        for key in pairs(rules) do
            tinsert(sortedKeys, key)
        end
        tsort(sortedKeys, function(a, b)
            local ra, rb = rules[a], rules[b]
            return (ra.name or a) < (rb.name or b)
        end)

        if #sortedKeys == 0 then
            emptyText:Show()
            listScroll:SetContentHeight(LIST_HEIGHT - LIST_INSET * 2)
            return
        end
        emptyText:Hide()

        local y = 0
        for _, key in ipairs(sortedKeys) do
            local rule = rules[key]
            rowCount = rowCount + 1

            local row = AcquireRow(rowCount)
            row:SetPoint("TOPLEFT", 0, y)

            if row.body then
                row.body:Hide()
                row.body:SetParent(nil)
            end
            local body = CreateFrame("Frame", nil, row)
            body:SetAllPoints()
            row.body = body

            FillRowBody(body, key, rule, function()
                BR.Options.Dialogs.LoadoutReminder.Show(key, Render)
            end, function()
                StaticPopup_Show("BUFFREMINDERS_DELETE_LOADOUT", rule.name or key, nil, {
                    key = key,
                    refreshPanel = Render,
                })
            end)

            y = y - ROW_HEIGHT
        end

        -- Content height tracks the rows; the fixed-height scroll handles
        -- overflow. Never shrink below the visible area or short lists float.
        local total = -y
        local minH = LIST_HEIGHT - LIST_INSET * 2
        listScroll:SetContentHeight(total > minH and total or minH)
    end

    Render()

    -- Footer: Add button below the list.
    local addBtn = CreateButton(content, L["Loadout.AddButton"], function()
        BR.Options.Dialogs.LoadoutReminder.Show(nil, Render)
    end)
    addBtn:SetSize(180, ACTION_BUTTON_HEIGHT)
    layout:Add(addBtn, ACTION_BUTTON_HEIGHT, SECTION_GAP)

    -- Shared category sections (loadout) sit directly below the footer.
    local sectionsTopY = layout:GetY()
    local sectionsContainer = CreateFrame("Frame", nil, content)
    sectionsContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 0, sectionsTopY)
    sectionsContainer:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    sectionsContainer:SetHeight(1)

    local sectionsLayout = Components.VerticalLayout(sectionsContainer, { x = COL_PADDING, y = 0 })

    local UpdateContentHeight

    local ctx = {
        category = "loadout",
        content = sectionsContainer,
        scrollFrame = scrollFrame,
        contentWidth = contentWidth,
        appearancePadding = 8,
        onAppearanceResize = function()
            if UpdateContentHeight then
                UpdateContentHeight()
            end
        end,
    }
    local Sections = BR.Options.BuffSections
    Sections.Layout(ctx, sectionsLayout)
    Sections.CustomAppearance(ctx, sectionsLayout)

    UpdateContentHeight = function()
        content:SetHeight(abs(sectionsTopY) + sectionsContainer:GetHeight() + 30)
    end
    UpdateContentHeight()

    local refreshHook = CreateFrame("Frame", nil, listContent)
    refreshHook:SetSize(1, 1)
    function refreshHook:Refresh()
        Render()
    end
    tinsert(BR.RefreshableComponents, refreshHook)

    BR.Options.Pages.loadout._UpdateContentHeight = UpdateContentHeight
end

BR.Options.Pages.loadout = {
    title = L["Category.LoadoutReminders"],
    Build = Build,
}
