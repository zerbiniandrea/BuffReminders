local _, BR = ...

-- ============================================================================
-- LOADOUT REMINDERS PAGE
-- ============================================================================
-- List of user-defined loadout reminders (one row per rule: enabled checkbox,
-- icon, name, summary, edit + delete). Add / edit open
-- BR.Options.Dialogs.LoadoutReminder.Show.
--
-- Built on the shared BR.Options.Helpers.ListEditor skeleton (same as the
-- Custom Buffs and Sound Alerts pages): rows flow directly in the page's own
-- scroll container (no nested scroll box) and the Add button sits above the list
-- so it stays reachable no matter how long the list grows. This page supplies
-- only what varies - the data source (getItems) and row content (fillRow).
-- Display styling for the loadout category lives on the Categories page's
-- Loadout tab; this page is purely the rule-list editor.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local ListEditor = BR.Options.Helpers.ListEditor

local UpdateDisplay = BR.Display.Update

local TEXCOORD_INSET = BR.TEXCOORD_INSET

local tinsert = table.insert
local tsort = table.sort
local C_ClassColor = C_ClassColor

local ROW_HEIGHT = 28
local ICON_SIZE = 20
local ACTION_BUTTON_WIDTH = 60
local ACTION_BUTTON_HEIGHT = 22
local ACTION_BUTTON_GAP = 8
local DEFAULT_ICON_TEXTURE = 134400

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

-- Sorted {key, rule} list of the user's loadout reminders, alphabetized by name.
local function GetSortedRules()
    local rules = BR.profile.loadoutReminders or {}
    local items = {}
    for key, rule in pairs(rules) do
        tinsert(items, { key = key, rule = rule })
    end
    tsort(items, function(a, b)
        return (a.rule.name or a.key) < (b.rule.name or b.key)
    end)
    return items
end

local function Build(content, scrollFrame)
    -- Advertise Talent Loadout Ex support only when it's actually installed, so
    -- non-users see no mention of a third-party addon they don't have.
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
