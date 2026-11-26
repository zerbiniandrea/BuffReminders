local _, ns = ...
---@class BR
local BR = ns

if BR.CLIENT ~= BR.ClientType.Forever then
    return
end

local L = BR.L

local floor = math.floor
local max = math.max
local AuraByIndex = BR.Secret.AuraByIndex
local AuraField = BR.Secret.AuraField
local Plain = BR.Secret.Plain
local CooldownsRestricted = BR.Restrictions.CooldownsRestricted
local UnitIsUnit = UnitIsUnit

local REPAIR_LABEL = L["Overlay.RepairLabel"]
local REAGENT_LABEL = L["Overlay.ReagentLabel"]
local AMMO_LABEL = L["Overlay.AmmoLabel"]
local REAGENTS_TEXT = L["Overlay.Reagents"]
local AMMO_TEXT = L["Overlay.Ammo"]
local AMMO_EQUIP_TEXT = L["Overlay.EquipAmmo"]

local _, playerClass = UnitClass("player")

-- Forever has no housing, scenarios or arenas, and all its dungeons have one difficulty.
-- The raid map holds the raid difficultyIDs that Forever raids use.
---@type InstanceContent
local INSTANCE_CONTENT = {
    contentTypes = { "openWorld", "dungeon", "raid", "pvp" },
    difficulties = {
        raid = { "raid40", "raid20" },
    },
    difficultyIDs = {
        raid = {
            [9] = "raid40",
            [186] = "raid40",
            [148] = "raid20",
            [185] = "raid20",
            [226] = "raid20",
        },
    },
    titles = {
        dungeon = L["Content.AnyDungeon"],
        pvp = L["Content.Battlegrounds"],
    },
    legacyLoot = false,
    keystones = false,
}

-- One poison column per hand. Each entry is the rank 1 spell of a poison type.
local DEFAULT_POISON_PREFERENCES = {
    mainHand = {
        { spellID = 8679, enabled = true }, -- Instant
        { spellID = 2823, enabled = true }, -- Deadly
        { spellID = 13219, enabled = true }, -- Wound
        { spellID = 3408, enabled = true }, -- Crippling
        { spellID = 5761, enabled = true }, -- Mind-numbing
    },
    offHand = {
        { spellID = 2823, enabled = true }, -- Deadly
        { spellID = 8679, enabled = true }, -- Instant
        { spellID = 13219, enabled = true }, -- Wound
        { spellID = 3408, enabled = true }, -- Crippling
        { spellID = 5761, enabled = true }, -- Mind-numbing
    },
}

---@type PoisonColumn[]
local POISON_COLUMNS = {
    { key = "mainHand", label = L["Options.PoisonMainHand"] },
    { key = "offHand", label = L["Options.PoisonOffHand"] },
}

---@type PetSpells
local PET_SPELLS = {
    callPet = { 883 },
    demonSummons = { 688, 697, 712, 691 }, -- Imp, Voidwalker, Succubus, Felhunter
    demonChoices = { "imp", "voidwalker", "succubus", "felhunter" },
    -- Voidwalker first for solo play. Felhunter is learned at level 30, Imp at level 1.
    demonPreference = { "voidwalker", "felhunter", "imp", "succubus" },
    felDomination = 18708,
}

-- Pet food type (ItemPetFood ID) -> the items of that type. Buff food is in the list, and
-- the feed click skips it. Quest items are absent.
-- stylua: ignore
local PET_FOOD_ITEMS = {
    [1] = {
        117, 723, 724, 729, 733, 769, 1015, 1017, 1080, 1081, 1082, 2287,
        2672, 2673, 2677, 2679, 2680, 2681, 2684, 2685, 2687, 2886, 2888, 2924,
        3173, 3220, 3404, 3662, 3664, 3665, 3666, 3667, 3712, 3726, 3727, 3728,
        3729, 3730, 3731, 3770, 3771, 4457, 4599, 5465, 5467, 5469, 5470, 5471,
        5472, 5473, 5474, 5477, 5478, 5479, 5480, 6888, 6890, 7097, 8952, 11444,
        12037, 12184, 12202, 12203, 12204, 12205, 12206, 12208, 12209, 12210, 12212, 12213,
        12214, 12215, 12216, 12217, 12218, 12224, 13851, 16971, 17119, 17222, 17407, 17408,
        18045, 18633, 18635, 19223, 19224, 19304, 19305, 19306, 19995, 20074, 20424, 20452,
        21023, 21235, 238637, 238638, 238639, 238641, 238642, 250065, 250066, 250067, 250068, 250069,
        250070, 250071, 250072, 250073, 250074, 250075, 250076, 250077, 250078, 250079, 250080, 252022,
        252029, 262433, 263509, 263512, 268913, 274976, 278117, 278118, 278121, 287963, 287973,
    },
    [2] = {
        787, 1326, 2608, 2674, 2675, 2682, 2683, 3663, 4592, 4593, 4594, 4603,
        4655, 5095, 5468, 5476, 5503, 5504, 5525, 5526, 5527, 6038, 6289, 6290,
        6291, 6292, 6294, 6295, 6299, 6303, 6308, 6309, 6310, 6311, 6316, 6317,
        6358, 6359, 6361, 6362, 6363, 6364, 6458, 6522, 6657, 6887, 7974, 8364,
        8365, 8957, 8959, 9681, 12238, 13422, 13546, 13754, 13755, 13756, 13757, 13758,
        13759, 13760, 13842, 13843, 13844, 13845, 13846, 13847, 13848, 13849, 13876, 13877,
        13878, 13879, 13880, 13882, 13883, 13884, 13885, 13886, 13887, 13888, 13889, 13893,
        13901, 13902, 13903, 13904, 13905, 13906, 13907, 13908, 13909, 13910, 13911, 13912,
        13913, 13914, 13915, 13916, 13917, 13927, 13928, 13929, 13930, 13931, 13932, 13933,
        13934, 13935, 16766, 18254, 18255, 19803, 19804, 19805, 19806, 19807, 19996, 21071,
        21072, 21153, 21217, 21238, 21552, 232436, 232438, 250081, 251524, 251525, 268912, 274971,
        286152, 287974,
    },
    [3] = {
        414, 422, 1707, 2070, 3927, 8932, 16167, 17406, 252023, 252030, 278569,
    },
    [4] = {
        1113, 1114, 1487, 4540, 4541, 4542, 4544, 4601, 5349, 8075, 8076, 8950,
        11109, 13724, 16166, 16169, 17344, 18632, 19060, 19061, 19062, 19301, 19696, 20031,
        20062, 20063, 20064, 20222, 20223, 20224, 20225, 20226, 20227, 20388, 20389, 20390,
        21215, 21236, 21254, 21537, 22895, 23160, 23175, 252026, 252028, 260623, 272053, 272054,
        272055, 278119, 287416,
    },
    [5] = {
        4604, 4605, 4606, 4607, 4608, 5569, 8948, 17747, 267474,
    },
    [6] = {
        4536, 4537, 4538, 4539, 4602, 4656, 5057, 8953, 11415, 11584, 11950, 11951,
        11952, 12763, 16168, 16170, 16171, 19994, 20516, 21030, 21031, 21033, 21240, 22324,
        23172, 249796, 251917, 252032, 260624, 260625, 260627, 260628, 278120, 278122,
    },
    [7] = {
        887, 2085, 3181, 3300, 4879, 8427, 252671,
    },
}

---@type table<number, number>
local PET_FOOD_TYPE = {}
for foodType, items in pairs(PET_FOOD_ITEMS) do
    for _, itemID in ipairs(items) do
        PET_FOOD_TYPE[itemID] = foodType
    end
end

-- Creature family -> pet food mask. Bit n - 1 is set if the family eats food type n.
local PET_DIETS = {
    [1] = 1, -- Wolf
    [2] = 3, -- Cat
    [3] = 1, -- Spider
    [4] = 63, -- Bear
    [5] = 63, -- Boar
    [6] = 3, -- Crocolisk
    [7] = 3, -- Carrion Bird
    [8] = 58, -- Crab
    [9] = 48, -- Gorilla
    [11] = 1, -- Raptor
    [12] = 52, -- Tallstrider
    [20] = 1, -- Scorpid
    [21] = 178, -- Turtle
    [24] = 48, -- Bat
    [25] = 33, -- Hyena
    [26] = 1, -- Bird of Prey
    [27] = 14, -- Wind Serpent
    [312] = 1, -- Core Hound
    [319] = 1, -- Fox
}

local FEED_PET = 6991

---@param diet number? Pet food mask, nil when the family is unknown
---@param foodType number
---@return boolean
local function PetEats(diet, foodType)
    return diet == nil or floor(diet / 2 ^ (foodType - 1)) % 2 == 1
end

---Bag food that the pet eats, highest item level first. Food closer to the pet level
---gives more happiness.
---@return number? itemID
local function FindPetFood()
    local _, familyID = UnitCreatureFamily("pet")
    familyID = Plain(familyID)
    local diet = type(familyID) == "number" and PET_DIETS[familyID] or nil
    local buffFood = BR.ConsumableData.items.food
    local bestID, bestLevel = nil, -1
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            local foodType = itemID and PET_FOOD_TYPE[itemID]
            if foodType and not buffFood[itemID] and PetEats(diet, foodType) then
                local level = select(4, C_Item.GetItemInfo(itemID)) or 0
                if level > bestLevel then
                    bestID, bestLevel = itemID, level
                end
            end
        end
    end
    return bestID
end

---If the Feed Pet cast fails, a /use line makes the hunter eat the food. So the macro
---names food only when Feed Pet and the global cooldown are ready.
---@return string
local function FeedPetMacro()
    local name = BR.GetSpellName(FEED_PET)
    if not name then
        return ""
    end
    local macro = "/cast " .. name
    -- C_Spell.GetSpellCooldown returns secret values when cooldowns are restricted.
    if BR.Restrictions.CooldownsRestricted() then
        return macro
    end
    local info = C_Spell.GetSpellCooldown(FEED_PET)
    local startTime = info and Plain(info.startTime)
    if startTime ~= 0 then
        return macro
    end
    local food = FindPetFood()
    return food and (macro .. "\n/use item:" .. food) or macro
end

---@type SelfBuff
local PET_HAPPINESS = {
    key = "petHappiness",
    name = L["Buff.PetHappiness"],
    class = "HUNTER",
    overlayText = L["Overlay.FeedPet"],
    icons = { textures = { 132165 } }, -- Feed Pet
    defaultEnabled = false, -- opt-in: a content pet still fights at full damage
    requiresSpellID = FEED_PET,
    castSpellID = FEED_PET,
    customCheck = function()
        local happiness = BR.BuffState.GetPetHappiness()
        return happiness ~= nil and happiness < 3 and not UnitIsDead("pet") or nil
    end,
    clickMacro = FeedPetMacro,
}

-- Demonic Sacrifice and its buffs: Burning Shadow, Fel Stamina, Touch of Fire, Fel Energy.
---@type PetSacrifice
local DEMONIC_SACRIFICE =
    { spellID = 18788, auraIDs = { 18789, 18790, 18791, 18792 }, reminderKey = "demonicSacrifice" }
-- Sacrifice buff -> summon spell of the sacrificed demon.
local SACRIFICED_DEMON = { [18789] = 688, [18790] = 691, [18791] = 712, [18792] = 697 }
-- Soul Link needs a live demon, so without Demonic Pact it excludes the sacrifice.
-- Demonic Pact keeps the sacrifice buff through the summon of a different demon.
local SOUL_LINK = 19028
local SOUL_LINK_AURA = 25228
local DEMONIC_PACT = 425464
-- Summon spells of the demons that Soul Link accepts: Imp, Voidwalker, Felhunter, Succubus.
local SOUL_LINK_DEMONS = { 688, 697, 691, 712 }

---@param familyID number
---@return boolean
local function IsSoulLinkFamily(familyID)
    local families = BR.PetHelpers.WARLOCK_DEMON_FAMILIES
    for _, summonID in ipairs(SOUL_LINK_DEMONS) do
        if families[summonID][familyID] then
            return true
        end
    end
    return false
end

---Summon spell of the sacrificed demon, nil without a sacrifice buff.
---@return number?
local function SacrificedDemon()
    for auraID, summonID in pairs(SACRIFICED_DEMON) do
        if C_UnitAuras.GetPlayerAuraBySpellID(auraID) then
            return summonID
        end
    end
    return nil
end

---@return boolean
local function KnowsDemonicPact()
    local IsKnown = BR.StateHelpers.IsPlayerSpellCached
    return IsKnown(SOUL_LINK) and IsKnown(DEMONIC_PACT)
end

---@alias DemonSetupStep "sacrifice"|"summon"|"link"

