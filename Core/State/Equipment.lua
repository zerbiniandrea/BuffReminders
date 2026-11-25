local _, ns = ...
---@class BR
local BR = ns

-- Equipment state: the off-hand type, weapon subclasses, durability, repair sources and ammo.

---@class BuffState
local BuffState = BR.BuffState

local Plain = BR.Secret.Plain
local HasItemInBags = BR.StateHelpers.HasItemInBags
local REPAIR_SOURCES = BR.BuffData.repairSources

-- Off-hand slot type cache (invalidated on equipment/spec change)
-- Populated together from a single GetInventoryItemID + GetItemInfoInstant call
local cachedOffHandType = nil -- nil = not yet checked, "weapon" | "shield" | "none"

-- Weapon subclass per hand slot, false for no weapon. Cleared with the off-hand cache.
---@type table<number, number|false>
local cachedWeaponSubclass = {}

-- Lowest equipped-item durability ratio (0-1). The 18-slot scan is a read-only
-- lookup whose answer only changes on durability / equipment events, so it is
-- memoized and reused on the fallback ticker instead of re-scanned every refresh.
---@type number|nil
local cachedLowestDurability = nil

-- Resolved repair click sources (mount to summon / item to use). Mount collection
-- and bag contents only change on their own events, so the pair is resolved once.
-- Only ever holds a positive answer (see GetRepairSources).
---@type { mountSpellID: number?, mountID: number?, itemID: number? }|nil
local cachedRepairSources = nil

local function ResolveOffHandType()
    if cachedOffHandType ~= nil then
        return
    end
    local offhandItemID = GetInventoryItemID("player", 17) -- INVSLOT_OFFHAND
    if not offhandItemID then
        -- Trust an empty off-hand only when inventory data is loaded. Right after
        -- a loading screen or an equipment swap, slot 17 can transiently read nil
        -- for a real dual-wielder. A cached "none" then poisons the rest of the
        -- session (dual-wielder read as two-handed -> wrong rune bucket). The main
        -- hand is always equipped, so a readable MH means inventory is loaded and a
        -- nil off-hand is truly empty. If MH is also nil, leave the cache unset so
        -- the next refresh retries.
        if GetInventoryItemID("player", 16) then -- INVSLOT_MAINHAND
            cachedOffHandType = "none"
        end
        return
    end
    local _, _, _, _, _, itemClassID, itemSubClassID = C_Item.GetItemInfoInstant(offhandItemID)
    if not itemClassID then
        -- Item data is not available yet (intermittent right after login/reload).
        -- Leave the cache unset so the next refresh retries. A stale "none" here
        -- poisons the session and makes a dual-wielder read as two-handed.
        return
    end
    if itemClassID == 2 then -- Enum.ItemClass.Weapon
        cachedOffHandType = "weapon"
    elseif itemClassID == 4 and itemSubClassID == 6 then -- Armor + Shield
        cachedOffHandType = "shield"
    else
        cachedOffHandType = "none"
    end
end

---Check if off-hand slot has a weapon (cached)
---@return boolean
function BuffState.HasOffHandWeapon()
    ResolveOffHandType()
    return cachedOffHandType == "weapon"
end

---Check if off-hand slot has a shield (cached)
---@return boolean
function BuffState.HasShield()
    ResolveOffHandType()
    return cachedOffHandType == "shield"
end

---Weapon subclass (Enum.ItemWeaponSubclass) of the item in a weapon slot (cached).
---@param slot number 16 (main hand), 17 (off hand) or 18 (ranged)
---@return number? subclassID nil when the slot holds no weapon or the item data is not loaded
function BuffState.GetWeaponSubclass(slot)
    local cached = cachedWeaponSubclass[slot]
    if cached ~= nil then
        return cached or nil
    end
    local itemID = GetInventoryItemID("player", slot)
    if not itemID then
        return nil
    end
    local _, _, _, _, _, itemClassID, itemSubClassID = C_Item.GetItemInfoInstant(itemID)
    if not itemClassID then
        return nil
    end
    cachedWeaponSubclass[slot] = itemClassID == 2 and itemSubClassID or false
    return cachedWeaponSubclass[slot] or nil
end

---Invalidate the off-hand weapon/shield and weapon subclass caches
function BuffState.InvalidateOffHandCache()
    cachedOffHandType = nil
    wipe(cachedWeaponSubclass)
