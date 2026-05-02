local _, BR = ...

-- ============================================================================
-- CONSUMABLE MEMORY
-- ============================================================================
-- Tracks which consumable the player last used per spec, so the display layer
-- can sort the preferred item first. Three detection paths feed into this module:
--
-- 1. State.lua (ShouldShowConsumableBuff) - spell-based consumables (flasks, runes, tea)
--    Calls ConsumableMemory.Remember() with updateOnly=true (refreshes existing preference,
--    never creates new entries - prevents leaking preferences across spec switches).
--
-- 2. PostClick handlers (SecureButtons.lua) - addon click-to-cast
--    Calls ConsumableMemory.RememberChoice() when a consumable button is clicked.
--
-- 3. Count-delta tracking - food and weapon enchants used outside the addon
--    ConsumableMemory.DetectConsumedItems() compares item counts between bag refreshes.

local GetItemSpell = GetItemSpell

-- ============================================================================
-- FLEETING FLASK DETECTION
-- ============================================================================
-- Fleeting/cauldron flasks sort first by numeric priority and should NOT be
-- remembered - they would overwrite the user's regular flask preference.

---Check if an item is a fleeting flask.
---@param itemID number
---@return boolean
local function IsFleetingItem(itemID)
    return BR.FLEETING_FLASK_ITEMS and BR.FLEETING_FLASK_ITEMS[itemID] or false
end

-- Lazily-built set of spell IDs that fleeting flask items cast.
local fleetingSpellIDs = nil

---Check if a spell ID corresponds to a fleeting flask.
---@param spellID number
---@return boolean
local function IsFleetingSpell(spellID)
    if not fleetingSpellIDs then
        fleetingSpellIDs = {}
        for itemID in pairs(BR.FLEETING_FLASK_ITEMS or {}) do
            local ok, _, sid = pcall(GetItemSpell, itemID)
            if ok and sid then
                fleetingSpellIDs[sid] = true
            end
        end
    end
    return fleetingSpellIDs[spellID] or false
end

-- ============================================================================
-- REMEMBER / READ
-- ============================================================================

---Remember a consumable spell for the current spec.
---@param specId number Player's current specialization ID
---@param category string Consumable category (e.g., "flask", "food", "weapon")
---@param spellID number The spell ID to remember
---@param updateOnly? boolean When true, only update an existing entry (never create new spec/category memory)
local function Remember(specId, category, spellID, updateOnly)
    if not specId or not category or not spellID then
        return
    end
    local db = BR.profile
    local mem = db.rememberedConsumables
    -- Fast path: already remembered (common case during steady-state)
    if mem and mem[specId] and mem[specId][category] == spellID then
        return
    end
    -- In updateOnly mode, only overwrite an existing entry (don't create new spec/category memory).
    -- This prevents passive buff detection from leaking preferences across spec switches.
    if updateOnly and not (mem and mem[specId] and mem[specId][category]) then
        return
    end
    if not mem then
        mem = {}
        db.rememberedConsumables = mem
    end
    if not mem[specId] then
        mem[specId] = {}
    end
    mem[specId][category] = spellID
end

---Get the remembered spell ID for a category and spec.
---@param specId number? Player's current specialization ID
---@param category string Consumable category
---@return number? spellID The remembered spell ID, or nil
local function GetRemembered(specId, category)
    if not specId then
        return nil
    end
    local mem = BR.profile.rememberedConsumables
    return mem and mem[specId] and mem[specId][category]
end

-- ============================================================================
-- CLICK-TO-CAST REMEMBER (PostClick path)
-- ============================================================================

---Remember a consumable that was clicked via the addon's action buttons.
---Resolves item → spell via GetItemSpell, skips fleeting flasks.
---@param itemID number? The item that was clicked
---@param buffFrame table? The buff frame the click originated from
local function RememberChoice(itemID, buffFrame)
    if not itemID or not buffFrame or buffFrame.buffCategory ~= "consumable" then
        return
    end
    if IsFleetingItem(itemID) then
        return
    end
    local ok, _, useSpellID = pcall(GetItemSpell, itemID)
    if not ok or not useSpellID then
        return
    end
    local resolvedFrame = buffFrame.mainFrame or buffFrame
    local cat = BR.BUFF_KEY_TO_CATEGORY[resolvedFrame.key]
    local specId = BR.StateHelpers and BR.StateHelpers.GetPlayerSpecId()
    if not cat or not specId then
        return
    end
    Remember(specId, cat, useSpellID)
end

-- ============================================================================
-- COUNT-DELTA TRACKING (food and weapon enchants used outside addon)
-- ============================================================================

-- Previous item counts per category, for detecting which item was consumed.
-- Structure: previousCounts[category][itemID] = { count = N, useSpellID = S }
local previousCounts = {}

---Detect consumed food/weapon items by comparing current buckets with previous counts.
---Automatically remembers the consumed item's spell for the current spec.
---Only runs for "food" and "weapon" categories (spell-based consumables are handled by State.lua).
---@param buckets table Current bag scan buckets: category → { [itemID] = { count, useSpellID, ... } }
---@param specId number? Player's current specialization ID
local function DetectConsumedItems(buckets, specId)
    if not specId then
        return
    end
    local isEating = BR.StateHelpers and BR.StateHelpers.IsPlayerEating and BR.StateHelpers.IsPlayerEating()
    for category, oldItems in pairs(previousCounts) do
        if category == "food" or category == "weapon" then
            for itemID, old in pairs(oldItems) do
                if old.useSpellID then
                    local newBucket = buckets[category] and buckets[category][itemID]
                    local newCount = newBucket and newBucket.count or 0
                    if newCount < old.count then
                        -- Food: only remember if player is eating (skip vendoring/discarding)
                        if category ~= "food" or isEating then
                            Remember(specId, category, old.useSpellID)
                        end
                    end
                end
            end
        end
    end
end

---Update the count snapshot from current bag scan buckets (for next delta comparison).
---Reuses existing tables to reduce GC pressure.
---@param buckets table Current bag scan buckets: category → { [itemID] = { count, useSpellID, ... } }
local function SnapshotCounts(buckets)
    -- Remove categories no longer in buckets, wipe existing ones for reuse
    for category, catTable in pairs(previousCounts) do
        if not buckets[category] then
            previousCounts[category] = nil
        else
            wipe(catTable)
        end
    end
    -- Populate from current buckets, reuse per-item tables when possible
    for category, entries in pairs(buckets) do
        if not previousCounts[category] then
            previousCounts[category] = {}
        end
        local catTable = previousCounts[category]
        for itemID, item in pairs(entries) do
            local prev = catTable[itemID]
            if prev then
                prev.count = item.count
                prev.useSpellID = item.useSpellID
            else
                catTable[itemID] = { count = item.count, useSpellID = item.useSpellID }
            end
        end
    end
end

-- ============================================================================
-- EXPORT
-- ============================================================================

BR.ConsumableMemory = {
    Remember = Remember,
    GetRemembered = GetRemembered,
    IsFleetingSpell = IsFleetingSpell,
    IsFleetingItem = IsFleetingItem,
    RememberChoice = RememberChoice,
    DetectConsumedItems = DetectConsumedItems,
    SnapshotCounts = SnapshotCounts,
}
