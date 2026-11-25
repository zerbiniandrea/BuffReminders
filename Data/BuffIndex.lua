local _, ns = ...
---@class BR
local BR = ns

local L = BR.L

local buffKeyToCategory = {}
for _, buff in ipairs(BR.BuffData.buffTables.consumable) do
    if buff.consumableCategory then
        buffKeyToCategory[buff.key] = buff.consumableCategory
    end
end
BR.BUFF_KEY_TO_CATEGORY = buffKeyToCategory

---@type table<string, BuffGroup>
BR.BuffGroups = {
    beacons = { displayName = L["Group.Beacons"] },
    dkRunes = { displayName = L["Group.DKRunes"] },
    shamanImbues = { displayName = L["Group.ShamanImbues"] },
    paladinRites = { displayName = L["Group.PaladinRites"] },
    pets = { displayName = L["Group.Pets"] },
    shamanShields = { displayName = L["Group.ShamanShields"] },
    -- Consumable groups
    flask = { displayName = L["Group.Flask"] },
    food = { displayName = L["Group.Food"] },
    delveFood = { displayName = L["Group.DelveFood"] },
    healthstone = { displayName = L["Group.Healthstone"] },
    rune = { displayName = L["Group.AugmentRune"] },
    weaponBuff = { displayName = L["Group.WeaponBuff"] },
}