---Next step of the sacrifice and Soul Link setup, nil when the setup is complete or does not apply.
---@return DemonSetupStep?
local function DemonSetupStep()
    local link = BR.StateHelpers.IsPlayerSpellCached(SOUL_LINK)
    local pact = link and KnowsDemonicPact()
    local sacrificed = SacrificedDemon()
    if not sacrificed and (pact or not link) then
        return "sacrifice"
    end
    if not link then
        return nil
    end
    local familyID = BR.BuffState.GetPetFamily()
    if familyID == nil then
        return nil
    end
    if familyID == false or UnitIsDead("pet") then
        -- Without Demonic Pact, the missing-demon reminder covers this state.
        return pact and "summon" or nil
    end
    if IsSoulLinkFamily(familyID) and not C_UnitAuras.GetPlayerAuraBySpellID(SOUL_LINK_AURA) then
        return "link"
    end
    return nil
end

---Row of a talent group grid for the active talent group.
---@return string
local function TalentGroupRow()
    return "spec" .. BR.StateHelpers.GetPlayerSpecGroup()
end

---Known demon of the first choice that a grid allows in a row.
---@param setting string Key of the grid in profile.defaults
---@param row string
---@param skipSpellID number?
---@return PetAction?
local function GridDemonAction(setting, row, skipSpellID)
    local actions = BR.PetHelpers.GetPetActions("WARLOCK")
    if not actions then
        return nil
    end
    for _, demon in ipairs(BR.PetHelpers.WARLOCK_DEMON_CHOICES) do
        if demon.spellID ~= skipSpellID and BR.Visibility.IsContentChoiceAllowed(setting, row, demon.key) then
            for _, action in ipairs(actions) do
                if action.spellID == demon.spellID then
                    return action
                end
            end
        end
    end
    return nil
end

---First known demon other than the given one.
---@param skipSpellID number?
---@return PetAction?
local function OtherDemonAction(skipSpellID)
    for _, action in ipairs(BR.PetHelpers.GetPetActions("WARLOCK") or {}) do
        if action.spellID ~= skipSpellID then
            return action
        end
    end
    return nil
end

---Demon to summon after a Demonic Pact sacrifice. A summon of the sacrificed demon cancels the buff.
---@return PetAction?
local function PactSummonAction()
    local sacrificed = SacrificedDemon()
    local desired = BR.PetHelpers.GetDesiredWarlockDemon()
    if desired and desired.spellID ~= sacrificed then
        return desired
    end
    return GridDemonAction("warlockDemons", BR.Visibility.GetContentRow(), sacrificed) or OtherDemonAction(sacrificed)
end

---Demon that the sacrifice click summons when no demon is out and the talent group picks none.
---@return PetAction?
local function FallbackSacrificeDemon()
    local actions = BR.PetHelpers.GetPetActions("WARLOCK")
    local desired = BR.PetHelpers.GetDesiredWarlockDemon() or (actions and actions[1])
    -- With Demonic Pact, the preferred demon is the one that stays out after the sacrifice.
    if desired and KnowsDemonicPact() then
        return OtherDemonAction(desired.spellID) or desired
    end
    return desired
end

local DEMON_SETUP_TEXT = {
    sacrifice = L["Overlay.NoSacrifice"],
    summon = L["Overlay.NoPet"],
    link = L["Overlay.NoLink"],
}

-- IsSpellKnown answers true only for the highest rank, so each list holds every rank.
local CREATE_HEALTHSTONE = { 11730, 11729, 5699, 6202, 6201 }
local CREATE_SOULSTONE = { 20757, 20756, 20755, 20752, 693 }
local SOULSTONE_ITEMS = { 16896, 16895, 16893, 16892, 5232 } -- Major to Minor
local CONJURE_MANA_GEM = { 10054, 10053, 3552, 759 } -- Ruby, Citrine, Jade, Agate
local SKYBORNE_RACIALS = { 1259705, 1259686 } -- Read Leyline (High Order), Skysight (Windshaper)

-- Shaman weapon imbues per setting value, highest rank first.
local SHAMAN_IMBUE_RANKS = {
    windfury = { 16362, 10486, 8235, 8232 },
    flametongue = { 16342, 16341, 16339, 8030, 8027, 8024 },
    rockbiter = { 16316, 16315, 16314, 10399, 8019, 8018, 8017 },
    frostbrand = { 16356, 16355, 10456, 8038, 8033 },
}
-- Frostbrand is cast only when the player picks it.
local SHAMAN_IMBUE_FALLBACK = { "windfury", "flametongue", "rockbiter" }
-- Each rank applies its own temporary enchant. 7566-7569 come from the rank
-- variants 461633-461636, which the addon detects but never casts.
local SHAMAN_IMBUE_ENCHANTS = {}
for _, enchantIDs in ipairs({
    { 29, 6, 1, 503, 1663, 683, 1664 }, -- Rockbiter Weapon
    { 5, 4, 3, 523, 1665, 1666 }, -- Flametongue Weapon
    { 2, 12, 524, 1667, 1668 }, -- Frostbrand Weapon
    { 283, 284, 525, 1669 }, -- Windfury Weapon
    { 7566, 7567, 7568, 7569 },
}) do
    for _, id in ipairs(enchantIDs) do
        SHAMAN_IMBUE_ENCHANTS[id] = true
    end