end

---Lowest equipped-item durability ratio (0-1; 1 when nothing is damaged), cached.
---Slots without durability (neck/rings/trinkets/shirt/tabard) return nil and are skipped.
---@return number
function BuffState.GetLowestDurability()
    if cachedLowestDurability ~= nil then
        return cachedLowestDurability
    end
    local lowest = 1
    local readable = false
    for slot = 1, 18 do
        local cur, max = GetInventoryItemDurability(slot)
        if cur and max and max > 0 then
            readable = true
            local pct = cur / max
            if pct < lowest then
                lowest = pct
            end
        end
    end
    -- Only a readable answer is cached: a zone change answers nil for every slot
    -- while the inventory resolves, and a frozen "nothing is damaged" hides the
    -- repair reminder until the next durability event.
    if readable then
        cachedLowestDurability = lowest
    end
    return lowest
end

---Invalidate the durability cache
function BuffState.InvalidateDurabilityCache()
    cachedLowestDurability = nil
end

---Best repair sources for the repair reminder's click action: a collected repair
---mount and/or a usable repair item. Both answers only change on collection and
---bag events, so the resolved pair is memoized.
---@return { mountSpellID: number?, mountID: number?, itemID: number? }
function BuffState.GetRepairSources()
    if cachedRepairSources then
        return cachedRepairSources
    end
    local sources = {}
    for _, spellID in ipairs(REPAIR_SOURCES.mounts) do
        local mountID = C_MountJournal.GetMountFromSpell(spellID)
        if mountID then
            local _, _, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
            if isCollected then
                sources.mountSpellID = spellID
                sources.mountID = mountID
                break
            end
        end
    end
    for _, itemID in ipairs(REPAIR_SOURCES.items) do
        if HasItemInBags(itemID) then
            -- A retired use effect must not arm a dead click, so ownership is not
            -- enough. An unreadable verdict means the item info is not cached yet;
            -- ownership decides then.
            local ok, usable = pcall(C_Item.IsUsableItem, itemID)
            if not ok or usable ~= false then
                sources.itemID = itemID
                break
            end
        end
    end
    -- Only a positive resolution is cached: the mount journal is not always
    -- populated at login, and a frozen "owns nothing" leaves the icon inert for the
    -- whole session. An empty answer resolves again on the next arming pass.
    if sources.mountSpellID or sources.itemID then
        cachedRepairSources = sources
    end
    return sources
end

---Whether the collected repair mount can be summoned where the player stands.
---The `[outdoors]` macro conditional cannot answer this: an outdoor area that
---blocks mounts still reads as outdoors, so the click spends nothing. The mount
---journal knows the real restriction. The answer follows the subzone, so it is
---never cached - the macro that reads it is rebuilt on every zone change.
---@return boolean
function BuffState.IsRepairMountUsable()
    local mountID = BuffState.GetRepairSources().mountID
    if not mountID then
        return false
    end
    return C_MountJournal.GetMountUsabilityByID(mountID, IsIndoors()) == true
end

---Invalidate the repair source cache
function BuffState.InvalidateRepairSourceCache()
    cachedRepairSources = nil
end

do
    local ammoID, ammoCount -- false = read and empty, nil = not read

    ---Equipped ammo item and its count (cached). nil when the client has no ammo slot or it is empty.
    ---@return number? itemID
    ---@return number count
    function BuffState.GetEquippedAmmo()
        if not INVSLOT_AMMO then
            return nil, 0
        end
        if ammoID == nil then
            ammoID = Plain(GetInventoryItemID("player", INVSLOT_AMMO)) or false
            ammoCount = ammoID and Plain(GetInventoryItemCount("player", INVSLOT_AMMO)) or 0
        end
        return ammoID or nil, ammoCount or 0
    end

    function BuffState.InvalidateAmmoCache()
        ammoID, ammoCount = nil, nil
    end
end

BR.GameContext.RegisterCache("offHand", BuffState.InvalidateOffHandCache)
BR.GameContext.RegisterCache("durability", BuffState.InvalidateDurabilityCache)
BR.GameContext.RegisterCache("repairSource", BuffState.InvalidateRepairSourceCache)
BR.GameContext.RegisterCache("ammo", BuffState.InvalidateAmmoCache)
