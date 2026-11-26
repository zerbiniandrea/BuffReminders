local _, ns = ...
---@class BR
local BR = ns

if BR.CLIENT ~= BR.ClientType.Forever then
    return
end

-- ============================================================================
-- REAGENT EDITOR (inline section)
-- ============================================================================
-- One count stepper per reagent, grouped by class in two columns. A reagent that
-- two classes use shows in both groups and stores one count.
--
-- BuildInline(parent, opts) draws the editor into `parent` at (opts.x, opts.y)
-- within opts.width and returns the vertical space it consumed. Holders go to
-- opts.registerHolder, so the panel can unregister them on teardown.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton

local DEPENDENT_INDENT = BR.Options.Constants.DEPENDENT_INDENT

local CHECKBOX_HEIGHT = 22
local NOTE_GAP = 8
local HEADER_HEIGHT = 18
local ROW_HEIGHT = 22
local GROUP_GAP = 10
local COLUMN_GAP = 16
local RESET_GAP = 6
local RESET_HEIGHT = 22
local STEPPER_MAX = 200

---@param reagent ForeverReagent
---@return string
local function ThresholdPath(reagent)
    return "defaults.reagentThresholds." .. reagent.key
end

---@param rank ForeverReagentRank
---@return string
local function ReagentLabel(rank)
    local name = C_Item.GetItemNameByID(rank.item) or ("item:" .. rank.item)
    return "|T" .. rank.icon .. ":14|t " .. name
end

---@return {class: ClassName, reagents: ForeverReagent[]}[]
local function ClassGroups()
    local groups, byClass = {}, {}
    for _, reagent in ipairs(BR.REAGENTS) do
        for _, class in ipairs(reagent.classes) do
            local group = byClass[class]
            if not group then
                group = { class = class, reagents = {} }
                byClass[class] = group
                groups[#groups + 1] = group
            end
            group.reagents[#group.reagents + 1] = reagent
        end
    end
    return groups
end

---Render the reagent editor into `parent`. Returns the height consumed (px).
---@param parent table Frame to parent the editor into
---@param opts table { x, y, width, registerHolder? }
---@return number height
local function BuildInline(parent, opts)
    local x, y, width = opts.x, opts.y, opts.width
    local register = opts.registerHolder or function(_) end

    local restedHolder = Components.Checkbox(parent, {
        label = L["Options.Reagent.RestedOnly"],
        holderWidth = width,
        get = function()
            return BR.Config.Get("defaults.reagentRestedOnly") ~= false
        end,
        tooltip = { title = L["Options.Reagent.RestedOnly"], desc = L["Options.Reagent.RestedOnly.Desc"] },
        onChange = function(checked)
            BR.Config.Set("defaults.reagentRestedOnly", checked)
            Components.RefreshAll()
        end,
    })
    restedHolder:SetPoint("TOPLEFT", x, y)
    register(restedHolder)

    local seconds = BR.Reagents.WINDOW_SECONDS
    local dropLabel = L["Options.Reagent.DropWarning"]:format(seconds)
    local dropHolder = Components.Checkbox(parent, {
        label = dropLabel,
        holderWidth = width - DEPENDENT_INDENT,
        get = function()
            return BR.Config.Get("defaults.reagentDropWarning") ~= false
        end,
        enabled = function()
            return BR.Config.Get("defaults.reagentRestedOnly") ~= false
        end,
        disabledReason = L["DisabledReason.ReagentDropWarning"],
        tooltip = { title = dropLabel, desc = L["Options.Reagent.DropWarning.Desc"]:format(seconds) },
        onChange = function(checked)
            BR.Config.Set("defaults.reagentDropWarning", checked)
        end,
    })
    dropHolder:SetPoint("TOPLEFT", x + DEPENDENT_INDENT, y - CHECKBOX_HEIGHT)
    register(dropHolder)

    local note = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", x, y - CHECKBOX_HEIGHT * 2 - NOTE_GAP)
    note:SetWidth(width)
    note:SetJustifyH("LEFT")
    note:SetText(L["Options.Reagent.Note"])
    local noteH = math.max(math.ceil(note:GetStringHeight()), 12)

    local gridTop = y - CHECKBOX_HEIGHT * 2 - NOTE_GAP - noteH - NOTE_GAP
    local colWidth = (width - COLUMN_GAP) / 2
    local columnY = { gridTop, gridTop }
    local stepperWidth = 32 + 30 + 16
    local labelWidth = colWidth - stepperWidth

    for _, group in ipairs(ClassGroups()) do
        -- Each group goes to the shorter column.
        local col = columnY[1] >= columnY[2] and 1 or 2
        local cx = x + (col - 1) * (colWidth + COLUMN_GAP)
        local cy = columnY[col]

        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[group.class]
        local className = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[group.class]) or group.class
        local header = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        header:SetPoint("TOPLEFT", cx, cy)
        header:SetText(color and color:WrapTextInColorCode(className) or className)
        cy = cy - HEADER_HEIGHT

        for _, reagent in ipairs(group.reagents) do
            local rank = reagent.ranks[1]
            local holder = Components.NumericStepper(parent, {
                label = ReagentLabel(rank),
                labelWidth = labelWidth,
                min = 0,
                max = STEPPER_MAX,
                step = 1,
                formatValue = function(val)
                    return val == 0 and L["Options.Reagent.Off"] or tostring(val)
                end,
                get = function()
                    return BR.Config.Get(ThresholdPath(reagent)) or reagent.warnBelow
                end,
                onChange = function(val)
                    -- The default stays nil in the DB, so a later change of warnBelow applies.
                    BR.Config.Set(ThresholdPath(reagent), val ~= reagent.warnBelow and val or nil)
                    -- A shared reagent has a stepper in each of its class groups.
                    if #reagent.classes > 1 then
                        Components.RefreshAll()
                    end
                end,
            })
            holder:SetPoint("TOPLEFT", cx, cy)
            register(holder)
            if not C_Item.GetItemNameByID(rank.item) then
                Item:CreateFromItemID(rank.item):ContinueOnItemLoad(function()
                    holder.label:SetText(ReagentLabel(rank))
                end)
            end
            cy = cy - ROW_HEIGHT
        end
        columnY[col] = cy - GROUP_GAP
    end

    local gridBottom = math.min(columnY[1], columnY[2]) + GROUP_GAP

    local resetBtn = CreateButton(parent, L["Options.Reagent.Reset"], function()
        for _, reagent in ipairs(BR.REAGENTS) do
            if BR.Config.Get(ThresholdPath(reagent)) ~= nil then
                BR.Config.Set(ThresholdPath(reagent), nil)
            end
        end
        Components.RefreshAll()
    end)
    resetBtn:SetPoint("TOPLEFT", x, gridBottom - RESET_GAP)

    local finalY = gridBottom - RESET_GAP - RESET_HEIGHT
    return y - finalY
end

BR.Options.Dialogs.Reagents = {
    BuildInline = BuildInline,
    Name = L["BuffRow.Option.Reagents"],
    Width = 504,
}
