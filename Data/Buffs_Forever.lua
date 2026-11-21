local _, ns = ...
---@class BR
local BR = ns

if BR.CLIENT ~= BR.ClientType.Forever then
    return
end

local L = BR.L

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

-- Spells have ranks, and every rank ID counts as the buff. Click-to-cast casts the
-- first ID in spellID that the player knows, so each list starts with the highest rank.
-- A raid buff lists its single-target ranks before its reagent group version.
---@type BuffTables
BR.BUFF_TABLES = {
    ---@type RaidBuff[]
    raid = {
        {
            spellID = { 10157, 10156, 1461, 1460, 1459, 23028 },
            key = "intellect",
            name = L["Buff.ArcaneIntellect"],
            class = "MAGE",
            reach = "raid",
            icons = { spells = { 10157 } },
            chatRequestable = true,
        },
        {
            spellID = { 25289, 11551, 11550, 11549, 6192, 5242, 6673 },
            key = "attackPower",
            name = L["Buff.BattleShout"],
            class = "WARRIOR",
            reach = "raid",
            -- Opt-in: it costs rage, which is empty between fights, and lasts 3 minutes.
            defaultEnabled = false,
        },
        {
            spellID = { 9885, 9884, 8907, 5234, 6756, 5232, 1126, 21850, 21849 },
            key = "versatility",
            name = L["Buff.MarkOfTheWild"],
            class = "DRUID",
            reach = "raid",
            icons = { spells = { 9885 } },
            chatRequestable = true,
        },
        {
            spellID = { 10938, 10937, 2791, 1245, 1244, 1243, 21564, 21562 },
            key = "stamina",
            name = L["Buff.PowerWordFortitude"],
            class = "PRIEST",
            reach = "raid",
            icons = { spells = { 10938 } },
            chatRequestable = true,
        },
    },
    ---@type PresenceBuff[]
    presence = {
        {
            spellID = {
                10293, -- Devotion Aura
                10292,
                1032,
                10291,
                643,
                10290,
                465,
                10301, -- Retribution Aura
                10300,
                10299,
                10298,
                7294,
                19746, -- Concentration Aura
                19896, -- Shadow Resistance Aura
                19895,
                19876,
                19898, -- Frost Resistance Aura
                19897,
                19888,
                19900, -- Fire Resistance Aura
                19899,
                19891,
                20218, -- Sanctity Aura
            },
            key = "paladinAura",
            name = L["Buff.PaladinAura"],
            class = "PALADIN",
            reach = "party",
            icons = { spells = { 10293 } },
            overlayText = L["Overlay.NoAura"],
        },
    },
    targeted = {},
    ---@type SelfBuff[]
    self = {
        {
            spellID = {
                25296, -- Aspect of the Hawk
                14322,
                14321,
                14320,
                14319,
                14318,
                13165,
                13163, -- Aspect of the Monkey
                20190, -- Aspect of the Wild
                20043,
                1299447, -- Aspect of the Beast
                1299446,
                1299445,
                13161,
                5118, -- Aspect of the Cheetah
                13159, -- Aspect of the Pack
            },
            key = "hunterAspect",
            icons = { spells = { 25296 } },
            name = L["Buff.HunterAspect"],
            class = "HUNTER",
            overlayText = L["Overlay.NoAspect"],
        },
        {
            spellID = {
                10220, -- Ice Armor
                10219,
                7320,
                7302,
                7301, -- Frost Armor
                7300,
                168,
                22783, -- Mage Armor
                22782,
                6117,
            },
            key = "mageArmor",
            icons = { spells = { 10220 } },
            name = L["Buff.MageArmor"],
            class = "MAGE",
            overlayText = L["Overlay.NoArmor"],
        },
        {
            spellID = 25780,
            key = "righteousFury",
            defaultEnabled = false, -- opt-in: only tanks want it
            name = L["Buff.RighteousFury"],
            class = "PALADIN",
            overlayText = L["Overlay.NoRighteousFury"],
        },
        {
            spellID = { 10952, 10951, 1006, 602, 7128, 588 },
            key = "innerFire",
            name = L["Buff.InnerFire"],
            class = "PRIEST",
            overlayText = L["Overlay.NoInnerFire"],
        },
        {
            spellID = 15473,
            key = "shadowform",
            name = L["Buff.Shadowform"],
            class = "PRIEST",
            overlayText = L["Overlay.NoForm"],
        },
        {
            spellID = { 10432, 10431, 8134, 945, 905, 325, 324 },
            key = "lightningShield",
            name = L["Buff.LightningShield"],
            class = "SHAMAN",
            overlayText = L["Overlay.NoShield"],
        },
        {
            spellID = {
                11735, -- Demon Armor
                11734,
                11733,
                1086,
                706,
                696, -- Demon Skin
                687,
            },
            key = "warlockArmor",
            icons = { spells = { 11735 } },
            name = L["Buff.WarlockArmor"],
            class = "WARLOCK",
            overlayText = L["Overlay.NoArmor"],
        },
        {
            spellID = { 9910, 9756, 8914, 1075, 782, 467 },
            key = "thorns",
            defaultEnabled = false, -- opt-in: only tanks want it
            name = L["Buff.Thorns"],
            class = "DRUID",
            overlayText = L["Overlay.NoThorns"],
        },
    },
    pet = {},
    custom = {},
    loadout = {},
    consumable = {},
    utility = {},
}
