local _, ns = ...
---@class BR
local BR = ns

-- ============================================================================
-- CONSUMABLE MEMORY
-- ============================================================================
-- Tracks which consumable the player last used per spec. The display layer sorts
-- the preferred item first. Items used outside the addon have no event, so the
-- module detects them from item count deltas between bag refreshes.

local GetItemSpell = C_Item.GetItemSpell

-- WoW Forever has no specializations, so its memory uses one fixed key in place of the spec ID.
local NO_SPEC_KEY = BR.ByClient({ retail = BR.NONE, forever = 0 })

---@param specId number?
---@return number?
local function MemoryKey(specId)
    return specId or NO_SPEC_KEY
end

-- Categories whose memory comes from item count deltas. The remembered spell is the
-- use spell of the item.
local COUNT_TRACKED = { food = true, weapon = true }

---@param category string
---@return boolean
local function IsCountTracked(category)
    return COUNT_TRACKED[category] == true
end

-- ============================================================================
-- UNREMEMBERED FLASKS
-- ============================================================================
-- Fleeting flasks and cauldrons sort first by numeric priority. The module must
-- not remember them, because they overwrite the regular flask preference.

---Check if the module must not remember an item.
---@param itemID number
---@return boolean
local function IsUnrememberedItem(itemID)
    return BR.ConsumableData.unrememberedFlasks[itemID] or false
end

local unrememberedSpellIDs = nil

---Check if the module must not remember a spell.
---@param spellID number
---@return boolean
local function IsUnrememberedSpell(spellID)
    if not unrememberedSpellIDs then
        unrememberedSpellIDs = {}
        for itemID in pairs(BR.ConsumableData.unrememberedFlasks) do
            local ok, _, sid = pcall(GetItemSpell, itemID)
            if ok and sid then
                unrememberedSpellIDs[sid] = true
            end
        end
    end
    return unrememberedSpellIDs[spellID] or false
end

-- ============================================================================
-- REMEMBER / READ
-- ============================================================================

---Remember a consumable spell for the current spec.
---@param specId number? Player's current specialization ID
---@param category string Consumable category (e.g., "flask", "food", "weapon")
---@param spellID number The spell ID to remember
---@param updateOnly? boolean When true, only update an existing entry (never create new spec/category memory)
local function Remember(specId, category, spellID, updateOnly)
    specId = MemoryKey(specId)
    if not specId or not category or not spellID then
        return
    end
    local db = BR.profile
    local mem = db.rememberedConsumables
    if mem and mem[specId] and mem[specId][category] == spellID then
        return
    end
    -- Passive buff detection must not leak preferences across spec switches.
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
    specId = MemoryKey(specId)
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
---@param itemID number? The item that was clicked
---@param buffFrame table? The buff frame the click originated from
local function RememberChoice(itemID, buffFrame)
    if not itemID or not buffFrame or buffFrame.buffCategory ~= "consumable" then
        return
    end
    if IsUnrememberedItem(itemID) then
        return
    end
    local ok, _, useSpellID = pcall(GetItemSpell, itemID)
    if not ok or not useSpellID then
        return
    end
    local resolvedFrame = buffFrame.mainFrame or buffFrame
    local cat = BR.BUFF_KEY_TO_CATEGORY[resolvedFrame.key]
    local specId = MemoryKey(BR.StateHelpers and BR.StateHelpers.GetPlayerSpecId())
    if not cat or not specId then
        return
    end
    Remember(specId, cat, useSpellID)
end

-- ============================================================================
-- COUNT-DELTA TRACKING (food and weapon enchants used outside addon)
-- ============================================================================

-- Detects which item was consumed by comparing counts between bag scans.
---@type table<string, table<number, { count: number, useSpellID: number? }>>
local previousCounts = {}

---Detect consumed food/weapon items by comparing current buckets with previous counts.
---Remembers the consumed item's spell for the current spec.
---Only "food" and "weapon" apply. State.lua handles the spell-based consumables.
---@param buckets table Current bag scan buckets: category -> { [itemID] = { count, useSpellID, ... } }
---@param specId number? Player's current specialization ID
local function DetectConsumedItems(buckets, specId)
    specId = MemoryKey(specId)
    if not specId then
        return
    end
    local isEating = BR.StateHelpers and BR.StateHelpers.IsPlayerEating and BR.StateHelpers.IsPlayerEating()
    for category, oldItems in pairs(previousCounts) do
        if IsCountTracked(category) then
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
---@param buckets table Current bag scan buckets: category -> { [itemID] = { count, useSpellID, ... } }
local function SnapshotCounts(buckets)
    for category, catTable in pairs(previousCounts) do
        if not buckets[category] then
            previousCounts[category] = nil
        else
            wipe(catTable)
        end
    end
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
    IsUnrememberedSpell = IsUnrememberedSpell,
    IsUnrememberedItem = IsUnrememberedItem,
    IsCountTracked = IsCountTracked,
    RememberChoice = RememberChoice,
    DetectConsumedItems = DetectConsumedItems,
    SnapshotCounts = SnapshotCounts,
}
