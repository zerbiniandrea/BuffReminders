local _, ns = ...
---@class BR
local BR = ns

if BR.CLIENT ~= BR.ClientType.Forever then
    return
end

-- Low reagent reminder: which reagents of BR.REAGENTS are below their count, and the
-- short window that shows the reminder outside rested areas after a reagent drops
-- below its count.

local L = BR.L
local IsPlayerSpellCached = BR.StateHelpers.IsPlayerSpellCached
local GetItemCountCached = BR.StateHelpers.GetItemCountCached
local GameContext = BR.GameContext

local WINDOW_SECONDS = 15

local _, playerClass = UnitClass("player")

---@type ForeverReagent[]
local PLAYER_REAGENTS = {}
for _, reagent in ipairs(BR.REAGENTS) do
    for _, class in ipairs(reagent.classes) do
        if class == playerClass then
            PLAYER_REAGENTS[#PLAYER_REAGENTS + 1] = reagent
        end
    end
end

---@param reagent ForeverReagent
---@return ForeverReagentRank?
local function KnownRank(reagent)
    for _, rank in ipairs(reagent.ranks) do
        for _, spellID in ipairs(rank.spells) do
            if IsPlayerSpellCached(spellID) then
                return rank
            end
        end
    end
    return nil
end

---@param reagent ForeverReagent
---@return number
local function Threshold(reagent)
    local defaults = BR.profile.defaults
    local thresholds = defaults and defaults.reagentThresholds
    return thresholds and thresholds[reagent.key] or reagent.warnBelow
end

local windowTimer
---@type ForeverReagent? The reagent whose drop opened the window
local windowReagent

---@param reagent ForeverReagent
---@return ForeverReagentRank? rank nil when the reagent is not low
---@return number? count
local function LowRank(reagent)
    local rank = KnownRank(reagent)
    if not rank then
        return nil
    end
    local count = GetItemCountCached(rank.item)
    if count < Threshold(reagent) then
        return rank, count
    end
    return nil
end

---The reagent to show: during a window, the one that dropped. Else the known reagent
---with the lowest count among those below their threshold, ties to the first in list order.
---@return ForeverReagentRank?
---@return number? count
local function Low()
    if windowReagent then
        local rank, count = LowRank(windowReagent)
        if rank then
            return rank, count
        end
    end
    local lowest, lowestCount
    for _, reagent in ipairs(PLAYER_REAGENTS) do
        local rank, count = LowRank(reagent)
        if rank and (not lowestCount or count < lowestCount) then
            lowest, lowestCount = rank, count
        end
    end
    return lowest, lowestCount
end

---@param tooltip table
local function AddTooltipLines(tooltip)
    tooltip:AddLine(" ")
    tooltip:AddLine(L["Tooltip.ReagentCounts"])
    for _, reagent in ipairs(PLAYER_REAGENTS) do
        local rank = KnownRank(reagent)
        if rank then
            local count = GetItemCountCached(rank.item)
            -- The name is nil until the item data loads.
            local name = C_Item.GetItemNameByID(rank.item) or ("item:" .. rank.item)
            local low = count < Threshold(reagent)
            tooltip:AddDoubleLine(
                "|T" .. rank.icon .. ":0|t " .. name,
                count,
                1,
                1,
                1,
                1,
                low and 0.2 or 1,
                low and 0.2 or 1
            )
        end
    end
end

-- ============================================================================
-- WINDOW
-- ============================================================================

-- A drop in combat opens the window when combat ends, where the reminder can show.
---@type ForeverReagent?
local pendingReagent
-- Reagent key -> below its threshold, at this scan and at the scan before it.
---@type table<string, boolean>
local lowNow, lowBefore = {}, {}
local scanned = false

---@param reagent ForeverReagent
local function OpenWindow(reagent)
    if windowTimer then
        windowTimer:Cancel()
    end
    windowReagent = reagent
    windowTimer = C_Timer.NewTimer(WINDOW_SECONDS, function()
        windowTimer = nil
        windowReagent = nil
        BR.CallbackRegistry:TriggerEvent("RenderRequested", true)
    end)
    BR.CallbackRegistry:TriggerEvent("RenderRequested", true)
end

---Record which reagents are low.
---@return ForeverReagent? dropped The first reagent that went below its threshold since the last scan
local function Scan()
    lowBefore, lowNow = lowNow, lowBefore
    wipe(lowNow)
    local dropped
    for _, reagent in ipairs(PLAYER_REAGENTS) do
        local rank = KnownRank(reagent)
        if rank then
            -- Live: the item cache can still hold the count from before this bag event.
            local isLow = GetItemCountCached(rank.item, true) < Threshold(reagent)
            lowNow[reagent.key] = isLow
            if isLow and not dropped and scanned and lowBefore[reagent.key] == false then
                dropped = reagent
            end
        end
    end
    scanned = true
    return dropped
end

if #PLAYER_REAGENTS > 0 then
    local eventFrame = CreateFrame("Frame")
    BR.Client.RegisterEvent(eventFrame, "BAG_UPDATE_DELAYED")
    BR.Client.RegisterEvent(eventFrame, "PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if pendingReagent then
                OpenWindow(pendingReagent)
                pendingReagent = nil
            end
            return
        end
        if not BR.aceDB then
            return
        end
        local dropped = Scan()
        if not dropped or GameContext.IsResting() then
            return
        end
        if GameContext.IsInCombat() then
            pendingReagent = dropped
        else
            OpenWindow(dropped)
        end
    end)

    -- A threshold edit or a profile change must not read as a drop at the next bag event.
    BR.CallbackRegistry:RegisterCallback("DisplayRefresh", function()
        if BR.aceDB then
            Scan()
        end
    end)
end

BR.Reagents = {
    WINDOW_SECONDS = WINDOW_SECONDS,
    Low = Low,
    AddTooltipLines = AddTooltipLines,
    ---@return boolean
    IsWindowOpen = function()
        return windowTimer ~= nil
    end,
}
