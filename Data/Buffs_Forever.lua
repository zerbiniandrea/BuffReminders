local _, ns = ...
---@class BR
local BR = ns

if BR.CLIENT ~= BR.ClientType.Forever then
    return
end

-- Each export mirrors a retail export that shared code reads.

---@type DKRuneforge[]
BR.DK_RUNEFORGES = {}

---@return boolean
function BR.IsInDelve()
    return false
end

BR.DEFAULT_POISON_PREFERENCES = {
    lethal = {},
    nonLethal = {},
}

BR.REPAIR_SOURCES = {
    mounts = {},
    items = {},
}

---@type table<string, table<number, ConsumableItemInfo|boolean>>
BR.CONSUMABLE_ITEMS = {}

---@type BuffTables
BR.BUFF_TABLES = {
    raid = {},
    presence = {},
    targeted = {},
    self = {},
    pet = {},
    custom = {},
    loadout = {},
    consumable = {},
    utility = {},
}