end
local SHAMAN_IMBUES = {}
for _, key in ipairs({ "rockbiter", "flametongue", "frostbrand", "windfury" }) do
    for _, id in ipairs(SHAMAN_IMBUE_RANKS[key]) do
        SHAMAN_IMBUES[#SHAMAN_IMBUES + 1] = id
    end
end
---@class WarlockStone
---@field key string Choice key in the warlockStones grid
---@field create number[] Create spells, highest rank first
---@field items number[] Stone items, highest rank first
---@field enchants table<number, true>
---@field icon number

-- A stone takes the imbue slot, so it stacks with a weapon oil.
---@type WarlockStone[]
local WARLOCK_STONES = {
    {
        key = "spellstone",
        create = { 17728, 17727, 2362 },
        items = { 13603, 13602, 5522 },
        enchants = { [8061] = true, [8060] = true, [8059] = true },
        icon = 134131,
    },
    {
        key = "firestone",
        create = { 17953, 17952, 17951, 6366 },
        items = { 13701, 13700, 13699, 1254 },
        enchants = { [1825] = true, [1824] = true, [1823] = true, [1803] = true },
        icon = 134085,
    },
}
local WARLOCK_STONE_CREATE = {}
local WARLOCK_STONE_ENCHANTS = {}
for _, stone in ipairs(WARLOCK_STONES) do
    for _, id in ipairs(stone.create) do
        WARLOCK_STONE_CREATE[#WARLOCK_STONE_CREATE + 1] = id
    end
    for id in pairs(stone.enchants) do
        WARLOCK_STONE_ENCHANTS[id] = true
    end
end

---@param spellIDs number[] Highest rank first
---@return number?
local function HighestKnownSpell(spellIDs)
    for _, id in ipairs(spellIDs) do
        if BR.StateHelpers.IsPlayerSpellCached(id) then
            return id
        end
    end
    return nil
end

local SKYBORNE_AURAS = { 1259691, 1270893 } -- Attuned, Charged

---The expiration warning shows the aura that expires, not the racial that the missing state shows.
---@return number? remaining
---@return number? auraID
---@return number? duration
local function SkyborneAuraExpiration()
    for _, id in ipairs(SKYBORNE_AURAS) do
        local aura = C_UnitAuras.GetUnitAuraBySpellID("player", id)
        if aura then
            local exp = AuraField(aura, "expirationTime")
            if not exp or exp <= 0 then
                return nil
            end
            return exp - GetTime(), id, AuraField(aura, "duration")
        end
    end
    return nil
end

-- The macro names the highest spell that the player knows.
---@param spellIDs number[] Highest rank first
---@return string
local function CastHighestKnownMacro(spellIDs)
    local id = HighestKnownSpell(spellIDs)
    return id and ("/cast " .. (BR.GetSpellName(id) or "")) or ""
end

---@return number? itemID
local function SoulstoneInBags()
    for _, id in ipairs(SOULSTONE_ITEMS) do
        if C_Item.GetItemCount(id) > 0 then
            return id
        end
    end
    return nil
end

-- All Soulstone ranks share one cooldown. A stone outside the bags still reports it.
---@return boolean
local function SoulstoneReady()
    for _, id in ipairs(SOULSTONE_ITEMS) do
        local _, duration = C_Item.GetItemCooldown(id)
        duration = Plain(duration)
        if duration and duration > 0 then
            return false
        end
    end
    return true
end

-- The sacrifice needs a demon out. If the talent group picks a demon and another one is out,
-- the click summons the picked demon first.
---@param spellID number?
---@return string
local function DemonicSacrificeMacro(spellID)
    local sacrifice = BR.GetSpellName(spellID or DEMONIC_SACRIFICE.spellID) or ""
    local picked = GridDemonAction("warlockSacrificeDemons", TalentGroupRow())
    if picked then
        local familyID = BR.BuffState.GetPetFamily()
        if familyID == nil then
            return "/cast [nopet] " .. picked.spellName .. "; " .. sacrifice
        end
        local families = BR.PetHelpers.WARLOCK_DEMON_FAMILIES[picked.spellID]
        if familyID and families[familyID] and not UnitIsDead("pet") then
            return "/cast " .. sacrifice
        end
        return "/cast " .. picked.spellName
    end
    local demon = FallbackSacrificeDemon()
    if not demon then
        return "/cast " .. sacrifice
    end
    return "/cast [nopet] " .. demon.spellName .. "; " .. sacrifice
end

---@param spellID number?
---@return string
local function DemonSetupMacro(spellID)
    local step = DemonSetupStep()
    if step == "link" then
        return "/cast " .. (BR.GetSpellName(SOUL_LINK) or "")
    end
    if step == "summon" then
        local demon = PactSummonAction()
        return demon and ("/cast " .. demon.spellName) or ""
    end
    return DemonicSacrificeMacro(spellID)
end

---Highest known rank of the preferred imbue, else of the first known fallback imbue.
---@return number?
local function ShamanImbueCastID()
    local defaults = BR.profile.defaults
    local ranks = SHAMAN_IMBUE_RANKS[defaults and defaults.shamanImbue or "windfury"]
    local id = ranks and HighestKnownSpell(ranks)
    if id then
        return id
    end
    for _, key in ipairs(SHAMAN_IMBUE_FALLBACK) do
        id = HighestKnownSpell(SHAMAN_IMBUE_RANKS[key])
        if id then
            return id
        end
    end
    return nil
end

-- A poison sits in the imbue slot of a weapon, beside an oil in the temporary slot.
-- Poison items per type, highest rank first. The rank 1 spell names the type.
local POISON_ITEMS = {
    [8679] = { 8928, 8927, 8926, 6950, 6949, 6947 }, -- Instant Poison
    [2823] = { 20844, 8985, 8984, 2893, 2892 }, -- Deadly Poison
    [13219] = { 10922, 10921, 10920, 10918 }, -- Wound Poison
    [3408] = { 3776, 3775 }, -- Crippling Poison
    [5761] = { 9186, 6951, 5237 }, -- Mind-numbing Poison
}
local POISONS_SKILL = 2842
local POISON_HANDS = { { slot = 16, column = "mainHand" }, { slot = 17, column = "offHand" } }

---@param slot number 16 (main hand) or 17 (off hand)
---@return boolean
local function HandHoldsWeapon(slot)
    if slot == 17 then
        return BR.BuffState.HasOffHandWeapon()
    end
    local subclass = BR.BuffState.GetWeaponSubclass(16)
    return subclass ~= nil and subclass ~= 20 -- Enum.ItemWeaponSubclass.Fishingpole
end

---@param column string
---@return { spellID: number, enabled: boolean }[]
local function PoisonList(column)
    local prefs = BR.profile.roguePoisonPreferences
    local list = prefs and prefs[column]
    if not list or #list == 0 then
        list = DEFAULT_POISON_PREFERENCES[column]
    end
    return list
end

---First enabled poison of the hand that the bags hold, as its highest rank item.
---@param column string
---@return number? itemID
---@return number? spellID rank 1 spell of the poison type
local function PickPoison(column)
    local GetItemCountCached = BR.StateHelpers.GetItemCountCached
    for _, entry in ipairs(PoisonList(column)) do
        local items = entry.enabled and POISON_ITEMS[entry.spellID]
        if items then
            for _, itemID in ipairs(items) do
                if GetItemCountCached(itemID) > 0 then
                    return itemID, entry.spellID
                end
            end
        end
    end
    return nil
end

---@param column string
---@return boolean
local function HasEnabledPoison(column)
    for _, entry in ipairs(PoisonList(column)) do
        if entry.enabled and POISON_ITEMS[entry.spellID] then
            return true
        end
    end
    return false
end

---First hand with a weapon, no imbue, and an enabled poison.
---@return { slot: number, column: string }?
local function HandMissingPoison()
    for _, hand in ipairs(POISON_HANDS) do
        if
            HandHoldsWeapon(hand.slot)
            and not BR.BuffState.GetWeaponImbue(hand.slot)
            and HasEnabledPoison(hand.column)
        then
            return hand
        end
    end
    return nil
end

---@return number? remaining seconds on the poison that expires first
local function PoisonRemaining()
    local soonest
    for _, hand in ipairs(POISON_HANDS) do
        if HandHoldsWeapon(hand.slot) then
            local id, remaining = BR.BuffState.GetWeaponImbue(hand.slot)
            if id and remaining and (not soonest or remaining < soonest) then
                soonest = remaining
            end
        end
    end
    return soonest
end

---Applies a poison to the first hand that misses one, else to the hand whose poison expires first.
---@return string
local function PoisonMacro()
    local hand = HandMissingPoison()
    if not hand then
        local soonest
        for _, h in ipairs(POISON_HANDS) do
            local id, remaining = BR.BuffState.GetWeaponImbue(h.slot)
            if HandHoldsWeapon(h.slot) and id and remaining and (not soonest or remaining < soonest) then
                hand, soonest = h, remaining
            end
        end
    end
    if not hand then
        return ""
    end
    local itemID = PickPoison(hand.column)
    return itemID and ("/use item:" .. itemID .. "\n/use " .. hand.slot) or ""
end

---The known stone that the active talent group picks, or nil when either stone counts.
---@return WarlockStone?
local function PickedStone()
    local row = TalentGroupRow()
    for _, stone in ipairs(WARLOCK_STONES) do
        if BR.Visibility.IsContentChoiceAllowed("warlockStones", row, stone.key) then
            return HighestKnownSpell(stone.create) and stone or nil
        end
    end
    return nil
end

---@param stone WarlockStone
---@return number? itemID
local function StoneInBags(stone)
    local GetItemCountCached = BR.StateHelpers.GetItemCountCached
    for _, itemID in ipairs(stone.items) do
        if GetItemCountCached(itemID) > 0 then
            return itemID
        end
    end
    return nil
end

---The stone of the click: the picked stone, else a stone in the bags, else the first known stone.
---@return WarlockStone stone
---@return number? itemID nil when the click creates the stone
local function ClickStone()
    local picked = PickedStone()
    if picked then
        return picked, StoneInBags(picked)
    end
    for _, stone in ipairs(WARLOCK_STONES) do
        local itemID = StoneInBags(stone)
        if itemID then
            return stone, itemID
        end
    end
    for _, stone in ipairs(WARLOCK_STONES) do
        if HighestKnownSpell(stone.create) then
            return stone
        end
    end
    return WARLOCK_STONES[1]
end

---@return string
local function WarlockStoneMacro()
    local stone, itemID = ClickStone()
    if itemID then
        return "/use item:" .. itemID .. "\n/use 16"
    end
    return CastHighestKnownMacro(stone.create)
end

local NO_STANCE = BR.NO_STANCE

---@type StanceGrid
local WARRIOR_STANCE_GRID = {
    setting = "warriorStances",
    hint = L["BuffPanel.WarriorStance.Hint"],
    choices = {
        { key = "battle", spellIDs = { 2457 } },
        { key = "defensive", spellIDs = { 71 } },
        { key = "berserker", spellIDs = { 2458 } },
    },
}

-- Bear Form and Dire Bear Form are one choice, so either known spell counts.
---@type StanceGrid
local DRUID_FORM_GRID = {
    setting = "druidForms",
    hint = L["BuffPanel.DruidForm.Hint"],
    choices = {
        { key = "bear", spellIDs = { 9634, 5487 } },
        { key = "cat", spellIDs = { 768 } },
        { key = "moonkin", spellIDs = { 24858 } },
        { key = "caster", spellIDs = {}, label = L["BuffPanel.DruidForm.Caster"], iconSpellID = 5185 },
    },
}

---Highest known spell of a choice, NO_STANCE for the caster choice, or nil if unknown.
---@param choice StanceChoice
---@return number?
local function KnownChoiceSpell(choice)
    if #choice.spellIDs == 0 then
        return NO_STANCE
    end
    return HighestKnownSpell(choice.spellIDs)
end

---A choice counts only if the current content row allows it and the player knows it.
---@param grid StanceGrid
---@return StanceRule
local function GridStanceRule(grid)
    local allowedSet = {}
    return {
        grid = grid,
        -- The set is reused, so a caller must read it before the next call.
        allowed = function()
            wipe(allowedSet)
            local row = BR.Visibility.GetContentRow()
            local any = false
            for _, choice in ipairs(grid.choices) do
                local known = KnownChoiceSpell(choice)
                if known and BR.Visibility.IsContentChoiceAllowed(grid.setting, row, choice.key) then
                    any = true
                    allowedSet[known] = true
                    for _, id in ipairs(choice.spellIDs) do
                        allowedSet[id] = true
                    end
                end
            end
            return any and allowedSet or nil
        end,
        castID = function()
            local row = BR.Visibility.GetContentRow()
            for _, choice in ipairs(grid.choices) do
                local known = KnownChoiceSpell(choice)
                if known and BR.Visibility.IsContentChoiceAllowed(grid.setting, row, choice.key) then
                    return known
                end
            end
            return nil
        end,
    }
end

---@type table<string, StanceRule>
local STANCE_RULES = {
    WARRIOR = GridStanceRule(WARRIOR_STANCE_GRID),
    DRUID = GridStanceRule(DRUID_FORM_GRID),
}

---@param castID number? Stance spell, or NO_STANCE to cancel the current form
---@return string
local function StanceMacro(castID)
    if castID == NO_STANCE then
        return "/cancelform"
    end
    return castID and ("/cast " .. (BR.GetSpellName(castID) or "")) or ""
end

---@return boolean
local function RighteousFuryWanted()
    local defaults = BR.profile.defaults
    return (defaults ~= nil and defaults.righteousFuryShow == "always") or BR.StateHelpers.IsPlayerTank()
end

-- Ice Armor is the higher rank line of Frost Armor, so both are one choice. Highest rank first.
local ICE_ARMOR_IDS = { 10220, 10219, 7320, 7302, 7301, 7300, 168 }
local MAGE_ARMOR_IDS = { 22783, 22782, 6117 }
local ALL_MAGE_ARMOR_IDS = {}
for _, list in ipairs({ ICE_ARMOR_IDS, MAGE_ARMOR_IDS }) do
    for _, id in ipairs(list) do
        ALL_MAGE_ARMOR_IDS[#ALL_MAGE_ARMOR_IDS + 1] = id
    end
end

---Highest known rank of the preferred armor, else of the other armor.
---@return number?
local function PreferredMageArmor()
    local defaults = BR.profile.defaults
    local preferIce = defaults ~= nil and defaults.mageArmorPreference == "ice"
    local first, second = MAGE_ARMOR_IDS, ICE_ARMOR_IDS
    if preferIce then
        first, second = ICE_ARMOR_IDS, MAGE_ARMOR_IDS
    end
    return HighestKnownSpell(first) or HighestKnownSpell(second)
end

-- State remembers the tank that a role buff goes on. With no tank, the buff goes on the player.
---@param buffKey string
---@return fun(spellID: number?): string
local function TankOrSelfMacro(buffKey)
    return function(spellID)
        local name = BR.GetSpellName(spellID) or ""
        local tank = BR.TargetMemory.Get(buffKey)
        if tank then
            return "/cast [@" .. tank .. ",help,nodead] " .. name
        end
        return "/cast [@player] " .. name
    end
end

local SYMBOL_OF_KINGS = 21177

---@class RankSpec
---@field key string
---@field ranks number[][] Single-target ranks, highest first: spell ID, SpellLevel, base points of the first effect
---@field groupCast? GroupCastRank[] Highest rank first
---@field blockers? number[] Scroll auras. Each camp feature adds the aura of its buff

---@class RankedBuff : StanceChoice, RankSpec
---@field blockers number[] The auras exclude each other, so the first one found decides

-- A rank lands only on a target whose level is at least the rank level minus this span.
local RANK_LEVEL_SPAN = 10
---@type table<number, number> Single-target rank -> SpellLevel
local RANK_LEVELS = {}
---@type table<number, number> Single-target rank -> base points of the first effect
local RANK_POINTS = {}
-- Every single-target rank, in the order of the definitions.
local SINGLE_TARGET_RANKS = {}

---A cast that is not stronger than an aura of the same stat on the target fails:
---"A more powerful spell is already active". The rank is the one that the unit level
---accepts, else the highest rank. An aura with unreadable points blocks.
---@param buff RankedBuff
---@return fun(unit: string): boolean
local function CastBlockedBy(buff)
    return function(unit)
        for _, id in ipairs(buff.blockers) do
            local aura = C_UnitAuras.GetUnitAuraBySpellID(unit, id)
            if aura then
                local points = BR.Secret.AuraField(aura, "points")
                local held = points and BR.Secret.Plain(points[1])
                if not held then
                    return true
                end
                local castID = BR.Ranks.Fit(buff.spellIDs, BR.Secret.Plain(UnitLevel(unit)) or -1)
                return held >= (RANK_POINTS[castID or buff.spellIDs[1]] or 0)
            end
        end
        return false
    end
end

---@param spec RankSpec
---@return RankedBuff
local function Ranked(spec)
    ---@cast spec RankedBuff
    local spellIDs, auraIDs = {}, {}
    for _, rank in ipairs(spec.ranks) do
        local id = rank[1]
        spellIDs[#spellIDs + 1] = id
        auraIDs[#auraIDs + 1] = id
        SINGLE_TARGET_RANKS[#SINGLE_TARGET_RANKS + 1] = id
        RANK_LEVELS[id] = rank[2]
        RANK_POINTS[id] = rank[3]
    end
    for _, rank in ipairs(spec.groupCast or {}) do
        auraIDs[#auraIDs + 1] = rank.spellID
    end
    spec.spellIDs = spellIDs
    spec.auraIDs = auraIDs
    spec.blockers = spec.blockers or {}
    spec.castBlocked = CastBlockedBy(spec)
    return spec
end

-- Single-target rank data from the SpellLevels and SpellEffect DB2 tables.
local ARCANE_INTELLECT = Ranked({
    key = "intellect",
    ranks = { { 10157, 56, 31 }, { 10156, 42, 22 }, { 1461, 28, 15 }, { 1460, 14, 7 }, { 1459, 1, 2 } },
    groupCast = { { spellID = 23028, reagent = 17020 } },
    blockers = { 12176, 8098, 8097, 8096 }, -- Scroll of Intellect IV to I
})
local MARK_OF_THE_WILD = Ranked({
    key = "versatility",
    ranks = {
        { 9885, 60, 385 },
        { 9884, 50, 324 },
        { 8907, 40, 263 },
        { 5234, 30, 203 },
        { 6756, 20, 142 },
        { 5232, 10, 88 },
        { 1126, 1, 34 },
    },
    groupCast = { { spellID = 21850, reagent = 17026 }, { spellID = 21849, reagent = 17021 } },
})
local POWER_WORD_FORTITUDE = Ranked({
    key = "stamina",
    ranks = {
        { 10938, 60, 70 },
        { 10937, 48, 56 },
        { 2791, 36, 42 },
        { 1245, 24, 26 },
        { 1244, 12, 10 },
        { 1243, 1, 4 },
    },
    groupCast = { { spellID = 21564, reagent = 17029 }, { spellID = 21562, reagent = 17028 } },
    blockers = { 12178, 8101, 8100, 8099 }, -- Scroll of Stamina IV to I
})
local DIVINE_SPIRIT = Ranked({
    key = "spirit",
    ranks = { { 27841, 60, 40 }, { 14819, 50, 33 }, { 14818, 40, 23 }, { 14752, 30, 17 } },
    groupCast = { { spellID = 27681, reagent = 17029 } },
    blockers = { 12177, 8114, 8113, 8112 }, -- Scroll of Spirit IV to I
})

-- A player keeps one blessing from each paladin, and the same blessing from two
-- paladins does not stack. A Greater Blessing reaches every group member of the
-- target's class.
---@type RankedBuff[]
local PALADIN_BLESSINGS = {
    Ranked({
        key = "might",
        ranks = {
            { 25291, 60, 133 },
            { 19838, 52, 112 },
            { 19837, 42, 83 },
            { 19836, 32, 61 },
            { 19835, 22, 40 },
            { 19834, 12, 25 },
            { 19740, 4, 14 },
        },
        groupCast = {
            { spellID = 25916, reagent = SYMBOL_OF_KINGS },
            { spellID = 25782, reagent = SYMBOL_OF_KINGS },
        },
    }),
    Ranked({
        key = "wisdom",
        ranks = {
            { 25290, 60, 40 },
            { 19854, 54, 36 },
            { 19853, 44, 30 },
            { 19852, 34, 24 },
            { 19850, 24, 18 },
            { 19742, 14, 12 },
        },
        groupCast = {
            { spellID = 25918, reagent = SYMBOL_OF_KINGS },
            { spellID = 25894, reagent = SYMBOL_OF_KINGS },
        },
    }),
    Ranked({
        key = "kings",
        ranks = { { 20217, 20, 10 } },
        groupCast = { { spellID = 25898, reagent = SYMBOL_OF_KINGS } },
    }),
}

---@class SpellRankData
---@field levelSpan number
---@field levels table<number, number> Single-target rank -> SpellLevel

-- Only code of this client reads this export, so retail has no mirror.
---@type SpellRankData
BR.SPELL_RANKS = { levelSpan = RANK_LEVEL_SPAN, levels = RANK_LEVELS }

-- Every rank of a blessing covers the member, whoever cast it. The stored click
-- action is the first known ID in spellID, so the single-target ranks come first.
local ALL_BLESSING_IDS = {}
---@type table<string, RankedBuff>
local BLESSING_BY_KEY = {}
---@type table<number, RankedBuff> Every aura ID of a blessing -> the blessing
local BLESSING_BY_SPELL = {}
for _, choice in ipairs(PALADIN_BLESSINGS) do
    for _, id in ipairs(choice.spellIDs) do
        ALL_BLESSING_IDS[#ALL_BLESSING_IDS + 1] = id
    end
    BLESSING_BY_KEY[choice.key] = choice
    for _, id in ipairs(choice.auraIDs) do
        BLESSING_BY_SPELL[id] = choice
    end
end
for _, choice in ipairs(PALADIN_BLESSINGS) do
    for _, rank in ipairs(choice.groupCast) do
        ALL_BLESSING_IDS[#ALL_BLESSING_IDS + 1] = rank.spellID
    end
end

---@type table<string, StanceChoice[]>
local knownBlessingsByClass = {}

---The blessings of the class list that the player knows, in priority order.
---The list is reused, so a caller must read it before the next call for the class.
---@param class string
---@return StanceChoice[]
local function KnownBlessingsForClass(class)
    local list = knownBlessingsByClass[class]
    if list then
        wipe(list)
    else
        list = {}
        knownBlessingsByClass[class] = list
    end
    local defaults = BR.profile.defaults
    local byClass = defaults and defaults.paladinBlessingsByClass
    local order = type(byClass) == "table" and byClass[class]
    if type(order) ~= "table" then
        return list
    end
    for i = 1, #PALADIN_BLESSINGS do
        local choice = BLESSING_BY_KEY[order[i]]
        if choice and HighestKnownSpell(choice.spellIDs) then
            local listed = false
            for j = 1, #list do
                listed = listed or list[j] == choice
            end
            if not listed then
                list[#list + 1] = choice
            end
        end
    end
    return list
end

---@type ClassChoiceGrid
local PALADIN_BLESSING_GRID = {
    setting = "paladinBlessingsByClass",
    choices = PALADIN_BLESSINGS,
    rows = { "WARRIOR", "ROGUE", "HUNTER", "MAGE", "WARLOCK", "PRIEST", "DRUID", "SHAMAN", "PALADIN" },
    slots = 3,
    clusterEnds = { ROGUE = true, HUNTER = true },
    forClass = KnownBlessingsForClass,
    castID = function(choice)
        return HighestKnownSpell(choice.spellIDs)
    end,
}

---@param order any
---@return StanceChoice?
local function FirstBlessing(order)
    if type(order) ~= "table" then
        return nil
    end
    for i = 1, #PALADIN_BLESSINGS do
        local choice = order[i] and BLESSING_BY_KEY[order[i]]
        if choice then
            return choice
        end
    end
    return nil
end

---The blessing that the player asks for: the first one of the class list in the
---options grid. A missing list uses the default list. An empty list asks for none.
---@return number? spellID
local function RequestedBlessing()
    local defaults = BR.profile.defaults
    local byClass = defaults and defaults.paladinBlessingsByClass
    local order = type(byClass) == "table" and byClass[playerClass]
    if order == nil or order == false then
        order = BR.defaults.defaults.paladinBlessingsByClass[playerClass]
    end
    local choice = FirstBlessing(order)
    return choice and choice.spellIDs[1]
end

-- A unit keeps one aura of each type, whoever casts it. A resistance aura reaches the
-- whole raid. The other auras reach only the party.
---@type ChoiceOrderGrid
local PALADIN_AURA_GRID = {
    setting = "paladinAuraOrder",
    choices = {
        { key = "devotion", spellIDs = { 10293, 10292, 1032, 10291, 643, 10290, 465 } },
        { key = "retribution", spellIDs = { 10301, 10300, 10299, 10298, 7294 } },
        { key = "concentration", spellIDs = { 19746 } },
        { key = "shadowResistance", spellIDs = { 19896, 19895, 19876 }, resistance = true },
        { key = "frostResistance", spellIDs = { 19898, 19897, 19888 }, resistance = true },
        { key = "fireResistance", spellIDs = { 19900, 19899, 19891 }, resistance = true },
        { key = "sanctity", spellIDs = { 20218 } },
    },
    rows = { "world", "dungeon", "raid", "pvp" },
    slots = 2,
    castID = function(choice)
        return HighestKnownSpell(choice.spellIDs)
    end,
}
local PALADIN_AURA_CHOICES = PALADIN_AURA_GRID.choices
---@type table<number, integer>
local PALADIN_AURA_TYPE = {}
---@type table<string, integer>
local PALADIN_AURA_TYPE_BY_KEY = {}
local ALL_PALADIN_AURA_IDS = {}
for auraType, choice in ipairs(PALADIN_AURA_CHOICES) do
    PALADIN_AURA_TYPE_BY_KEY[choice.key] = auraType
    for _, id in ipairs(choice.spellIDs) do
        PALADIN_AURA_TYPE[id] = auraType
        ALL_PALADIN_AURA_IDS[#ALL_PALADIN_AURA_IDS + 1] = id
    end
end

local UnitGUID = UnitGUID
local IsInRaid = IsInRaid
local IsGUIDInGroup = IsGUIDInGroup
local UnitTokenFromGUID = UnitTokenFromGUID
local UnitInSubgroup = UnitInSubgroup

-- The scan reads auras only out of combat. An entry stays while its paladin is out
-- of range or the player is in combat, so a taken aura does not flip back and forth.
---@type table<string, integer> GUID of another paladin -> the aura type that the paladin gives the player
local otherPaladinAuras = {}

---Forget each paladin who left the group. In a raid, a party aura reaches only the
---subgroup of its caster.
local function PruneOtherPaladinAuras()
    local inRaid = IsInRaid()
    for guid, auraType in pairs(otherPaladinAuras) do
        local keep = Plain(IsGUIDInGroup(guid)) ~= false
        if keep and inRaid and not PALADIN_AURA_CHOICES[auraType].resistance then
            local unit = Plain(UnitTokenFromGUID(guid))
            keep = not unit or Plain(UnitInSubgroup(unit)) ~= false
        end
        if not keep then
            otherPaladinAuras[guid] = nil
        end
    end
end

---@param auraType integer
---@return boolean
local function IsAuraTypeTaken(auraType)
    for _, other in pairs(otherPaladinAuras) do
        if other == auraType then
            return true
        end
    end
    return false
end

---The aura that the player runs: the first choice of the content row list that the
---player knows and that no other paladin gives. nil when no choice qualifies.
---@return integer? auraType
---@return number? castID
local function WantedPaladinAura()
    local defaults = BR.profile.defaults
    local byRow = defaults and defaults.paladinAuraOrder
    local order = type(byRow) == "table" and byRow[BR.Visibility.GetContentRow()]
    if type(order) ~= "table" then
        return nil
    end
    for i = 1, PALADIN_AURA_GRID.slots do
        local auraType = PALADIN_AURA_TYPE_BY_KEY[order[i]]
        local castID = auraType and HighestKnownSpell(PALADIN_AURA_CHOICES[auraType].spellIDs)
        if castID and not IsAuraTypeTaken(auraType) then
            return auraType, castID
        end
    end
    return nil
end

local NO_AURA_TEXT = L["Overlay.NoAura"]
local WRONG_AURA_TEXT = L["Overlay.WrongAura"]
local DUPLICATE_TEXT = L["Overlay.Duplicate"]

---@type table<integer, true>
local ownAuraTypes = {}
---@type table<integer, true>
local foreignAuraTypes = {}

-- Only for use out of combat. In a restricted context, the enumeration finds no aura.
local function ScanPlayerAuraTypes()
    wipe(ownAuraTypes)
    wipe(foreignAuraTypes)
    local i = 1
    local aura = AuraByIndex("player", i, "HELPFUL")
    while aura do
        local auraType = PALADIN_AURA_TYPE[AuraField(aura, "spellId")]
        if auraType then
            local source = AuraField(aura, "sourceUnit")
            if source and Plain(UnitIsUnit(source, "player")) == true then
                ownAuraTypes[auraType] = true
            else
                foreignAuraTypes[auraType] = true
                local guid = source and Plain(UnitGUID(source))
                if guid then
                    otherPaladinAuras[guid] = auraType
                end
            end
        end
        i = i + 1
        aura = AuraByIndex("player", i, "HELPFUL")
    end
    PruneOtherPaladinAuras()
end

---@return boolean anyKnown The player knows an aura
---@return boolean allOnBar Each known aura type has a slot on the stance bar
local function KnownAurasOnStanceBar()
    local bar = BR.BuffState.GetStanceBarSpells()
    local anyKnown, allOnBar = false, true
    for _, choice in ipairs(PALADIN_AURA_CHOICES) do
        if HighestKnownSpell(choice.spellIDs) then
            anyKnown = true
            local onBar = false
            for _, id in ipairs(choice.spellIDs) do
                onBar = onBar or bar[id] == true
            end
            allOnBar = allOnBar and onBar
        end
    end
    return anyKnown, allOnBar
end

---Overlay text for the aura reminder of a paladin, or nil when the own aura is fine
---or unknown. The stance bar shows the active aura also in combat. Out of combat, an
---own aura instance stands in for an aura with no stance bar slot. A running
---resistance aura counts as a choice for the current boss.
---@param isAuraRestricted boolean
---@return string?
---@return boolean? noClick
local function CheckOwnPaladinAura(isAuraRestricted)
    local stanceID, unstanced = BR.BuffState.GetActiveStance()
    if not stanceID and not unstanced then
        return nil
    end
    local anyKnown, allOnBar = KnownAurasOnStanceBar()
    if not anyKnown then
        return nil
    end
    local runType = stanceID and PALADIN_AURA_TYPE[stanceID]
    local givenByOther = false
    if isAuraRestricted or BR.GameContext.IsInCombat() then
        if not runType then
            return allOnBar and NO_AURA_TEXT or nil
        end
    else
        ScanPlayerAuraTypes()
        runType = runType or next(ownAuraTypes)
        if not runType then
            return NO_AURA_TEXT
        end
        givenByOther = foreignAuraTypes[runType] == true and not ownAuraTypes[runType]
    end
    -- The scan marks each aura of another paladin as taken, so no paladin gives the wanted aura.
    local wantedType = WantedPaladinAura()
    if runType == wantedType then
        return nil
    end
    if givenByOther then
        if wantedType then
            return WRONG_AURA_TEXT
        end
        return DUPLICATE_TEXT, true
    end
    if not wantedType or PALADIN_AURA_CHOICES[runType].resistance then
        return nil
    end
    return WRONG_AURA_TEXT
end

---@class ForeverReagentRank
---@field item number
---@field icon number
---@field spells number[] Spells that use the item

---@class ForeverReagent
---@field key string Key in defaults.reagentThresholds
---@field classes ClassName[]
---@field warnBelow number Default threshold. 0 turns the warning off
---@field ranks ForeverReagentRank[] Highest first. Only the highest rank that the player knows counts

-- Vendor reagents only. A spell rank can need its own item, and a player keeps the
-- lower ranks, so only the item of the highest known rank counts.
---@type ForeverReagent[]
local REAGENTS = {
    {
        key = "arcanePowder",
        classes = { "MAGE" },
        warnBelow = 20,
        ranks = { { item = 17020, icon = 133848, spells = { 23028 } } },
    },
    {
        key = "teleportRune",
        classes = { "MAGE" },
        warnBelow = 3,
        ranks = {
            { item = 17031, icon = 134419, spells = { 3561, 3562, 3563, 3565, 3566, 3567, 1297659 } },
        },
    },
    {
        key = "portalRune",
        classes = { "MAGE" },
        warnBelow = 3,
        ranks = { { item = 17032, icon = 134421, spells = { 10059, 11416, 11417, 11418, 11419, 11420 } } },
    },
    {
        key = "lightFeather",
        classes = { "MAGE", "PRIEST" },
        warnBelow = 3,
        ranks = { { item = 17056, icon = 132917, spells = { 130, 1706 } } }, -- Slow Fall, Levitate
    },
    {
        key = "prayerCandle",
        classes = { "PRIEST" },
        warnBelow = 20,
        ranks = {
            { item = 17029, icon = 133751, spells = { 21564, 27681, 27683 } }, -- Sacred Candle
            { item = 17028, icon = 133752, spells = { 21562 } }, -- Holy Candle
        },
    },
    {
        key = "wildReagent",
        classes = { "DRUID" },
        warnBelow = 20,
        ranks = {
            { item = 17026, icon = 134412, spells = { 21850 } }, -- Wild Thornroot
            { item = 17021, icon = 133749, spells = { 21849 } }, -- Wild Berries
        },
    },
    {
        key = "rebirthSeed",
        classes = { "DRUID" },
        warnBelow = 3,
        ranks = {
            { item = 17038, icon = 133944, spells = { 20748 } }, -- Ironwood Seed
            { item = 17037, icon = 133944, spells = { 20747 } }, -- Hornbeam Seed
            { item = 17036, icon = 133944, spells = { 20742 } }, -- Ashwood Seed
            { item = 17035, icon = 133944, spells = { 20739 } }, -- Stranglethorn Seed
            { item = 17034, icon = 133944, spells = { 20484 } }, -- Maple Seed
        },
    },
    {
        key = "symbolOfKings",
        classes = { "PALADIN" },
        warnBelow = 20,
        ranks = { { item = 21177, icon = 134471, spells = { 25782, 25916, 25894, 25918, 25898 } } },
    },
    {
        key = "symbolOfDivinity",
        classes = { "PALADIN" },
        warnBelow = 3,
        ranks = { { item = 17033, icon = 135259, spells = { 19752 } } }, -- Divine Intervention
    },
    {
        key = "ankh",
        classes = { "SHAMAN" },
        warnBelow = 3,
        ranks = { { item = 17030, icon = 133439, spells = { 20608 } } },
    },
    {
        key = "fishScales",
        classes = { "SHAMAN" },
        warnBelow = 0,
        ranks = { { item = 17057, icon = 134310, spells = { 131 } } }, -- Water Breathing
    },
    {
        key = "fishOil",
        classes = { "SHAMAN" },
        warnBelow = 0,
        ranks = { { item = 17058, icon = 134844, spells = { 546 } } }, -- Water Walking
    },
    {
        key = "flashPowder",
        classes = { "ROGUE" },
        warnBelow = 10,
        ranks = { { item = 5140, icon = 134387, spells = { 1856, 1857, 27617, 457437, 1285372 } } },
    },
    {
        key = "infernalStone",
        classes = { "WARLOCK" },
        warnBelow = 3,
        ranks = { { item = 5565, icon = 135231, spells = { 1122 } } }, -- Inferno
    },
    {
        key = "demonicFigurine",
        classes = { "WARLOCK" },
        warnBelow = 0,
        ranks = { { item = 16583, icon = 134337, spells = { 18540 } } }, -- Ritual of Doom
    },
}

---The icon of the first reagent of the class, else Arcane Powder.
---@return number
local function DefaultReagentIcon()
    for _, reagent in ipairs(REAGENTS) do
        for _, class in ipairs(reagent.classes) do
            if class == playerClass then
                return reagent.ranks[1].icon
            end
        end
    end
    return 133848
end

BR.REAGENTS = REAGENTS

local AMMO_ICON_ARROW = 132382
local AMMO_ICON_BULLET = 132384
-- Arrows and bullets stack to 200 on Forever.
local AMMO_STACK_SIZE = 200

-- Ranged weapon subclass (Enum.ItemWeaponSubclass) to its ammo items.
---@type table<number, number[]>
local AMMO_BY_WEAPON = {}
do
    -- Every arrow and bullet in the item data, without test, deprecated and creature items.
    local arrows = { 2512, 2515, 3030, 3043, 3464, 9399, 10579, 11285, 12654, 18042, 19316, 223648, 231806, 274387 }
    local bullets = {
        2516,
        2519,
        3033,
        3465,
        4960,
        5568,
        8067,
        8068,
        8069,
        10512,
        10513,
        11284,
        11630,
        13377,
        15997,
        19317,
        231807,
        235699,
        274388,
    }
    AMMO_BY_WEAPON[2] = arrows -- Bow
    AMMO_BY_WEAPON[18] = arrows -- Crossbow
    AMMO_BY_WEAPON[3] = bullets -- Gun
end

-- The client can lack the ranged slot, so the main hand is the fallback.
---@return number? subclassID A ranged weapon that fires ammo
local function AmmoWeaponSubclass()
    local subclass = INVSLOT_RANGED and BR.BuffState.GetWeaponSubclass(INVSLOT_RANGED)
    if not (subclass and AMMO_BY_WEAPON[subclass]) then
        subclass = BR.BuffState.GetWeaponSubclass(16)
    end
    return subclass and AMMO_BY_WEAPON[subclass] and subclass or nil
end

---Count of the ammo that the weapon can fire.
---@param subclass number
---@return number
local function AmmoCount(subclass)
    local getCount = BR.StateHelpers.GetItemCountCached
    local total = 0
    for _, itemID in ipairs(AMMO_BY_WEAPON[subclass]) do
        total = total + getCount(itemID)
    end
    return total
end

---Shots left before the weapon stops firing: the game fires only the equipped ammo type
---and never swaps to another one. A client without an ammo slot fires any matching ammo.
---@param subclass number
---@return number shots
---@return number total All matching ammo in the bags
local function AmmoShots(subclass)
    local total = AmmoCount(subclass)
    if not INVSLOT_AMMO then
        return total, total
    end
    local itemID, count = BR.BuffState.GetEquippedAmmo()
    if itemID then
        for _, id in ipairs(AMMO_BY_WEAPON[subclass]) do
            if id == itemID then
                return count, total
            end
        end
    end
    return 0, total
end

-- Hunters fire ammo all the time; other classes only pull with it.
---@return number threshold In ammo, not stacks
local function AmmoThreshold()
    local defaults = BR.profile.defaults
    if playerClass == "HUNTER" then
        return (defaults and defaults.ammoThresholdStacks or 1) * AMMO_STACK_SIZE
    end
    return defaults and defaults.ammoThresholdShots or 20
end

local BATTLE_SHOUT = { 25289, 11551, 11550, 11549, 6192, 5242, 6673 }

-- Rage drains between fights, so the reminder shows only while the shout is castable.
-- The usable check includes talents that change the rage cost.
---@return boolean
local function BattleShoutReady()
    if BR.GameContext.IsInCombat() or BR.BuffState.IsRestricted() then
        return false
    end
    for _, id in ipairs(BATTLE_SHOUT) do
        if C_UnitAuras.GetPlayerAuraBySpellID(id) then
            return false
        end
    end
    local castID = HighestKnownSpell(BATTLE_SHOUT)
    return castID ~= nil and BR.BuffState.IsSpellUsable(castID)
end

---A single-target blessing rank that the level of the unit accepts.
---@param spellID number
---@param unit string
---@return number
local function FitBlessingRank(spellID, unit)
    local choice = BLESSING_BY_SPELL[spellID]
    if not choice or not RANK_LEVELS[spellID] or unit == "player" then
        return spellID
    end
    return BR.Ranks.Fit(choice.spellIDs, BR.Secret.Plain(UnitLevel(unit)) or -1) or spellID
end

---@param def RaidBuff
---@return number? spellID
---@return string? unit
local function BlessingPick(def)
    local spellID, unit = BR.BuffState.GetGroupCastSpellID(def)
    if spellID then
        return spellID, unit or "player"
    end
    spellID, unit = BR.BuffState.GetChoiceCast(def)
    if not spellID then
        return nil
    end
    unit = unit or "player"
    return FitBlessingRank(spellID, unit), unit
end

local otherBlessings = {}

---@param unit string
---@param auraIDs number[]
---@return boolean
local function UnitHasAnyAura(unit, auraIDs)
    for _, id in ipairs(auraIDs) do
        if C_UnitAuras.GetUnitAuraBySpellID(unit, id) then
            return true
        end
    end
    return false
end

---Every known blessing except the one that the main click casts and the ones that
---the unit has from any paladin or cannot take. The class lists do not apply, so the
---row can override them. A blessing needs a rank that the level of the unit accepts.
---@param unit string
---@param spellID number
---@return number[][]
local function OtherBlessings(_, unit, spellID)
    wipe(otherBlessings)
    local main = BLESSING_BY_SPELL[spellID]
    local level = BR.Secret.Plain(UnitLevel(unit)) or -1
    for _, choice in ipairs(PALADIN_BLESSINGS) do
        if
            choice ~= main
            and BR.Ranks.Fit(choice.spellIDs, level)
            and not UnitHasAnyAura(unit, choice.auraIDs)
            and not choice.castBlocked(unit)
        then
            otherBlessings[#otherBlessings + 1] = choice.spellIDs
        end
    end
    return otherBlessings
end

---@type SubChoiceRow
local BLESSING_ROW = {
    pick = BlessingPick,
    others = OtherBlessings,
}

---@type SubChoiceRow
local DRIVE_BY_ROW = {
    pick = function()
        local spellID = BR.DriveBy.Pick()
        if spellID then
            return spellID, "target"
        end
        return nil
    end,
    others = function(_, _, spellID)
        return BR.DriveBy.Others(spellID)
    end,
}

local SLEEPING_BAG = {
    itemID = 211527, -- Cozy Sleeping Bag
    auraID = 429959, -- Well-Rested
    restingID = 1331671, -- Resting, while the player lies in the bag
    maxStacks = 3,
    stackSeconds = 60,
}

---@return boolean
local function IsRestingInBag()
    return C_UnitAuras.GetUnitAuraBySpellID("player", SLEEPING_BAG.restingID) ~= nil
end

-- The Resting aura has no duration, so the rest starts when the addon first sees it.
local restInstanceID, restStartedAt

---GetTime()-based moment of the next Well-Rested gain while the player rests in the bag:
---the full stack, or at full stacks the duration refresh.
---@return number? endsAt nil when the player is not in the bag
---@return number? sweepSeconds
---@return string? stacksText
local function SleepingBagRestEnd()
    local GetPlayerAura = C_UnitAuras.GetUnitAuraBySpellID
    local resting = GetPlayerAura("player", SLEEPING_BAG.restingID)
    if not resting then
        restInstanceID = nil
        return nil
    end
    if resting.auraInstanceID ~= restInstanceID then
        restInstanceID = resting.auraInstanceID
        restStartedAt = GetTime()
    end
    local lastStackAt = restStartedAt
    local stacks = 0
    local rested = GetPlayerAura("player", SLEEPING_BAG.auraID)
    if rested then
        stacks = max(rested.applications or 0, 1)
        -- Each stack refreshes the duration, so the aura start is the time of the last stack.
        if rested.duration and rested.duration > 0 then
            lastStackAt = max(lastStackAt, rested.expirationTime - rested.duration)
        end
    end
    local stacksText = stacks .. "/" .. SLEEPING_BAG.maxStacks
    if stacks >= SLEEPING_BAG.maxStacks then
        return lastStackAt + SLEEPING_BAG.stackSeconds, SLEEPING_BAG.stackSeconds, stacksText
    end
    local fullSeconds = SLEEPING_BAG.maxStacks * SLEEPING_BAG.stackSeconds
    local endsAt = lastStackAt + (SLEEPING_BAG.maxStacks - stacks) * SLEEPING_BAG.stackSeconds
    return endsAt, fullSeconds, stacksText
end

-- The bag cannot go down in a city or an inn, and the buff gives only experience.
---@param isAuraRestricted boolean
---@return boolean
local function CanPlaceSleepingBag(isAuraRestricted)
    local GameContext = BR.GameContext
    if isAuraRestricted or GameContext.IsInCombat() or GameContext.IsResting() then
        return false
    end
    if GameContext.GetPlayerLevel() >= GameContext.GetMaxExpansionLevel() then
        return false
    end
    return BR.StateHelpers.GetItemCountCached(SLEEPING_BAG.itemID) > 0
        and BR.BuffState.IsItemOffCooldown(SLEEPING_BAG.itemID)
end

local CAMP = {
    benefitsID = 1229741, -- Camp Benefits
    nearbyID = 1283391, -- Campfire Nearby
    countdownIDs = { 1229739, 1289723 }, -- Welcoming Campfire, while the player sits or crafts
    -- Best tier first. Each kit needs a Cooking rank, and all kits share one cooldown.
    kits = { 279974, 279961, 279981 }, -- Expert, Journeyman, Basic Campfire Kit
}
local CAMP_SIT_TEXT = L["Overlay.CampSit"]
local CAMP_KIT_TEXT = L["Overlay.CampKit"]
-- The emote token works in every client language. The /sit command is localized.
local CAMP_SIT_MACRO = '/run DoEmote("SIT")'
local CAMP_KIT_MACROS = {}
local CAMP_KIT_ICONS = {}
for _, itemID in ipairs(CAMP.kits) do
    CAMP_KIT_MACROS[itemID] = "/use item:" .. itemID
    CAMP_KIT_ICONS[itemID] = C_Item.GetItemIconByID(itemID)
end

---@class CampFeature
---@field itemIDs number[] Highest tier first. A higher tier also gives the buff of its tier 1 feature
---@field auraID? number The feature buff, from the "mutually exclusive" spell tooltip
---@field conflict? RankedBuff The class buff that does not stack with the feature buff
---@field conflictAuras? number[] Aura IDs of a totem or aura that does not stack with the feature buff

-- The placeable features that give a buff to players who sit nearby. A feature needs
-- a campfire nearby, and all features share one cooldown.
---@type CampFeature[]
local CAMP_FEATURES = {
    -- Alchemy Laboratory, Fermenter, Mana Well
    { itemIDs = { 279990, 279970, 279956 }, auraID = 1230587, conflict = BLESSING_BY_KEY.wisdom },
    -- Master Forge, Anvil, Sharpening Wheel. Strength of Earth Totem ranks 5 to 1
    { itemIDs = { 279955, 279988, 279944 }, conflictAuras = { 25362, 10441, 8163, 8162, 8076 } },
    -- Arcane Forge, Arcane Salvager, Enchanted Lute
    { itemIDs = { 279987, 279985, 279976 }, auraID = 1230653, conflict = MARK_OF_THE_WILD },
    -- Plague Doctor's Laboratory, Toxin Study, First Aid Kit
    { itemIDs = { 279951, 279940, 279968 }, auraID = 1230124, conflict = POWER_WORD_FORTITUDE },
    -- Fishing Hut, Fishing Rack, Fish Bowl
    { itemIDs = { 279966, 279965, 279967 }, auraID = 1230098, conflict = BLESSING_BY_KEY.kings },
    -- Seed Hybridizer, Greenhouse, Incense Candle
    { itemIDs = { 279947, 279964, 279962 }, auraID = 1229513, conflict = ARCANE_INTELLECT },
    -- Molten Foundry, Rock Garden, Lodestone
    { itemIDs = { 279952, 279948, 279960 }, auraID = 1230164, conflict = BLESSING_BY_KEY.might },
    -- Field Guide, Camp Chair. Moonkin Aura
    { itemIDs = { 279969, 279979 }, conflictAuras = { 24907 } },
    -- Loom, Spinning Wheel, Faction Banner (Horde, Alliance)
    { itemIDs = { 279959, 279943, 279972, 279973 }, auraID = 1229718, conflict = DIVINE_SPIRIT },
    -- Sewing Machine, Tanning Rack, Camp Tent
    { itemIDs = { 279945, 279941, 279978 } },
}
---@type table<number, SubChoiceItem>
local CAMP_FEATURE_CHOICES = {}
for _, feature in ipairs(CAMP_FEATURES) do
    for _, itemID in ipairs(feature.itemIDs) do
        CAMP_FEATURE_CHOICES[itemID] = { itemID = itemID }
    end
    if feature.conflict and feature.auraID then
        local blockers = feature.conflict.blockers
        blockers[#blockers + 1] = feature.auraID
    end
end

---The next step toward Camp Benefits, also while the buff is present, so that the step renews it.
---@return "sit"|"camp"|nil stage
---@return number? kitID The kit that the click uses at the camp stage
local function ComputeCampStage()
    local GetPlayerAura = C_UnitAuras.GetUnitAuraBySpellID
    if GetPlayerAura("player", CAMP.nearbyID) then
        for _, spellID in ipairs(CAMP.countdownIDs) do
            if GetPlayerAura("player", spellID) then
                return nil
            end
        end
        return "sit"
    end
    local defaults = BR.profile.defaults
    if defaults and defaults.campLightFire == false then
        return nil
    end
    -- IsUsableItem also answers false indoors, so a cached answer goes stale on the way out.
    local kitID
    for _, itemID in ipairs(CAMP.kits) do
        if BR.StateHelpers.GetItemCountCached(itemID) > 0 and C_Item.IsUsableItem(itemID) then
            kitID = itemID
            break
        end
    end
    if not kitID or not BR.BuffState.IsItemOffCooldown(kitID) then
        return nil
    end
    -- A campfire alone gives no benefit: the benefits come from the features placed near it.
    for itemID in pairs(CAMP_FEATURE_CHOICES) do
        if BR.StateHelpers.GetItemCountCached(itemID) > 0 then
            return "camp", kitID
        end
    end
    return nil
end

-- One refresh asks for the stage from several callbacks in the same frame.
local campStageAt, campStage, campKitID
---@return "sit"|"camp"|nil stage
---@return number? kitID
local function CampStage()
    local now = GetTime()
    if campStageAt ~= now then
        campStageAt = now
        campStage, campKitID = ComputeCampStage()
    end
    return campStage, campKitID
end

-- The game blocks both the sit and the kit while the player is mounted.
---@param isAuraRestricted boolean
---@return boolean
local function CanRenewCamp(isAuraRestricted)
    local GameContext = BR.GameContext
    if isAuraRestricted or GameContext.IsInCombat() or GameContext.IsResting() or IsMounted() then
        return false
    end
    return CampStage() ~= nil
end

local campChoices = {}

---The carried camp features, while the player can place one. A feature whose buff
---the player already has from a class buff goes last.
---@return SubChoiceItem[]
local function CampFeatureChoices()
    wipe(campChoices)
    if CampStage() ~= "sit" then
        return campChoices
    end
    local GetItemCount = BR.StateHelpers.GetItemCountCached
    local covered = 0
    for _, feature in ipairs(CAMP_FEATURES) do
        local conflictIDs = feature.conflict and feature.conflict.auraIDs or feature.conflictAuras
        local last = conflictIDs ~= nil and UnitHasAnyAura("player", conflictIDs)
        for _, itemID in ipairs(feature.itemIDs) do
            if GetItemCount(itemID) > 0 then
                local choice = CAMP_FEATURE_CHOICES[itemID]
                if last then
                    covered = covered + 1
                    tinsert(campChoices, choice)
                else
                    tinsert(campChoices, #campChoices - covered + 1, choice)
                end
            end
        end
    end
    if campChoices[1] and not BR.BuffState.IsItemOffCooldown(campChoices[1].itemID) then
        wipe(campChoices)
    end
    return campChoices
end

---@type SubChoiceRow
local CAMP_ROW = {
    pick = function()
        if CampStage() == "sit" then
            return CAMP.benefitsID, "player"
        end
        return nil
    end,
    others = CampFeatureChoices,
}

---@alias TrackingKind "profession"|"racial"|"class"

---@class TrackingSpell
---@field key string Choice key in defaults.trackingSpells[kind]
---@field spellID number
---@field kind TrackingKind
---@field form? number Stance spell that the cast needs. The game ends the tracking when the form ends

-- Minimap tracking spells, in the order of the fallback pick. The game allows one active tracking.
---@type TrackingSpell[]
BR.TRACKING_SPELLS = {
    { key = "herbs", spellID = 2383, kind = "profession" }, -- Find Herbs
    { key = "minerals", spellID = 2580, kind = "profession" }, -- Find Minerals
    { key = "treasure", spellID = 2481, kind = "racial" }, -- Find Treasure
    { key = "beasts", spellID = 1494, kind = "class" }, -- Track Beasts
    { key = "humanoids", spellID = 19883, kind = "class" }, -- Track Humanoids
    { key = "undead", spellID = 19884, kind = "class" }, -- Track Undead
    { key = "demons", spellID = 19878, kind = "class" }, -- Track Demons
    { key = "elementals", spellID = 19880, kind = "class" }, -- Track Elementals
    { key = "giants", spellID = 19882, kind = "class" }, -- Track Giants
    { key = "dragonkin", spellID = 19879, kind = "class" }, -- Track Dragonkin
    { key = "hidden", spellID = 19885, kind = "class" }, -- Track Hidden
    { key = "humanoidsCat", spellID = 5225, kind = "class", form = 768 }, -- Track Humanoids (Druid), Cat Form
    { key = "senseUndead", spellID = 5502, kind = "class" }, -- Sense Undead
    { key = "senseDemons", spellID = 5500, kind = "class" }, -- Sense Demons
}

---@type number[]
local TRACKING_SPELL_IDS = {}
for i, spell in ipairs(BR.TRACKING_SPELLS) do
    TRACKING_SPELL_IDS[i] = spell.spellID
end

---@type SubChoiceRow
local TRACKING_ROW = {
    pick = function()
        local spellID = BR.Tracking.Pick()
        if spellID then
            return spellID, "player"
        end
        return nil
    end,
    others = function(_, _, spellID)
        return BR.Tracking.Others(spellID)
    end,
}

-- Spells have ranks, and every rank ID counts as the buff. Click-to-cast casts the
-- first ID in spellID that the player knows, so each list starts with the highest rank.
-- A raid buff lists its single-target ranks before its reagent group version.
-- A single-target raid buff sets castOnMissing, so that the click casts on a member
-- who lacks the buff. groupCast lists its group ranks, highest first.
---@type BuffTables
local BUFF_TABLES = {
    ---@type RaidBuff[]
    raid = {
        {
            spellID = ARCANE_INTELLECT.auraIDs,
            castBlocked = ARCANE_INTELLECT.castBlocked,
            key = "intellect",
            name = L["Buff.ArcaneIntellect"],
            class = "MAGE",
            reach = "raid",
            icons = { spells = { 10157 } },
            castOnMissing = true,
            groupCast = ARCANE_INTELLECT.groupCast,
            chatRequestable = true,
        },
        {
            spellID = BATTLE_SHOUT,
            key = "attackPower",
            name = L["Buff.BattleShout"],
            class = "WARRIOR",
            reach = "raid",
            requiresKnownSpell = true,
            visibilityCondition = BattleShoutReady,
        },
        {
            spellID = DIVINE_SPIRIT.auraIDs,
            castBlocked = DIVINE_SPIRIT.castBlocked,
            key = "spirit",
            name = L["Buff.DivineSpirit"],
            class = "PRIEST",
            reach = "raid",
            icons = { spells = { 27841 } },
            castOnMissing = true,
            groupCast = DIVINE_SPIRIT.groupCast,
            -- A talent: only a priest who knows it sees the reminder.
            requiresKnownSpell = true,
        },
        {
            spellID = MARK_OF_THE_WILD.auraIDs,
            castBlocked = MARK_OF_THE_WILD.castBlocked,
            key = "versatility",
            name = L["Buff.MarkOfTheWild"],
            class = "DRUID",
            reach = "raid",
            icons = { spells = { 9885 } },
            castOnMissing = true,
            groupCast = MARK_OF_THE_WILD.groupCast,
            chatRequestable = true,
        },
        -- Each member gets the blessing of their class list in the options grid.
        {
            spellID = ALL_BLESSING_IDS,
            key = "paladinBlessing",
            name = L["Buff.PaladinBlessing"],
            class = "PALADIN",
            reach = "raid",
            icons = { spells = { 25291 } },
            castOnMissing = true,
            requiresKnownSpell = true,
            classChoices = PALADIN_BLESSING_GRID,
            subChoices = BLESSING_ROW,
            levelRequired = 4, -- Blessing of Might rank 1
            chatRequestable = true,
            chatRequestSpell = RequestedBlessing,
            target = function()
                local defaults = BR.profile.defaults
                return defaults ~= nil and defaults.paladinBlessingScope == "self" and "self" or "group"
            end,
        },
        {
            spellID = POWER_WORD_FORTITUDE.auraIDs,
            castBlocked = POWER_WORD_FORTITUDE.castBlocked,
            key = "stamina",
            name = L["Buff.PowerWordFortitude"],
            class = "PRIEST",
            reach = "raid",
            icons = { spells = { 10938 } },
            castOnMissing = true,
            groupCast = POWER_WORD_FORTITUDE.groupCast,
            chatRequestable = true,
        },
        {
            spellID = { 10958, 10957, 976, 27683 },
            key = "shadowProtection",
            name = L["Buff.ShadowProtection"],
            class = "PRIEST",
            reach = "raid",
            icons = { spells = { 10958 } },
            castOnMissing = true,
            groupCast = { { spellID = 27683, reagent = 17029 } },
            defaultEnabled = false, -- opt-in: only shadow damage fights want it
            chatRequestable = true,
        },
    },
    ---@type PresenceBuff[]
    presence = {
        {
            spellID = ALL_PALADIN_AURA_IDS,
            key = "paladinAura",
            name = L["Buff.PaladinAura"],
            class = "PALADIN",
            reach = "party",
            icons = {
                spells = { 10293 },
                dynamic = function()
                    local _, castID = WantedPaladinAura()
                    return castID and BR.Icons.GetBuffTexture(castID)
                end,
            },
            overlayText = L["Overlay.NoAura"],
            casterCheck = CheckOwnPaladinAura,
            choiceOrder = PALADIN_AURA_GRID,
            clickMacro = function(spellID)
                local _, castID = WantedPaladinAura()
                return "/cast " .. (BR.GetSpellName(castID or spellID) or "")
            end,
            infoTooltip = { title = L["Tooltip.PaladinDuplicate"], desc = L["Tooltip.PaladinAuraDuplicate.Desc"] },
        },
        -- The target gets the buff from a Soulstone item, so the click uses the stone in
        -- the bags, else creates one.
        {
            spellID = { 20765, 20764, 20763, 20762, 20707 }, -- Soulstone Resurrection, one per rank
            key = "soulstone",
            name = L["Buff.Soulstone"],
            class = "WARLOCK",
            reach = "raid",
            levelRequired = 18, -- Create Soulstone (Minor)
            overlayText = L["Overlay.NoSoulstone"],
            chatRequestable = true,
            readyCheckOnly = true,
            target = "allyOrSelf", -- solo, a warlock stones itself
            copies = "own",
            castSpellID = CREATE_SOULSTONE,
            castReady = function()
                if playerClass ~= "WARLOCK" then
                    return nil
                end
                local defaults = BR.profile.defaults
                if not (defaults and defaults.soulstoneHideCooldown) then
                    return nil
                end
                if CooldownsRestricted() then
                    return false
                end
                return SoulstoneReady()
            end,
            pinnedTarget = function()
                local defaults = BR.profile.defaults
                local pinned = defaults and defaults.soulstonePinnedTarget
                return pinned ~= "" and pinned or nil
            end,
            clickMacro = function(spellID)
                local stone = SoulstoneInBags()
                if stone then
                    return "/use " .. BR.SoulstoneTargetConditions() .. "item:" .. stone
                end
                return "/cast " .. (BR.GetSpellName(spellID) or "")
            end,
        },
    },
    ---@type TargetedBuff[]
    targeted = {
        {
            spellID = 1328548,
            key = "oathOfLight",
            target = "allyOrSelf",
            name = L["Buff.OathOfLight"],
            class = "PALADIN",
            overlayText = L["Overlay.NoOath"],
            clickMacro = BR.TargetedClickMacro("oathOfLight"),
        },
        {
            spellID = { 9910, 9756, 8914, 1075, 782, 467 },
            key = "thorns",
            name = L["Buff.Thorns"],
            class = "DRUID",
            overlayText = L["Overlay.NoThorns"],
            levelRequired = 6, -- Thorns rank 1
            target = "tankOrSelf",
            copies = "any",
            targetHint = L["Tooltip.TankHint"],
            chatRequestable = true,
            -- A tank of another class sees the request only when the user turns it on.
            visibilityCondition = function()
                local defaults = BR.profile.defaults
                return playerClass == "DRUID" or (defaults ~= nil and defaults.thornsRequest == true)
            end,
            clickMacro = TankOrSelfMacro("thorns"),
            infoTooltip = { title = L["Tooltip.TankTarget"], desc = L["Tooltip.ThornsTank.Desc"] },
        },
    },
    ---@type SelfBuff[]
    self = {
        -- spellID holds the racials for the known-spell gate. Each Skyborne race knows one of them.
        {
            spellID = SKYBORNE_RACIALS,
            buffIdOverride = SKYBORNE_AURAS,
            getExpirationInfo = SkyborneAuraExpiration,
            key = "skyborneAttunement",
            defaultEnabled = false, -- opt-in: ships disabled
            name = L["Buff.SkyborneAttunement"],
            overlayText = L["Overlay.FindLeyline"],
            icons = {
                spells = SKYBORNE_RACIALS,
                dynamic = function()
                    local id = HighestKnownSpell(SKYBORNE_RACIALS)
                    return id and BR.Icons.GetBuffTexture(id)
                end,
            },
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
        -- One reminder for the whole setup, because the order of the steps matters: a
        -- sacrifice kills the linked demon. The link ends with its demon, so each summon needs a new cast.
        {
            spellID = DEMONIC_SACRIFICE.spellID,
            -- Sacrifice buffs first, so that the expiration check reads the timed buff.
            buffIdOverride = { 18789, 18790, 18791, 18792, SOUL_LINK_AURA },
            key = "demonicSacrifice",
            name = L["Buff.DemonicSacrificeSoulLink"],
            class = "WARLOCK",
            overlayText = L["Overlay.NoSacrifice"],
            overlayTextFn = function()
                return DEMON_SETUP_TEXT[DemonSetupStep() or "sacrifice"]
            end,
            icons = {
                spells = { DEMONIC_SACRIFICE.spellID, SOUL_LINK },
                dynamic = function()
                    local step = DemonSetupStep()
                    if step == "summon" then
                        local demon = PactSummonAction()
                        return demon and demon.icon
                    end
                    return BR.Icons.GetBuffTexture(step == "link" and SOUL_LINK or DEMONIC_SACRIFICE.spellID)
                end,
            },
            requiresSpellID = DEMONIC_SACRIFICE.spellID,
            customCheck = function()
                return DemonSetupStep() ~= nil
            end,
            clickMacro = DemonSetupMacro,
            infoTooltip = { title = L["Tooltip.DemonSetup"], desc = L["Tooltip.DemonSetup.Desc"] },
        },
        -- The stance bar stays readable in combat, so this reminder works there.
        {
            key = "druidWrongForm",
            defaultEnabled = false, -- opt-in: ships disabled
            name = L["Buff.DruidForm"],
            class = "DRUID",
            overlayText = L["Overlay.WrongForm"],
            icons = {
                spells = { 5487, 768, 24858 }, -- Bear, Cat, Moonkin
                dynamic = function()
                    local expected = BR.BuffState.GetExpectedDruidFormID()
                    if expected and expected ~= NO_STANCE then
                        return BR.Icons.GetBuffTexture(expected)
                    end
                    return BR.BuffState.GetCurrentStanceIcon()
                end,
            },
            -- Any known form enables the click. The caster choice cancels a form.
            castSpellID = { 9634, 5487, 768, 24858 },
            customCheck = function()
                return BR.BuffState.IsWrongDruidForm()
            end,
            clickMacro = function()
                return StanceMacro(BR.BuffState.GetExpectedDruidFormID())
            end,
        },
        {
            spellID = ALL_MAGE_ARMOR_IDS,
            key = "mageArmor",
            icons = {
                spells = { 10220 },
                dynamic = function()
                    local castID = PreferredMageArmor()
                    return castID and BR.Icons.GetBuffTexture(castID)
                end,
            },
            name = L["Buff.MageArmor"],
            class = "MAGE",
            overlayText = L["Overlay.NoArmor"],
            clickMacro = function(spellID)
                return "/cast " .. (BR.GetSpellName(PreferredMageArmor() or spellID) or "")
            end,
        },
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
            spellID = { 10952, 10951, 1006, 602, 7128, 588 },
            key = "innerFire",
            name = L["Buff.InnerFire"],
            class = "PRIEST",
            overlayText = L["Overlay.NoInnerFire"],
        },
        {
            spellID = { 10432, 10431, 8134, 945, 905, 325, 324 },
            key = "lightningShield",
            name = L["Buff.LightningShield"],
            class = "SHAMAN",
            overlayText = L["Overlay.NoShield"],
        },
        {
            spellID = 25780,
            key = "righteousFury",
            name = L["Buff.RighteousFury"],
            class = "PALADIN",
            overlayText = L["Overlay.NoRighteousFury"],
            visibilityCondition = RighteousFuryWanted,
            infoTooltip = { title = L["Tooltip.TankOnly"], desc = L["Tooltip.RighteousFuryTank.Desc"] },
        },
        {
            icons = {
                spells = { 8679, 2823 }, -- Instant Poison, Deadly Poison
                dynamic = function()
                    local hand = HandMissingPoison()
                    local _, spellID = PickPoison(hand and hand.column or "mainHand")
                    return spellID and BR.Icons.GetBuffTexture(spellID)
                end,
            },
            key = "roguePoisons",
            name = L["Buff.RoguePoisons"],
            class = "ROGUE",
            overlayText = L["Overlay.ApplyPoison"],
            requiresSpellID = POISONS_SKILL,
            castSpellID = POISONS_SKILL,
            visibilityCondition = function()
                return not BR.BuffState.IsRestricted()
            end,
            customCheck = function()
                return HandMissingPoison() ~= nil
            end,
            getExpirationInfo = PoisonRemaining,
            enchantDuration = 1800, -- seconds
            clickMacro = PoisonMacro,
        },
        -- The stance bar shows Shadowform, and it stays readable in combat.
        {
            key = "shadowform",
            name = L["Buff.Shadowform"],
            class = "PRIEST",
            overlayText = L["Overlay.NoForm"],
            icons = { textures = { 136200 } }, -- spell_shadow_shadowform
            requiresSpellID = BR.SHADOWFORM_SPELL_ID,
            castSpellID = BR.SHADOWFORM_SPELL_ID,
            noExpirationGlow = true,
            customCheck = function()
                return not BR.BuffState.IsShadowFormActive()
            end,
        },
        {
            spellID = WARLOCK_STONE_CREATE,
            key = "warlockStone",
            name = L["Buff.WarlockStone"],
            class = "WARLOCK",
            overlayText = L["Overlay.NoStone"],
            -- The enchant set times the expiry warning. customCheck decides what is missing.
            enchantID = WARLOCK_STONE_ENCHANTS,
            enchantDuration = 7200, -- seconds
            visibilityCondition = function()
                return HandHoldsWeapon(16)
            end,
            customCheck = function()
                if not HighestKnownSpell(WARLOCK_STONE_CREATE) then
                    return nil
                end
                local id = BR.BuffState.GetWeaponImbue(16)
                local picked = PickedStone()
                return not (id and (picked and picked.enchants or WARLOCK_STONE_ENCHANTS)[id])
            end,
            icons = {
                textures = { WARLOCK_STONES[1].icon, WARLOCK_STONES[2].icon },
                dynamic = function()
                    return (ClickStone()).icon
                end,
            },
            clickMacro = WarlockStoneMacro,
        },
        {
            spellID = { 20906, 20905, 19506, 1299348, 1299346 },
            key = "trueshotAura",
            name = L["Buff.TrueshotAura"],
            class = "HUNTER",
            overlayText = L["Overlay.NoAura"],
        },
        -- The stance bar stays readable in combat, so this reminder works there.
        {
            key = "warriorWrongStance",
            defaultEnabled = false, -- opt-in: ships disabled
            name = L["Buff.WarriorStance"],
            class = "WARRIOR",
            overlayText = L["Overlay.WrongStance"],
            icons = {
                spells = { 2457, 71, 2458 }, -- Battle, Defensive, Berserker
                dynamic = function()
                    local current = BR.BuffState.GetCurrentStanceIcon()
                    if current then
                        return current
                    end
                    local expected = BR.BuffState.GetExpectedWarriorStanceID()
                    return expected and BR.Icons.GetBuffTexture(expected)
                end,
            },
            castSpellID = 2457, -- Battle Stance: known from level 1
            customCheck = function()
                return BR.BuffState.IsWrongWarriorStance()
            end,
            clickMacro = function()
                return StanceMacro(BR.BuffState.GetExpectedWarriorStanceID())
            end,
        },
        -- Vanilla shamans do not dual-wield, so any imbue on the weapon counts.
        {
            spellID = SHAMAN_IMBUES,
            key = "shamanImbue",
            name = L["Buff.ShamanImbue"],
            class = "SHAMAN",
            overlayText = L["Overlay.NoImbue"],
            enchantID = SHAMAN_IMBUE_ENCHANTS,
            enchantDuration = 3600, -- seconds
            -- An unarmed hand or a fishing pole takes no imbue.
            visibilityCondition = function()
                local subclass = BR.BuffState.GetWeaponSubclass(16)
                return subclass ~= nil and subclass ~= 20 -- Enum.ItemWeaponSubclass.Fishingpole
            end,
            icons = {
                spells = { 16362, 16342, 16316, 16356 }, -- Windfury, Flametongue, Rockbiter, Frostbrand
                dynamic = function()
                    local id = ShamanImbueCastID()
                    return id and BR.Icons.GetBuffTexture(id)
                end,
            },
            clickMacro = function()
                local id = ShamanImbueCastID()
                return id and ("/cast " .. (BR.GetSpellName(id) or "")) or ""
            end,
        },
    },
    ---@type SelfBuff[]
    pet = {
        {
            key = "petPassive",
            name = L["Buff.PetPassive"],
            overlayText = L["Overlay.PassivePet"],
            icons = { textures = { 132311 } },
            customCheck = function()
                return BR.PetHelpers.IsPetOnPassive()
            end,
        },
        -- A hunter tames the first pet at level 10, where Call Pet is learned.
        {
            key = "hunterPet",
            name = L["Buff.HunterPet"],
            class = "HUNTER",
            overlayText = L["Overlay.NoPet"],
            icons = { textures = { 132161 } }, -- Call Pet
            requiresSpellID = 883,
            groupId = "pets",
            customCheck = function()
                return not UnitExists("pet") or UnitIsDead("pet") or nil
            end,
        },
        {
            key = "warlockPet",
            name = L["Buff.WarlockDemon"],
            class = "WARLOCK",
            overlayText = L["Overlay.NoPet"],
            icons = { textures = { 136218 } }, -- Summon Imp
            requiresSpellID = 688, -- Summon Imp
            petSacrifice = DEMONIC_SACRIFICE,
            groupId = "pets",
            customCheck = function()
                return not UnitExists("pet")
            end,
        },
        {
            key = "warlockWrongPet",
            name = L["Buff.WrongDemon"],
            class = "WARLOCK",
            overlayText = L["Overlay.WrongPet"],
            icons = { textures = { 136217 } }, -- Summon Felhunter
            groupId = "pets",
            -- The setup reminder picks the demons, and a summon can cancel the sacrifice.
            petSacrifice = DEMONIC_SACRIFICE,
            customCheck = function()
                local defaults = BR.profile.defaults
                if defaults and defaults.warlockWrongDemon == false then
                    return false
                end
                return BR.BuffState.IsWrongDemonPet()
            end,
            getPetActions = function()
                return BR.PetHelpers.GetDesiredWarlockDemonList()
            end,
        },
    },
    custom = {},
    loadout = {},
    ---@type ConsumableBuff[]
    consumable = {
        {
            spellID = {
                17626, -- Flask of the Titans
                17627, -- Distilled Wisdom
                17628, -- Supreme Power
                17629, -- Chromatic Resistance
                17624, -- Petrification
            },
            icons = { spells = { 17626, 17627, 17628, 17629 } },
            key = "flask",
            name = L["Buff.Flask"],
            overlayText = L["Overlay.NoFlask"],
            groupId = "flask",
            consumableCategory = "flask",
            disabledInCompetitivePvP = true,
        },
        -- The list holds each aura that a food item gives. Icon 136000 also catches the
        -- older Well Fed auras that no item gives.
        {
            spellID = {
                1248406, -- Well Fed (Stamina)
                1248420, -- Well Fed (Agility)
                1248421, -- Well Fed (Intellect)
                1248422, -- Well Fed (Strength)
                1302064, -- Well Fed (Strength)
                1249519, -- Well Fed (Attack Power)
                1249520, -- Well Fed (Spell Damage)
                1249521, -- Well Fed (Fishing)
                1249523, -- Well Fed (Critical Strike)
                1319310, -- Well Fed (Armor)
                1225779, -- Well Fed (Agility and Stamina)
                1248688, -- Well Fed (movement speed in Westfall)
                1294007, -- Well Fed (movement speed in Hyjal)
                1249907, -- Well Fed (Herbalism, Goldthorn Tea)
                1249926, -- Well Fed (Spirit, smoothies)
                1249927, -- Well Fed (Healing Power, teas)
                19705, -- Well Fed (Stamina and Spirit)
                19706,
                19708,
                19709,
                19710,
                19711,
                25661, -- Increased Stamina (Dirge's Kickin' Chimaerok Chops)
                18191, -- Increased Stamina (Windblossom Berries)
                18125, -- Blessed Sunfruit
                18141, -- Blessed Sunfruit Juice
                15852, -- Dragonbreath Chili
            },
            buffIconID = 136000,
            icons = { textures = { 133943 } },
            key = "food",
            name = L["Buff.Food"],
            overlayText = L["Overlay.NoFood"],
            groupId = "food",
            consumableCategory = "food",
            disabledInCompetitivePvP = true,
        },
        -- A healthstone is unique and has one use. No Soulwell exists.
        {
            itemID = {
                9421, -- Major Healthstone
                19012,
                19013,
                5510, -- Greater Healthstone
                19010,
                19011,
                5509, -- Healthstone
                19008,
                19009,
                5511, -- Lesser Healthstone
                19006,
                19007,
                5512, -- Minor Healthstone
                19004,
                19005,
            },
            key = "healthstone",
            name = L["Buff.Healthstone"],
            casterClass = "WARLOCK",
            overlayText = L["Overlay.NoStone"],
            groupId = "healthstone",
            icons = { textures = { 135230 } },
            freeConsumable = true,
            chatRequestable = true,
            clickMacro = function()
                return CastHighestKnownMacro(CREATE_HEALTHSTONE)
            end,
        },
        {
            itemID = {
                8008, -- Mana Ruby
                8007, -- Mana Citrine
                5513, -- Mana Jade
                5514, -- Mana Agate
            },
            key = "manaGem",
            name = L["Buff.ManaGem"],
            casterClass = "MAGE",
            overlayText = L["Overlay.NoGem"],
            icons = { textures = { 134128 } },
            freeConsumable = true,
            visibilityCondition = function()
                return playerClass == "MAGE" and HighestKnownSpell(CONJURE_MANA_GEM) ~= nil
            end,
            clickMacro = function()
                return CastHighestKnownMacro(CONJURE_MANA_GEM)
            end,
        },
        {
            checkWeaponEnchant = true,
            enchantDuration = 1800, -- seconds
            key = "weaponBuff",
            name = L["Buff.Weapon"],
            overlayText = L["Overlay.NoWeaponBuff"],
            groupId = "weaponBuff",
            icons = { textures = { 134727, 135252 } }, -- Brilliant Wizard Oil, Dense Sharpening Stone
            consumableCategory = "weapon",
            visibilityCondition = function()
                return not BR.BuffState.IsRestricted()
            end,
            disabledInCompetitivePvP = true,
        },
        {
            checkWeaponEnchantOH = true,
            enchantDuration = 1800, -- seconds
            key = "weaponBuffOH",
            name = L["Buff.WeaponOH"],
            overlayText = L["Overlay.NoWeaponBuff"],
            groupId = "weaponBuff",
            icons = { textures = { 134727, 135252 } }, -- Brilliant Wizard Oil, Dense Sharpening Stone
            consumableCategory = "weapon",
            visibilityCondition = function()
                return not BR.BuffState.IsRestricted() and BR.BuffState.HasOffHandWeapon()
            end,
            disabledInCompetitivePvP = true,
        },
    },
    ---@type UtilityBuff[]
    utility = {
        {
            key = "camp",
            name = L["Buff.Camp"],
            icons = {
                spells = { CAMP.benefitsID },
                dynamic = function()
                    local stage, kitID = CampStage()
                    -- A nil icon keeps the texture of the previous stage on the frame.
                    if stage == "camp" and kitID then
                        local icon = CAMP_KIT_ICONS[kitID] or C_Item.GetItemIconByID(kitID)
                        CAMP_KIT_ICONS[kitID] = icon
                        return icon
                    end
                    return BR.Icons.GetBuffTexture(CAMP.benefitsID)
                end,
            },
            overlayText = CAMP_SIT_TEXT,
            overlayTextFn = function()
                return CampStage() == "camp" and CAMP_KIT_TEXT or CAMP_SIT_TEXT
            end,
            subChoices = CAMP_ROW,
            clickMacroText = function()
                local stage, kitID = CampStage()
                if stage == "sit" then
                    return CAMP_SIT_MACRO
                end
                return kitID and CAMP_KIT_MACROS[kitID]
            end,
            customCheck = function(isAuraRestricted)
                return CanRenewCamp(isAuraRestricted)
                    and not C_UnitAuras.GetUnitAuraBySpellID("player", CAMP.benefitsID)
            end,
            renewAuraID = CAMP.benefitsID,
            canRenew = CanRenewCamp,
        },
        {
            key = "sleepingBag",
            name = L["Buff.SleepingBag"],
            icons = { textures = { C_Item.GetItemIconByID(SLEEPING_BAG.itemID) or 134400 } }, -- else a question mark
            overlayText = L["Overlay.SleepingBag"],
            infoTooltip = { title = L["Buff.SleepingBag"], desc = L["Tooltip.SleepingBag.Desc"] },
            clickItem = SLEEPING_BAG.itemID,
            countdown = SleepingBagRestEnd,
            customCheck = function(isAuraRestricted)
                local GameContext = BR.GameContext
                if isAuraRestricted or GameContext.IsInCombat() then
                    return false
                end
                if GameContext.GetPlayerLevel() >= GameContext.GetMaxExpansionLevel() then
                    return false
                end
                -- The bag itself makes the player rest, so this check comes before the rest check.
                if SleepingBagRestEnd() then
                    return true
                end
                return CanPlaceSleepingBag(isAuraRestricted)
                    and not C_UnitAuras.GetUnitAuraBySpellID("player", SLEEPING_BAG.auraID)
            end,
            renewAuraID = SLEEPING_BAG.auraID,
            canRenew = CanPlaceSleepingBag,
        },
        -- spellID gives the click overlay a known spell. PreClick replaces it with the pick.
        {
            key = "driveByBuffs",
            defaultEnabled = false, -- opt-in: casts on strangers
            name = L["Buff.DriveByBuffs"],
            spellID = SINGLE_TARGET_RANKS,
            icons = {
                spells = { 10157, 10938, 9885 },
                dynamic = function()
                    local spellID = BR.DriveBy.Pick()
                    return spellID and BR.Icons.GetBuffTexture(spellID)
                end,
            },
            overlayText = L["Overlay.DriveBy"],
            infoTooltip = { title = L["Buff.DriveByBuffs"], desc = L["Tooltip.DriveBy.Desc"] },
            castUnit = "target",
            subChoices = DRIVE_BY_ROW,
            clickSpell = function()
                return BR.DriveBy.Pick()
            end,
            customCheck = function()
                return BR.DriveBy.Pick() ~= nil
            end,
        },
        {
            key = "lowAmmo",
            name = L["Buff.LowAmmo"],
            icons = {
                textures = { AMMO_ICON_ARROW },
                dynamic = function()
                    return AmmoWeaponSubclass() == 3 and AMMO_ICON_BULLET or AMMO_ICON_ARROW -- 3 = Gun
                end,
            },
            overlayText = AMMO_TEXT,
            overlayTextFn = function()
                local subclass = AmmoWeaponSubclass()
                if not subclass then
                    return AMMO_TEXT
                end
                -- Enough other ammo in the bags: a swap fixes it, not a vendor.
                local shots, total = AmmoShots(subclass)
                if total - shots >= AmmoThreshold() or (shots == 0 and total > 0) then
                    return AMMO_EQUIP_TEXT
                end
                return AMMO_LABEL .. "\n" .. shots
            end,
            customCheck = function()
                if BR.GameContext.IsInCombat() then
                    return false
                end
                local subclass = AmmoWeaponSubclass()
                if not subclass then
                    return false
                end
                return AmmoShots(subclass) < AmmoThreshold()
            end,
        },
        {
            key = "lowReagents",
            name = L["Buff.LowReagents"],
            icons = {
                textures = { DefaultReagentIcon() },
                dynamic = function()
                    local reagent = BR.Reagents.Low()
                    return reagent and reagent.icon
                end,
            },
            overlayText = REAGENTS_TEXT,
            overlayTextFn = function()
                local _, count = BR.Reagents.Low()
                return count and (REAGENT_LABEL .. "\n" .. count) or REAGENTS_TEXT
            end,
            tooltipItemID = function()
                local reagent = BR.Reagents.Low()
                return reagent and reagent.item
            end,
            tooltipLines = function(tooltip)
                BR.Reagents.AddTooltipLines(tooltip)
            end,
            customCheck = function()
                if BR.GameContext.IsInCombat() then
                    return false
                end
                local defaults = BR.profile.defaults
                local restedOnly = not defaults or defaults.reagentRestedOnly ~= false
                local dropWarning = not defaults or defaults.reagentDropWarning ~= false
                if
                    restedOnly
                    and not BR.GameContext.IsResting()
                    and not (dropWarning and BR.Reagents.IsWindowOpen())
                then
                    return false
                end
                return BR.Reagents.Low() ~= nil
            end,
        },
        {
            key = "repairGear",
            defaultEnabled = false, -- opt-in: ships disabled
            name = L["Buff.RepairGear"],
            icons = { textures = { 136241 } }, -- Trade_BlackSmithing
            overlayText = L["Overlay.Repair"],
            -- floor, not round: 84.9% must never read as the 85% threshold it crossed.
            overlayTextFn = function()
                return REPAIR_LABEL .. "\n" .. floor(BR.BuffState.GetLowestDurability() * 100) .. "%"
            end,
            customCheck = function()
                return BR.BuffState.GetLowestDurability() < (BR.Config.Get("defaults.repairThreshold", 20) / 100)
            end,
        },
        {
            key = "tracking",
            name = L["Buff.Tracking"],
            spellID = TRACKING_SPELL_IDS,
            icons = {
                spells = { 2383, 2580, 1494 },
                dynamic = function()
                    local spellID = BR.Tracking.Pick()
                    return spellID and BR.Icons.GetBuffTexture(spellID)
                end,
            },
            overlayText = L["Overlay.NoTracking"],
            subChoices = TRACKING_ROW,
            clickSpell = function()
                return BR.Tracking.Pick()
            end,
            customCheck = function()
                if BR.GameContext.IsInCombat() then
                    return false
                end
                return BR.Tracking.Pick() ~= nil and not BR.BuffState.IsTrackingActive()
            end,
        },
    },
}

-- The happiness reminder exists only on a client with pet happiness.
if C_PetInfo and C_PetInfo.GetPetHappiness then
    table.insert(BUFF_TABLES.pet, 1, PET_HAPPINESS)
end

---@type BuffData
BR.BuffData = {
    buffTables = BUFF_TABLES,
    dkRuneforges = {},
    instanceContent = INSTANCE_CONTENT,
    petSpells = PET_SPELLS,
    stanceRules = STANCE_RULES,
    poisonDefaults = DEFAULT_POISON_PREFERENCES,
    poisonColumns = POISON_COLUMNS,
    repairSources = { mounts = {}, items = {} },
    isRestingInBag = IsRestingInBag,
}
