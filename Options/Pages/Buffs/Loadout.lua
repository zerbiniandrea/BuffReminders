local _, BR = ...

-- ============================================================================
-- LOADOUT REMINDERS PAGE
-- ============================================================================
-- List of user-defined loadout reminders, one row per rule. Add and edit open
-- BR.Options.Dialogs.LoadoutReminder.Show.
--
-- Built on the shared BR.Options.Helpers.ListEditor skeleton: rows flow in the
-- page's own scroll container, with no nested scroll box. This page supplies
-- only the data source (getItems) and the row content (fillRow).
--
-- Display styling for the loadout category lives on the Categories page's
-- Loadout tab. This page is only the rule-list editor.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local ListEditor = BR.Options.Helpers.ListEditor

local UpdateDisplay = BR.Display.Update

local TEXCOORD_INSET = BR.TEXCOORD_INSET

local C_ClassColor = C_ClassColor

local ROW_HEIGHT = 28
local ICON_SIZE = 20
local ACTION_BUTTON_WIDTH = 60
local ACTION_BUTTON_HEIGHT = 22
local ACTION_BUTTON_GAP = 8

local REQUIRE_LABELS = {
    gear = "Loadout.Require.Gear",
    talent = "Loadout.Require.Talent",
    loadout = "Loadout.Require.Loadout",
}

local SCOPE_LABELS = BR.Options.LoadoutScopeLabel

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

---What this rule was saved on (the bound spec or character), class-colored.
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

local function FillRowBody(body, key, rule, onEdit, onDelete)
    local checkbox = Components.Checkbox(body, {
        label = "",
        holderWidth = 18,
        get = function()
            return BR.StateHelpers.IsBuffEnabled(key)
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
    iconTex:SetTexture(BR.Loadouts.GetRuleIcon(rule))
    iconTex:SetTexCoord(TEXCOORD_INSET, 1 - TEXCOORD_INSET, TEXCOORD_INSET, 1 - TEXCOORD_INSET)

    local deleteBtn = CreateButton(body, L["Options.Delete"], onDelete)
    deleteBtn:SetSize(ACTION_BUTTON_WIDTH, ACTION_BUTTON_HEIGHT)
    deleteBtn:SetPoint("RIGHT", 0, 0)

    local editBtn = CreateButton(body, L["CustomBuff.EditShort"], onEdit)
    editBtn:SetSize(ACTION_BUTTON_WIDTH, ACTION_BUTTON_HEIGHT)
    editBtn:SetPoint("RIGHT", deleteBtn, "LEFT", -ACTION_BUTTON_GAP, 0)

    local summaryLine = FormatSummary(rule)
    local hasSummary = summaryLine ~= ""
    local nameY = hasSummary and 6 or 0

    -- A single right anchor sizes the binding to its own text, so the name
    -- truncates against the binding's left edge.
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

-- Sorted {key, rule} list of the user's loadout reminders, alphabetized by name.
local function GetSortedRules()
    local rules = BR.profile.loadoutReminders or {}
    local items = {}
    for key, rule in pairs(rules) do
        table.insert(items, { key = key, rule = rule })
    end
    table.sort(items, function(a, b)
        return (a.rule.name or a.key) < (b.rule.name or b.key)
    end)
    return items
end

local function Build(content, scrollFrame)
    -- Name Talent Loadout Ex only when it is installed. Other users must see no
    -- mention of an addon they do not have.
    local note = L["Category.LoadoutNote"]
    if BR.Loadouts.IsTLXAvailable() then
        note = note .. "\n" .. L["Category.LoadoutTLXNote"]
    end

    ListEditor(content, scrollFrame, {
        header = L["Category.LoadoutReminders"],
        note = note,
        addLabel = L["Loadout.AddButton"],
        addWidth = 180,
        onAdd = function(render)
            BR.Options.Dialogs.LoadoutReminder.Show(nil, render)
        end,
        rowHeight = ROW_HEIGHT,
        emptyText = L["Loadout.Empty"],
        getItems = GetSortedRules,
        fillRow = function(row, item, render)
            local key, rule = item.key, item.rule

            if row.body then
                row.body:Hide()
                row.body:SetParent(nil)
            end
            local body = CreateFrame("Frame", nil, row)
            body:SetAllPoints()
            row.body = body

            FillRowBody(body, key, rule, function()
                BR.Options.Dialogs.LoadoutReminder.Show(key, render)
            end, function()
                StaticPopup_Show("BUFFREMINDERS_DELETE_LOADOUT", rule.name or key, nil, {
                    key = key,
                    refreshPanel = render,
                })
            end)
        end,
    })
end

BR.Options.Pages.loadout = {
    title = L["Category.LoadoutReminders"],
    Build = Build,
}
