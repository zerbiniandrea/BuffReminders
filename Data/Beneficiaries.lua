local _, ns = ...
---@class BR
local BR = ns

-- Classes that benefit from each buff (fallback when spec is unknown)
-- nil = everyone benefits, otherwise only listed classes are counted
BR.BuffBeneficiaries = {
    intellect = {
        MAGE = true,
        WARLOCK = true,
        PRIEST = true,
        DRUID = true,
        SHAMAN = true,
        MONK = true,
        EVOKER = true,
        PALADIN = true,
    },
    attackPower = {
        WARRIOR = true,
        ROGUE = true,
        HUNTER = true,
        DEATHKNIGHT = true,
        PALADIN = true,
        MONK = true,
        DRUID = true,
        DEMONHUNTER = true,
        SHAMAN = true,
    },
    -- stamina, versatility, skyfury, bronze = everyone benefits (nil)
}

-- Hunters use mana on WoW Forever. Spirit helps the same mana users.
-- Blessing of Might raises melee attack power only.
if BR.CLIENT == BR.ClientType.Forever then
    BR.BuffBeneficiaries.intellect.HUNTER = true
    BR.BuffBeneficiaries.spirit = BR.BuffBeneficiaries.intellect
    BR.BuffBeneficiaries.meleeAttackPower = {
        WARRIOR = true,
        ROGUE = true,
        PALADIN = true,
        SHAMAN = true,
        DRUID = true,
    }
end

-- Specs that benefit from each buff (used when spec ID is known via LibSpecialization)
-- nil = everyone benefits (same as BuffBeneficiaries)
-- When a unit's spec is known, this takes priority over the class-based BuffBeneficiaries table.
BR.SpecBeneficiaries = {
    intellect = {
        [62] = true,
        [63] = true,
        [64] = true, -- Mage: Arcane, Fire, Frost
        [256] = true,
        [257] = true,
        [258] = true, -- Priest: Discipline, Holy, Shadow
        [265] = true,
        [266] = true,
        [267] = true, -- Warlock: Affliction, Demonology, Destruction
        [102] = true,
        [105] = true, -- Druid: Balance, Restoration
        [262] = true,
        [264] = true, -- Shaman: Elemental, Restoration
        [270] = true, -- Monk: Mistweaver
        [65] = true, -- Paladin: Holy
        [1467] = true,
        [1468] = true,
        [1473] = true, -- Evoker: Devastation, Preservation, Augmentation
        [1480] = true, -- Demon Hunter: Devourer
    },
    attackPower = {
        [71] = true,
        [72] = true,
        [73] = true, -- Warrior: Arms, Fury, Protection
        [259] = true,
        [260] = true,
        [261] = true, -- Rogue: Assassination, Outlaw, Subtlety
        [253] = true,
        [254] = true,
        [255] = true, -- Hunter: Beast Mastery, Marksmanship, Survival
        [250] = true,
        [251] = true,
        [252] = true, -- Death Knight: Blood, Frost, Unholy
        [577] = true,
        [581] = true, -- Demon Hunter: Havoc, Vengeance
        [103] = true,
        [104] = true, -- Druid: Feral, Guardian
        [263] = true, -- Shaman: Enhancement
        [268] = true,
        [269] = true, -- Monk: Brewmaster, Windwalker
        [66] = true,
        [70] = true, -- Paladin: Protection, Retribution
    },
    -- stamina, versatility, skyfury, bronze = everyone benefits (nil)
}
